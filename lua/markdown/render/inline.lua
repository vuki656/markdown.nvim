local treesitter = require("markdown.treesitter")

local M = {}

---@class InlineSegment
---@field text string
---@field highlight string|nil

local EMPHASIS_TYPES = {
    strong_emphasis = "MarkdownBold",
    emphasis = "MarkdownItalic",
    strikethrough = "MarkdownStrikethrough",
}

---@param node table
---@return boolean
local function has_nested_formatting(node)
    local node_type = node:type()

    for child in node:iter_children() do
        local child_type = child:type()

        if child_type == node_type then
            return has_nested_formatting(child)
        end

        local is_formatting = EMPHASIS_TYPES[child_type]
            or child_type == "code_span"
            or child_type == "inline_link"
            or child_type == "shortcut_link"

        if is_formatting then
            return true
        end
    end

    return false
end

---@param source_text string
---@return InlineSegment[]
local function parse_inline_segments(source_text)
    local root = treesitter.get_inline_tree(source_text)

    if not root then
        return { { text = source_text, highlight = nil } }
    end

    local segments = {}
    local last_byte = 0

    local function walk_node(node, parent_highlight)
        local node_type = node:type()
        local _, start_col, _, end_col = node:range()

        local emphasis_highlight = EMPHASIS_TYPES[node_type]

        if emphasis_highlight then
            if start_col > last_byte then
                local gap_text = source_text:sub(last_byte + 1, start_col)
                table.insert(segments, { text = gap_text, highlight = parent_highlight })
            end

            if has_nested_formatting(node) then
                local saved_last_byte = last_byte

                local is_double_delimiter = node_type == "strong_emphasis" or node_type == "strikethrough"
                local delimiter_length = is_double_delimiter and 2 or 1
                last_byte = start_col + delimiter_length

                for child in node:iter_children() do
                    if child:named() and child:type() ~= "emphasis_delimiter" then
                        walk_node(child, emphasis_highlight)
                    end
                end

                local end_delimiter_start = end_col - delimiter_length

                if last_byte < end_delimiter_start then
                    table.insert(
                        segments,
                        { text = source_text:sub(last_byte + 1, end_delimiter_start), highlight = emphasis_highlight }
                    )
                end

                last_byte = end_col
                _ = saved_last_byte
            else
                local full_text = source_text:sub(start_col + 1, end_col)
                local inner_text = full_text

                if node_type == "strong_emphasis" then
                    inner_text = full_text:gsub("^%*%*(.-)%*%*$", "%1"):gsub("^__(.-)__$", "%1")
                elseif node_type == "emphasis" then
                    inner_text = full_text:gsub("^%*(.-)%*$", "%1"):gsub("^_(.-)_$", "%1")
                elseif node_type == "strikethrough" then
                    inner_text = full_text:gsub("^~~(.-)~~$", "%1")
                end

                table.insert(segments, { text = inner_text, highlight = emphasis_highlight })
                last_byte = end_col
            end

            return
        elseif node_type == "code_span" then
            if start_col > last_byte then
                local gap_text = source_text:sub(last_byte + 1, start_col)
                table.insert(segments, { text = gap_text, highlight = parent_highlight })
            end

            local full_text = source_text:sub(start_col + 1, end_col)
            local inner_text = full_text:gsub("^`(.-)`$", "%1")
            table.insert(segments, { text = " " .. inner_text .. " ", highlight = "MarkdownCodeInline" })
            last_byte = end_col
            return
        elseif node_type == "inline_link" then
            if start_col > last_byte then
                local gap_text = source_text:sub(last_byte + 1, start_col)
                table.insert(segments, { text = gap_text, highlight = parent_highlight })
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
                local gap_text = source_text:sub(last_byte + 1, start_col)
                table.insert(segments, { text = gap_text, highlight = parent_highlight })
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
                    walk_node(child, parent_highlight)
                end
            end
        end
    end

    walk_node(root, nil)

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
