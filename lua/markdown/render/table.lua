local treesitter = require("markdown.treesitter")

local M = {}

local MIN_COLUMN_WIDTH = 8
local FALLBACK_AVAILABLE_WIDTH = 200

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
---@param max_width number
---@return string[]
local function wrap_cell_text(text, max_width)
    if max_width < 1 then
        max_width = 1
    end

    if vim.fn.strwidth(text) <= max_width then
        return { text }
    end

    local lines = {}
    local current = ""

    local function break_long_word(word)
        local remaining = word

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

            table.insert(lines, vim.fn.strcharpart(remaining, 0, fit))
            remaining = vim.fn.strcharpart(remaining, fit)
        end

        return remaining
    end

    for word in text:gmatch("%S+") do
        local candidate

        if current == "" then
            candidate = word
        else
            candidate = current .. " " .. word
        end

        if vim.fn.strwidth(candidate) <= max_width then
            current = candidate
        else
            if current ~= "" then
                table.insert(lines, current)
                current = ""
            end

            if vim.fn.strwidth(word) > max_width then
                current = break_long_word(word)
            else
                current = word
            end
        end
    end

    if current ~= "" then
        table.insert(lines, current)
    end

    if #lines == 0 then
        table.insert(lines, "")
    end

    return lines
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
        local max_width = vim.fn.strwidth(header_cells[column_index] or "")

        for _, row in ipairs(rows) do
            local cell_width = vim.fn.strwidth(row[column_index] or "")
            max_width = math.max(max_width, cell_width)
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
        local cell_wrapped = {}
        local row_height = 1

        for column_index = 1, column_count do
            local cell_text = cells[column_index] or ""
            local inner_width = column_widths[column_index] - 2
            local wrapped_lines = wrap_cell_text(cell_text, inner_width)
            cell_wrapped[column_index] = wrapped_lines

            if #wrapped_lines > row_height then
                row_height = #wrapped_lines
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
                local cell_text = cell_wrapped[column_index][line_index] or ""
                local cell_display_width = vim.fn.strwidth(cell_text)
                local padding_needed = column_widths[column_index] - cell_display_width - 1
                local padded_cell = " " .. cell_text .. string.rep(" ", math.max(0, padding_needed))

                table.insert(parts, padded_cell)

                local cell_start = cursor + 1
                local cell_end = cursor + #cell_text + 1

                if #cell_text > 0 then
                    table.insert(result.highlights, {
                        line = line_number,
                        column_start = cell_start,
                        column_end = cell_end,
                        group = highlight_group,
                    })
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
