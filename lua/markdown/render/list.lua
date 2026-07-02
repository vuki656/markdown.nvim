local inline = require("markdown.render.inline")
local treesitter = require("markdown.treesitter")

local M = {}

local INDENT_WIDTH = 4
local CHECKBOX_UNCHECKED = "\u{2610}"
local CHECKBOX_CHECKED = "\u{2611}"

---@param node TSNode
---@return boolean
local function is_ordered_list(node)
    for child in node:iter_children() do
        if child:type() == "list_item" then
            for list_child in child:iter_children() do
                local child_type = list_child:type()

                if child_type == "list_marker_dot" or child_type == "list_marker_parenthesis" then
                    return true
                end
            end

            break
        end
    end

    return false
end

---@param list_item_node TSNode
---@return "checked"|"unchecked"|nil
local function get_task_marker_state(list_item_node)
    for child in list_item_node:iter_children() do
        local child_type = child:type()

        if child_type == "task_list_marker_checked" then
            return "checked"
        elseif child_type == "task_list_marker_unchecked" then
            return "unchecked"
        end
    end

    return nil
end

---@param paragraph_node TSNode
---@param buffer_number number
---@return string
local function get_paragraph_text(paragraph_node, buffer_number)
    for child in paragraph_node:iter_children() do
        if child:type() == "inline" then
            return treesitter.get_node_text(child, buffer_number)
        end
    end

    return treesitter.get_node_text(paragraph_node, buffer_number)
end

---@param result RenderResult
---@param count number
local function append_blank_lines(result, count)
    for _ = 1, count do
        table.insert(result.lines, "")
    end
end

---@param result RenderResult
---@param addition RenderResult
---@param prefix string
local function append_indented(result, addition, prefix)
    local base_line = #result.lines

    for _, line in ipairs(addition.lines) do
        table.insert(result.lines, line == "" and "" or prefix .. line)
    end

    for _, highlight in ipairs(addition.highlights) do
        table.insert(result.highlights, {
            line = highlight.line + base_line,
            column_start = highlight.column_start + #prefix,
            column_end = highlight.column_end == -1 and -1 or highlight.column_end + #prefix,
            group = highlight.group,
        })
    end
end

---@param paragraph_node TSNode
---@param buffer_number number
---@param first_line_prefix string
---@param continuation_prefix string
---@param result RenderResult
local function render_paragraph(paragraph_node, buffer_number, first_line_prefix, continuation_prefix, result)
    local text = get_paragraph_text(paragraph_node, buffer_number)
    local segments = inline.parse_segments(text)
    local lines, highlights = inline.segments_to_lines(segments)
    local base_line = #result.lines

    for line_index, line_text in ipairs(lines) do
        local prefix = line_index == 1 and first_line_prefix or continuation_prefix
        table.insert(result.lines, prefix .. line_text)
    end

    for _, highlight in ipairs(highlights) do
        local prefix = highlight.line == 0 and first_line_prefix or continuation_prefix

        table.insert(result.highlights, {
            line = highlight.line + base_line,
            column_start = highlight.column_start + #prefix,
            column_end = highlight.column_end + #prefix,
            group = highlight.group,
        })
    end
end

---@param node TSNode
---@param buffer_number number
---@param nesting_level number
---@return RenderResult
function M.render(node, buffer_number, nesting_level)
    local render = require("markdown.render")
    local result = render.empty_result()
    local ordered = is_ordered_list(node)
    local item_index = 0
    local indent = string.rep(" ", INDENT_WIDTH * nesting_level)
    local bullet_highlight = nesting_level == 0 and "MarkdownBulletL1" or "MarkdownBulletL2"

    local previous_item_end_row = nil

    for child in node:iter_children() do
        if child:type() == "list_item" then
            local item_start_row = child:range()

            if previous_item_end_row then
                append_blank_lines(result, math.max(item_start_row - previous_item_end_row, 0))
            end

            item_index = item_index + 1
            local task_state = get_task_marker_state(child)
            local bullet_char
            local item_bullet_highlight = bullet_highlight

            if task_state == "checked" then
                bullet_char = CHECKBOX_CHECKED
                item_bullet_highlight = "MarkdownCheckboxChecked"
            elseif task_state == "unchecked" then
                bullet_char = CHECKBOX_UNCHECKED
                item_bullet_highlight = "MarkdownCheckboxUnchecked"
            elseif ordered then
                bullet_char = item_index .. "."
            else
                bullet_char = nesting_level == 0 and "\u{2022}" or "\u{25E6}"
            end

            local display_bullet = indent .. bullet_char .. " "
            local continuation_indent = string.rep(" ", vim.fn.strdisplaywidth(display_bullet))

            local bullet_rendered = false
            local previous_block_end_row = nil

            for block in child:iter_children() do
                local block_type = block:type()

                if block_type == "paragraph" or block_type == "list" or block_type == "fenced_code_block" then
                    local block_start_row = block:range()

                    if previous_block_end_row then
                        append_blank_lines(result, math.max(block_start_row - previous_block_end_row, 0))
                    end

                    if block_type == "paragraph" then
                        local first_line_prefix = bullet_rendered and continuation_indent or display_bullet
                        local paragraph_start_line = #result.lines

                        render_paragraph(block, buffer_number, first_line_prefix, continuation_indent, result)

                        if not bullet_rendered then
                            table.insert(result.highlights, {
                                line = paragraph_start_line,
                                column_start = #indent,
                                column_end = #display_bullet,
                                group = item_bullet_highlight,
                            })
                        end

                        if task_state == "checked" then
                            for line_number = paragraph_start_line, #result.lines - 1 do
                                local line_prefix = line_number == paragraph_start_line and first_line_prefix
                                    or continuation_indent

                                table.insert(result.highlights, {
                                    line = line_number,
                                    column_start = #line_prefix,
                                    column_end = #result.lines[line_number + 1],
                                    group = "MarkdownCheckboxDoneText",
                                })
                            end
                        end

                        bullet_rendered = true
                    elseif block_type == "list" then
                        append_indented(result, M.render(block, buffer_number, nesting_level + 1), "")
                    else
                        local code = require("markdown.render.code")
                        append_indented(result, code.render_block(block, buffer_number), continuation_indent)
                    end

                    previous_block_end_row = render.get_content_end_row(block, buffer_number)
                end
            end

            previous_item_end_row = render.get_content_end_row(child, buffer_number)
        end
    end

    return result
end

return M
