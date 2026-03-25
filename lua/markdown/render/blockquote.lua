local treesitter = require("markdown.treesitter")

local M = {}

local BLOCKQUOTE_BAR = "\u{2595} "

---@param node TSNode
---@param buffer_number number
---@return RenderResult
function M.render(node, buffer_number)
    local render = require("markdown.render")
    local result = render.empty_result()
    local full_text = treesitter.get_node_text(node, buffer_number)

    local raw_lines = vim.split(full_text, "\n", { plain = true })

    for _, raw_line in ipairs(raw_lines) do
        local line_number = #result.lines
        local stripped = raw_line:gsub("^>%s?", "")
        local display_line = BLOCKQUOTE_BAR .. stripped

        table.insert(result.lines, display_line)

        local bar_byte_length = #BLOCKQUOTE_BAR

        table.insert(result.highlights, {
            line = line_number,
            column_start = 0,
            column_end = bar_byte_length,
            group = "MarkdownBlockquoteBar",
        })

        table.insert(result.highlights, {
            line = line_number,
            column_start = bar_byte_length,
            column_end = #display_line,
            group = "MarkdownBlockquoteText",
        })
    end

    return result
end

return M
