local inline = require("markdown.render.inline")
local treesitter = require("markdown.treesitter")

local M = {}

local HEADING_HIGHLIGHT_MAP = {
    [1] = "MarkdownH1",
    [2] = "MarkdownH2",
    [3] = "MarkdownH3",
    [4] = "MarkdownH3",
    [5] = "MarkdownH3",
    [6] = "MarkdownH3",
}

---@param node TSNode
---@return number
local function get_heading_level(node)
    for child in node:iter_children() do
        local child_type = child:type()

        if child_type == "atx_h1_marker" then
            return 1
        elseif child_type == "atx_h2_marker" then
            return 2
        elseif child_type == "atx_h3_marker" then
            return 3
        elseif child_type == "atx_h4_marker" then
            return 4
        elseif child_type == "atx_h5_marker" then
            return 5
        elseif child_type == "atx_h6_marker" then
            return 6
        end
    end

    return 1
end

---@param node TSNode
---@param buffer_number number
---@return string|nil
local function get_heading_content(node, buffer_number)
    for child in node:iter_children() do
        if child:type() == "inline" then
            return treesitter.get_node_text(child, buffer_number)
        end
    end

    return nil
end

---@param node TSNode
---@param buffer_number number
---@return RenderResult
function M.render(node, buffer_number)
    local render = require("markdown.render")
    local result = render.empty_result()
    local level = get_heading_level(node)
    local content = get_heading_content(node, buffer_number)

    if not content then
        return result
    end

    local highlight_group = HEADING_HIGHLIGHT_MAP[level]
    local segments = inline.parse_segments(content)

    if level == 1 then
        table.insert(result.lines, "")
    end

    if level <= 2 then
        table.insert(result.lines, "")
    end

    local line_number = #result.lines
    local text, highlights = inline.segments_to_line(segments, line_number)
    table.insert(result.lines, text)

    table.insert(result.highlights, {
        line = line_number,
        column_start = 0,
        column_end = #text,
        group = highlight_group,
    })

    for _, highlight in ipairs(highlights) do
        table.insert(result.highlights, highlight)
    end

    if level == 1 then
        table.insert(result.lines, "")
    end

    table.insert(result.lines, "")

    return result
end

return M
