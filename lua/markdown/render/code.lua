local treesitter = require("markdown.treesitter")

local M = {}

local CODE_INDENT = "  "

---@param node TSNode
---@param buffer_number number
---@return string|nil
local function get_code_content(node, buffer_number)
    for child in node:iter_children() do
        if child:type() == "code_fence_content" then
            return treesitter.get_node_text(child, buffer_number)
        end
    end

    return nil
end

---@param capture_name string
---@param language string
---@return string
local function resolve_highlight_group(capture_name, language)
    local language_specific = "@" .. capture_name .. "." .. language

    local resolved = vim.api.nvim_get_hl(0, { name = language_specific })

    if not resolved or (not resolved.fg and not resolved.bg and not resolved.link) then
        return "@" .. capture_name
    end

    return language_specific
end

---@param content string
---@param language string
---@param base_line number
---@param indent_width number
---@return RenderHighlight[]
local function get_syntax_highlights(content, language, base_line, indent_width)
    local highlights = {}

    local resolved_language = vim.treesitter.language.get_lang(language) or language

    local has_language = pcall(vim.treesitter.language.add, resolved_language)

    if not has_language then
        return highlights
    end

    local has_parser, parser = pcall(vim.treesitter.get_string_parser, content, resolved_language)

    if not has_parser then
        return highlights
    end

    local trees = parser:parse()

    if not trees or #trees == 0 then
        return highlights
    end

    local query_ok, query = pcall(vim.treesitter.query.get, resolved_language, "highlights")

    if not query_ok or not query then
        return highlights
    end

    local content_lines = vim.split(content, "\n", { plain = true })

    for capture_id, node in query:iter_captures(trees[1]:root(), content) do
        local capture_name = query.captures[capture_id]
        local start_row, start_col, end_row, end_col = node:range()
        local highlight_group = resolve_highlight_group(capture_name, resolved_language)

        for row = start_row, end_row do
            local column_start = row == start_row and start_col or 0
            local column_end = row == end_row and end_col or #(content_lines[row + 1] or "")

            if column_end > column_start then
                table.insert(highlights, {
                    line = base_line + row,
                    column_start = indent_width + column_start,
                    column_end = indent_width + column_end,
                    group = highlight_group,
                })
            end
        end
    end

    return highlights
end

---@param node TSNode
---@param buffer_number number
---@return RenderResult
function M.render_block(node, buffer_number)
    local render = require("markdown.render")
    local result = render.empty_result()
    local content = get_code_content(node, buffer_number)

    if not content then
        return result
    end

    local language = treesitter.get_code_block_language(node, buffer_number)

    local code_lines = vim.split(content, "\n", { plain = true })

    local _, block_start_column = node:range()

    if block_start_column > 0 then
        local block_indent = string.rep(" ", block_start_column)

        for index, code_line in ipairs(code_lines) do
            if vim.startswith(code_line, block_indent) then
                code_lines[index] = code_line:sub(block_start_column + 1)
            end
        end
    end

    if #code_lines > 0 and code_lines[#code_lines] == "" then
        table.remove(code_lines)
    end

    local first_code_line = #result.lines

    for _, code_line in ipairs(code_lines) do
        local line_number = #result.lines
        local indented_line = CODE_INDENT .. code_line

        table.insert(result.lines, indented_line)

        table.insert(result.highlights, {
            line = line_number,
            column_start = 0,
            column_end = -1,
            group = "MarkdownCodeBlock",
        })
    end

    if language then
        local trimmed_content = table.concat(code_lines, "\n")
        local syntax_highlights = get_syntax_highlights(
            trimmed_content,
            language,
            first_code_line,
            #CODE_INDENT
        )

        for _, highlight in ipairs(syntax_highlights) do
            table.insert(result.highlights, highlight)
        end
    end

    return result
end

---@param node TSNode
---@param buffer_number number
---@return RenderResult
function M.render_html_block(node, buffer_number)
    local render = require("markdown.render")
    local result = render.empty_result()
    local content = treesitter.get_node_text(node, buffer_number)

    if not content or content == "" then
        return result
    end

    local code_lines = vim.split(content, "\n", { plain = true })

    if #code_lines > 0 and code_lines[#code_lines] == "" then
        table.remove(code_lines)
    end

    local first_code_line = #result.lines

    for _, code_line in ipairs(code_lines) do
        local line_number = #result.lines
        table.insert(result.lines, code_line)

        table.insert(result.highlights, {
            line = line_number,
            column_start = 0,
            column_end = -1,
            group = "MarkdownCodeBlock",
        })
    end

    local trimmed_content = table.concat(code_lines, "\n")
    local syntax_highlights = get_syntax_highlights(trimmed_content, "html", first_code_line, 0)

    for _, highlight in ipairs(syntax_highlights) do
        table.insert(result.highlights, highlight)
    end

    return result
end

return M
