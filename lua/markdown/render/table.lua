local treesitter = require("markdown.treesitter")

local M = {}

local MIN_COLUMN_WIDTH = 8
local FALLBACK_AVAILABLE_WIDTH = 200
local CODE_INLINE_HIGHLIGHT = "MarkdownTableCodeInline"

---@param row_node TSNode
---@param buffer_number number
---@return string[]
local function extract_cells(row_node, buffer_number)
    local cells = {}

    for child in row_node:iter_children() do
        local child_type = child:type()

        if child_type == "pipe_table_cell" then
            local cell_text = vim.trim(treesitter.get_node_text(child, buffer_number))
            table.insert(cells, cell_text)
        end
    end

    return cells
end

---@return number
local function get_available_table_width()
    local state = require("markdown.state")
    local config = require("markdown.config")

    local padding_width = config.get().padding or 0

    if state.state.preview_window and vim.api.nvim_win_is_valid(state.state.preview_window) then
        local window_width = vim.api.nvim_win_get_width(state.state.preview_window)
        return math.max(window_width - padding_width, MIN_COLUMN_WIDTH * 2)
    end

    local fallback = vim.o.columns

    if not fallback or fallback <= 0 then
        fallback = FALLBACK_AVAILABLE_WIDTH
    end

    return math.max(fallback - padding_width, MIN_COLUMN_WIDTH * 2)
end

---@param text string
---@return {text: string, is_code: boolean, has_leading_space: boolean}[]
local function tokenize_cell(text)
    local atoms = {}
    local cursor = 1
    local pending_space = false

    while cursor <= #text do
        local char = text:sub(cursor, cursor)

        if char:match("%s") then
            pending_space = true
            cursor = cursor + 1
        elseif char == "`" then
            local code_end = text:find("`", cursor + 1)

            if code_end then
                local inner = text:sub(cursor + 1, code_end - 1)
                table.insert(atoms, {
                    text = inner,
                    is_code = true,
                    has_leading_space = pending_space and #atoms > 0,
                })
                pending_space = false
                cursor = code_end + 1
            else
                local word_end = text:find("%s", cursor + 1) or (#text + 1)
                table.insert(atoms, {
                    text = text:sub(cursor, word_end - 1),
                    is_code = false,
                    has_leading_space = pending_space and #atoms > 0,
                })
                pending_space = false
                cursor = word_end
            end
        else
            local word_end = text:find("[%s`]", cursor) or (#text + 1)
            table.insert(atoms, {
                text = text:sub(cursor, word_end - 1),
                is_code = false,
                has_leading_space = pending_space and #atoms > 0,
            })
            pending_space = false
            cursor = word_end
        end
    end

    return atoms
end

---@param word_text string
---@param max_width number
---@return string[]
local function break_long_text(word_text, max_width)
    local pieces = {}
    local remaining = word_text

    while vim.fn.strwidth(remaining) > max_width do
        local total_chars = vim.fn.strchars(remaining)
        local low, high = 1, total_chars
        local fit = 1

        while low <= high do
            local mid = math.floor((low + high) / 2)
            local chunk = vim.fn.strcharpart(remaining, 0, mid)

            if vim.fn.strwidth(chunk) <= max_width then
                fit = mid
                low = mid + 1
            else
                high = mid - 1
            end
        end

        table.insert(pieces, vim.fn.strcharpart(remaining, 0, fit))
        remaining = vim.fn.strcharpart(remaining, fit)
    end

    if #remaining > 0 or #pieces == 0 then
        table.insert(pieces, remaining)
    end

    return pieces
end

---@param atoms table[]
---@param max_width number
---@return table[][]
local function wrap_atoms(atoms, max_width)
    if max_width < 1 then
        max_width = 1
    end

    local lines = {}
    local current_line = {}
    local current_width = 0

    local function flush_line()
        table.insert(lines, current_line)
        current_line = {}
        current_width = 0
    end

    for _, atom in ipairs(atoms) do
        local atom_width = vim.fn.strwidth(atom.text)
        local has_space = atom.has_leading_space and #current_line > 0
        local separator_width = has_space and 1 or 0
        local needed = atom_width + separator_width

        if atom_width > max_width then
            if #current_line > 0 then
                flush_line()
            end

            local pieces = break_long_text(atom.text, max_width)

            for piece_index, piece_text in ipairs(pieces) do
                table.insert(current_line, {
                    text = piece_text,
                    is_code = atom.is_code,
                    has_leading_space = false,
                })
                current_width = vim.fn.strwidth(piece_text)

                if piece_index < #pieces then
                    flush_line()
                end
            end
        elseif current_width + needed > max_width and #current_line > 0 then
            flush_line()
            table.insert(current_line, {
                text = atom.text,
                is_code = atom.is_code,
                has_leading_space = false,
            })
            current_width = atom_width
        else
            table.insert(current_line, {
                text = atom.text,
                is_code = atom.is_code,
                has_leading_space = has_space,
            })
            current_width = current_width + needed
        end
    end

    if #current_line > 0 then
        flush_line()
    end

    if #lines == 0 then
        table.insert(lines, {})
    end

    return lines
end

---@param line_atoms table[]
---@return string, table[]
local function render_line_atoms(line_atoms)
    local parts = {}
    local highlights = {}
    local cursor_byte = 0

    for _, atom in ipairs(line_atoms) do
        if atom.has_leading_space then
            table.insert(parts, " ")
            cursor_byte = cursor_byte + 1
        end

        local atom_start = cursor_byte
        table.insert(parts, atom.text)
        cursor_byte = cursor_byte + #atom.text

        if atom.is_code then
            table.insert(highlights, {
                relative_start = atom_start,
                relative_end = cursor_byte,
                group = CODE_INLINE_HIGHLIGHT,
            })
        end
    end

    return table.concat(parts), highlights
end

---@param column_widths number[]
---@param max_total_width number
local function shrink_column_widths(column_widths, max_total_width)
    local current_total = 0

    for _, width in ipairs(column_widths) do
        current_total = current_total + width
    end

    while current_total > max_total_width do
        local widest_index = 1
        local widest_value = column_widths[1]

        for index = 2, #column_widths do
            if column_widths[index] > widest_value then
                widest_index = index
                widest_value = column_widths[index]
            end
        end

        if widest_value <= MIN_COLUMN_WIDTH then
            break
        end

        column_widths[widest_index] = widest_value - 1
        current_total = current_total - 1
    end
end

---@param cell_text string
---@return number
local function cell_display_width(cell_text)
    local atoms = tokenize_cell(cell_text)
    local width = 0
    local first = true

    for _, atom in ipairs(atoms) do
        if not first and atom.has_leading_space then
            width = width + 1
        end

        width = width + vim.fn.strwidth(atom.text)
        first = false
    end

    return width
end

---@param node TSNode
---@param buffer_number number
---@return RenderResult
function M.render(node, buffer_number)
    local render = require("markdown.render")
    local result = render.empty_result()

    local header_cells = {}
    local rows = {}

    for child in node:iter_children() do
        local child_type = child:type()

        if child_type == "pipe_table_header" then
            header_cells = extract_cells(child, buffer_number)
        elseif child_type == "pipe_table_row" then
            table.insert(rows, extract_cells(child, buffer_number))
        end
    end

    local column_count = #header_cells

    if column_count == 0 then
        return result
    end

    local column_widths = {}

    for column_index = 1, column_count do
        local max_width = cell_display_width(header_cells[column_index] or "")

        for _, row in ipairs(rows) do
            local row_cell_width = cell_display_width(row[column_index] or "")
            max_width = math.max(max_width, row_cell_width)
        end

        column_widths[column_index] = max_width + 2
    end

    local available_width = get_available_table_width()
    local borders_width = column_count + 1
    local content_budget = math.max(available_width - borders_width, column_count * MIN_COLUMN_WIDTH)
    shrink_column_widths(column_widths, content_budget)

    local function build_border(left_char, middle_char, right_char, fill_char)
        local parts = { left_char }

        for column_index = 1, column_count do
            table.insert(parts, string.rep(fill_char, column_widths[column_index]))

            if column_index < column_count then
                table.insert(parts, middle_char)
            end
        end

        table.insert(parts, right_char)
        return table.concat(parts)
    end

    local function add_border_line(left_char, middle_char, right_char)
        local line_number = #result.lines
        local border_line = build_border(left_char, middle_char, right_char, "\u{2500}")
        table.insert(result.lines, border_line)

        table.insert(result.highlights, {
            line = line_number,
            column_start = 0,
            column_end = #border_line,
            group = "MarkdownTableBorder",
        })
    end

    local function add_content_row(cells, highlight_group)
        local cell_lines = {}
        local row_height = 1

        for column_index = 1, column_count do
            local cell_text = cells[column_index] or ""
            local inner_width = column_widths[column_index] - 2
            local atoms = tokenize_cell(cell_text)
            local wrapped_atom_lines = wrap_atoms(atoms, inner_width)

            local rendered_lines = {}

            for _, line_atoms in ipairs(wrapped_atom_lines) do
                local line_text, line_highlights = render_line_atoms(line_atoms)
                table.insert(rendered_lines, { text = line_text, highlights = line_highlights })
            end

            cell_lines[column_index] = rendered_lines

            if #rendered_lines > row_height then
                row_height = #rendered_lines
            end
        end

        for line_index = 1, row_height do
            local line_number = #result.lines
            local parts = { "\u{2502}" }
            local cursor = #"\u{2502}"

            table.insert(result.highlights, {
                line = line_number,
                column_start = 0,
                column_end = cursor,
                group = "MarkdownTableBorder",
            })

            for column_index = 1, column_count do
                local rendered = cell_lines[column_index][line_index]
                local cell_text = rendered and rendered.text or ""
                local cell_highlights = rendered and rendered.highlights or {}
                local cell_strwidth = vim.fn.strwidth(cell_text)
                local padding_needed = column_widths[column_index] - cell_strwidth - 1
                local padded_cell = " " .. cell_text .. string.rep(" ", math.max(0, padding_needed))

                table.insert(parts, padded_cell)

                local cell_byte_start = cursor + 1
                local cell_byte_end = cursor + 1 + #cell_text

                if #cell_text > 0 then
                    table.insert(result.highlights, {
                        line = line_number,
                        column_start = cell_byte_start,
                        column_end = cell_byte_end,
                        group = highlight_group,
                    })

                    for _, code_highlight in ipairs(cell_highlights) do
                        table.insert(result.highlights, {
                            line = line_number,
                            column_start = cell_byte_start + code_highlight.relative_start,
                            column_end = cell_byte_start + code_highlight.relative_end,
                            group = code_highlight.group,
                        })
                    end
                end

                cursor = cursor + #padded_cell

                local separator = "\u{2502}"
                table.insert(parts, separator)

                table.insert(result.highlights, {
                    line = line_number,
                    column_start = cursor,
                    column_end = cursor + #separator,
                    group = "MarkdownTableBorder",
                })

                cursor = cursor + #separator
            end

            table.insert(result.lines, table.concat(parts))
        end
    end

    add_border_line("\u{250C}", "\u{252C}", "\u{2510}")
    add_content_row(header_cells, "MarkdownTableHeader")
    add_border_line("\u{251C}", "\u{253C}", "\u{2524}")

    for _, row in ipairs(rows) do
        add_content_row(row, "MarkdownTableCell")
    end

    add_border_line("\u{2514}", "\u{2534}", "\u{2518}")

    return result
end

return M
