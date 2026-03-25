local treesitter = require("markdown.treesitter")

local M = {}

---@class InlineSegment
---@field text string
---@field highlight string|nil

---@param source_text string
---@return InlineSegment[]
local function parse_inline_segments(source_text)
    local root = treesitter.get_inline_tree(source_text)

    if not root then
        return { { text = source_text, highlight = nil } }
    end

    local segments = {}
    local last_byte = 0

    local function walk_node(node)
        local node_type = node:type()
        local _, start_col, _, end_col = node:range()

        if node_type == "strong_emphasis" then
            if start_col > last_byte then
                table.insert(segments, { text = source_text:sub(last_byte + 1, start_col), highlight = nil })
            end

            local full_text = source_text:sub(start_col + 1, end_col)
            local inner_text = full_text:gsub("^%*%*(.-)%*%*$", "%1"):gsub("^__(.-)__$", "%1")
            table.insert(segments, { text = inner_text, highlight = "MarkdownBold" })
            last_byte = end_col
            return
        elseif node_type == "emphasis" then
            if start_col > last_byte then
                table.insert(segments, { text = source_text:sub(last_byte + 1, start_col), highlight = nil })
            end

            local full_text = source_text:sub(start_col + 1, end_col)
            local inner_text = full_text:gsub("^%*(.-)%*$", "%1"):gsub("^_(.-)_$", "%1")
            table.insert(segments, { text = inner_text, highlight = "MarkdownItalic" })
            last_byte = end_col
            return
        elseif node_type == "strikethrough" then
            if start_col > last_byte then
                table.insert(segments, { text = source_text:sub(last_byte + 1, start_col), highlight = nil })
            end

            local full_text = source_text:sub(start_col + 1, end_col)
            local inner_text = full_text:gsub("^~~(.-)~~$", "%1")
            table.insert(segments, { text = inner_text, highlight = "MarkdownStrikethrough" })
            last_byte = end_col
            return
        elseif node_type == "code_span" then
            if start_col > last_byte then
                table.insert(segments, { text = source_text:sub(last_byte + 1, start_col), highlight = nil })
            end

            local full_text = source_text:sub(start_col + 1, end_col)
            local inner_text = full_text:gsub("^`(.-)`$", "%1")
            table.insert(segments, { text = inner_text, highlight = "MarkdownCodeInline" })
            last_byte = end_col
            return
        elseif node_type == "inline_link" then
            if start_col > last_byte then
                table.insert(segments, { text = source_text:sub(last_byte + 1, start_col), highlight = nil })
            end

            local link_text = nil

            for child in node:iter_children() do
                if child:type() == "link_text" then
                    local _, child_start, _, child_end = child:range()
                    link_text = source_text:sub(child_start + 1, child_end)
                    break
                end
            end

            if link_text then
                table.insert(segments, { text = link_text, highlight = "MarkdownLink" })
            end

            last_byte = end_col
            return
        elseif node_type == "shortcut_link" then
            if start_col > last_byte then
                table.insert(segments, { text = source_text:sub(last_byte + 1, start_col), highlight = nil })
            end

            local full_text = source_text:sub(start_col + 1, end_col)
            local inner_text = full_text:gsub("^%[(.-)%]$", "%1")
            table.insert(segments, { text = inner_text, highlight = "MarkdownLink" })
            last_byte = end_col
            return
        end

        if node:named_child_count() > 0 then
            for child in node:iter_children() do
                if child:named() then
                    walk_node(child)
                end
            end
        end
    end

    walk_node(root)

    if last_byte < #source_text then
        table.insert(segments, { text = source_text:sub(last_byte + 1), highlight = nil })
    end

    return segments
end

---@param segments InlineSegment[]
---@param line_number number
---@return string
---@return RenderHighlight[]
function M.segments_to_line(segments, line_number)
    local text = ""
    local highlights = {}

    for _, segment in ipairs(segments) do
        local start_col = #text

        text = text .. segment.text

        if segment.highlight then
            table.insert(highlights, {
                line = line_number,
                column_start = start_col,
                column_end = start_col + #segment.text,
                group = segment.highlight,
            })
        end
    end

    return text, highlights
end

---@param source_text string
---@return RenderResult
function M.render(source_text)
    local render = require("markdown.render")
    local result = render.empty_result()
    local raw_lines = vim.split(source_text, "\n", { plain = true })

    for _, raw_line in ipairs(raw_lines) do
        local segments = parse_inline_segments(raw_line)
        local line_number = #result.lines
        local text, highlights = M.segments_to_line(segments, line_number)

        table.insert(result.lines, text)

        for _, highlight in ipairs(highlights) do
            table.insert(result.highlights, highlight)
        end
    end

    return result
end

---@param source_text string
---@return InlineSegment[]
function M.parse_segments(source_text)
    return parse_inline_segments(source_text)
end

return M
