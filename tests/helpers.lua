local M = {}

---@param markdown_text string
---@return number buffer_number
function M.create_markdown_buffer(markdown_text)
    local buffer_number = vim.api.nvim_create_buf(false, true)
    local lines = vim.split(markdown_text, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(buffer_number, 0, -1, false, lines)
    vim.bo[buffer_number].filetype = "markdown"

    return buffer_number
end

---@param buffer_number number
function M.delete_buffer(buffer_number)
    if vim.api.nvim_buf_is_valid(buffer_number) then
        vim.api.nvim_buf_delete(buffer_number, { force = true })
    end
end

---@param highlights table[]
---@param group string
---@return table[]
function M.filter_highlights(highlights, group)
    local filtered = {}

    for _, highlight in ipairs(highlights) do
        if highlight.group == group then
            table.insert(filtered, highlight)
        end
    end

    return filtered
end

function M.capture_notifications()
    local captured = {}
    local original_notify = vim.notify

    vim.notify = function(message, level, options)
        table.insert(captured, { message = message, level = level, options = options })
    end

    local function restore()
        vim.notify = original_notify
    end

    return captured, restore
end

return M
