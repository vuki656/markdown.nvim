local M = {}

local RULE_WIDTH = 60

---@return RenderResult
function M.render()
    local render = require("markdown.render")
    local result = render.empty_result()

    local line_number = #result.lines
    local rule_line = string.rep("\u{2500}", RULE_WIDTH)
    table.insert(result.lines, rule_line)

    table.insert(result.highlights, {
        line = line_number,
        column_start = 0,
        column_end = #rule_line,
        group = "MarkdownHorizontalRule",
    })

    return result
end

return M
