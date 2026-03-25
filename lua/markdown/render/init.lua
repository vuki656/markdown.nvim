local config = require("markdown.config")
local treesitter = require("markdown.treesitter")

local M = {}

---@class RenderHighlight
---@field line number
---@field column_start number
---@field column_end number
---@field group string

---@class RenderResult
---@field lines string[]
---@field highlights RenderHighlight[]

---@return RenderResult
function M.empty_result()
    return { lines = {}, highlights = {} }
end

---@param result RenderResult
---@param addition RenderResult
---@param line_offset number
local function append_result(result, addition, line_offset)
    for _, line in ipairs(addition.lines) do
        if line:find("\n") then
            for _, split_line in ipairs(vim.split(line, "\n", { plain = true })) do
                table.insert(result.lines, split_line)
            end
        else
            table.insert(result.lines, line)
        end
    end

    for _, highlight in ipairs(addition.highlights) do
        table.insert(result.highlights, {
            line = highlight.line + line_offset,
            column_start = highlight.column_start,
            column_end = highlight.column_end,
            group = highlight.group,
        })
    end
end

---@param result RenderResult
---@param padding_width number
local function apply_padding(result, padding_width)
    local padding = string.rep(" ", padding_width)

    for index, line in ipairs(result.lines) do
        if line ~= "" then
            result.lines[index] = padding .. line
        end
    end

    for _, highlight in ipairs(result.highlights) do
        highlight.column_start = highlight.column_start + padding_width
        if highlight.column_end ~= -1 then
            highlight.column_end = highlight.column_end + padding_width
        end
    end
end

---@param node TSNode
---@param buffer_number number
---@return RenderResult
local function render_node(node, buffer_number)
    local node_type = node:type()

    if node_type == "atx_heading" then
        local heading = require("markdown.render.heading")
        return heading.render(node, buffer_number)
    elseif node_type == "fenced_code_block" then
        local code = require("markdown.render.code")
        return code.render_block(node, buffer_number)
    elseif node_type == "list" then
        local list = require("markdown.render.list")
        return list.render(node, buffer_number, 0)
    elseif node_type == "pipe_table" then
        local markdown_table = require("markdown.render.table")
        return markdown_table.render(node, buffer_number)
    elseif node_type == "block_quote" then
        local blockquote = require("markdown.render.blockquote")
        return blockquote.render(node, buffer_number)
    elseif node_type == "thematic_break" then
        local horizontal_rule = require("markdown.render.horizontal_rule")
        return horizontal_rule.render()
    elseif node_type == "paragraph" then
        local inline = require("markdown.render.inline")
        local text = treesitter.get_node_text(node, buffer_number)
        return inline.render(text)
    elseif node_type == "section" then
        return M.render_section(node, buffer_number)
    else
        local text = treesitter.get_node_text(node, buffer_number)
        local result = M.empty_result()
        local split_lines = vim.split(text, "\n", { plain = true })

        for _, split_line in ipairs(split_lines) do
            table.insert(result.lines, split_line)
        end

        return result
    end
end

---@param section_node TSNode
---@param buffer_number number
---@return RenderResult
function M.render_section(section_node, buffer_number)
    local result = M.empty_result()

    for child, child_type in treesitter.iter_children(section_node) do
        if child_type == "section" then
            local section_result = M.render_section(child, buffer_number)
            append_result(result, section_result, #result.lines)
        else
            local node_result = render_node(child, buffer_number)
            append_result(result, node_result, #result.lines)
        end
    end

    return result
end

---@param buffer_number number
---@return RenderResult
function M.render(buffer_number)
    local root = treesitter.parse_buffer(buffer_number)

    if not root then
        return M.empty_result()
    end

    local result = M.empty_result()

    for child, child_type in treesitter.iter_children(root) do
        if child_type == "section" then
            local section_result = M.render_section(child, buffer_number)
            append_result(result, section_result, #result.lines)
        else
            local node_result = render_node(child, buffer_number)
            append_result(result, node_result, #result.lines)
        end
    end

    local padding_width = config.get().padding
    apply_padding(result, padding_width)

    return result
end

return M
