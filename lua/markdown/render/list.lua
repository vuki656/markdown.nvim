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
---@param buffer_number number
---@return string|nil
local function get_list_item_text(list_item_node, buffer_number)
    for child in list_item_node:iter_children() do
        if child:type() == "paragraph" then
            for grandchild in child:iter_children() do
                if grandchild:type() == "inline" then
                    return treesitter.get_node_text(grandchild, buffer_number)
                end
            end

            return treesitter.get_node_text(child, buffer_number)
        end
    end

    return nil
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

---@param list_item_node TSNode
---@return TSNode|nil
local function get_nested_list(list_item_node)
    for child in list_item_node:iter_children() do
        if child:type() == "list" then
            return child
        end
    end

    return nil
end

---@param list_item_node TSNode
---@return boolean
local function has_trailing_blank_line(list_item_node)
    local item_start_row = list_item_node:range()
    local _, _, item_end_row = list_item_node:range()
    local content_lines = 1

    local nested = get_nested_list(list_item_node)

    if nested then
        local _, _, nested_end_row = nested:range()
        content_lines = nested_end_row - item_start_row
    end

    return (item_end_row - item_start_row) > content_lines
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

    local previous_item_had_trailing_blank = false

    for child in node:iter_children() do
        if child:type() == "list_item" then
            if previous_item_had_trailing_blank then
                table.insert(result.lines, "")
            end

            item_index = item_index + 1
            local item_text = get_list_item_text(child, buffer_number)

            if item_text then
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

                local segments = inline.parse_segments(item_text)
                local line_number = #result.lines
                local text, highlights = inline.segments_to_line(segments, line_number)
                local full_line = display_bullet .. text

                table.insert(result.lines, full_line)

                table.insert(result.highlights, {
                    line = line_number,
                    column_start = #indent,
                    column_end = #display_bullet,
                    group = item_bullet_highlight,
                })

                for _, highlight in ipairs(highlights) do
                    table.insert(result.highlights, {
                        line = highlight.line,
                        column_start = highlight.column_start + #display_bullet,
                        column_end = highlight.column_end + #display_bullet,
                        group = highlight.group,
                    })
                end

                if task_state == "checked" then
                    table.insert(result.highlights, {
                        line = line_number,
                        column_start = #display_bullet,
                        column_end = #full_line,
                        group = "MarkdownCheckboxDoneText",
                    })
                end
            end

            local nested_list = get_nested_list(child)

            if nested_list then
                local nested_result = M.render(nested_list, buffer_number, nesting_level + 1)

                for _, line in ipairs(nested_result.lines) do
                    table.insert(result.lines, line)
                end

                for _, highlight in ipairs(nested_result.highlights) do
                    table.insert(result.highlights, {
                        line = highlight.line + #result.lines - #nested_result.lines,
                        column_start = highlight.column_start,
                        column_end = highlight.column_end,
                        group = highlight.group,
                    })
                end
            end

            previous_item_had_trailing_blank = has_trailing_blank_line(child)
        end
    end

    return result
end

return M
