local M = {}

---@param buffer_number number
---@return TSNode|nil
function M.parse_buffer(buffer_number)
    local has_parser, parser = pcall(vim.treesitter.get_parser, buffer_number, "markdown")

    if not has_parser then
        vim.notify("markdown.nvim: treesitter markdown parser not found", vim.log.levels.ERROR)
        return nil
    end

    local trees = parser:parse()

    if not trees or #trees == 0 then
        return nil
    end

    return trees[1]:root()
end

---@param node TSNode
---@param buffer_number number
---@return string
function M.get_node_text(node, buffer_number)
    return vim.treesitter.get_node_text(node, buffer_number)
end

---@param source_text string
---@return TSNode|nil
function M.get_inline_tree(source_text)
    local has_parser, parser = pcall(vim.treesitter.get_string_parser, source_text, "markdown_inline")

    if not has_parser then
        return nil
    end

    local trees = parser:parse()

    if not trees or #trees == 0 then
        return nil
    end

    return trees[1]:root()
end

---@param node TSNode
---@return fun(): TSNode|nil, string|nil
function M.iter_children(node)
    local index = 0
    local child_count = node:named_child_count()

    return function()
        if index >= child_count then
            return nil, nil
        end

        local child = node:named_child(index)
        index = index + 1

        if child then
            return child, child:type()
        end

        return nil, nil
    end
end

---@param fenced_code_node TSNode
---@param buffer_number number
---@return string|nil
function M.get_code_block_language(fenced_code_node, buffer_number)
    for child in fenced_code_node:iter_children() do
        if child:type() == "info_string" then
            local language = vim.trim(M.get_node_text(child, buffer_number))

            if language ~= "" then
                return language
            end
        end
    end

    return nil
end

return M
