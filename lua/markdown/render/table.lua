local treesitter = require("markdown.treesitter")

local M = {}

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
            local cell_text = cells[column_index] or ""
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
