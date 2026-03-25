local M = {}

---@param source_window number
---@param preview_window number
function M.bind(source_window, preview_window)
    vim.wo[source_window].scrollbind = true
    vim.wo[preview_window].scrollbind = true
end

---@param source_window number
---@param preview_window number
function M.unbind(source_window, preview_window)
    if vim.api.nvim_win_is_valid(source_window) then
        vim.wo[source_window].scrollbind = false
    end

    if vim.api.nvim_win_is_valid(preview_window) then
        vim.wo[preview_window].scrollbind = false
    end
end

return M
