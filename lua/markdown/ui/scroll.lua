local M = {}

---@param source_buffer number
---@param source_window number
---@param preview_buffer number
---@param preview_window number
function M.sync(source_buffer, source_window, preview_buffer, preview_window)
    if not vim.api.nvim_win_is_valid(source_window) or not vim.api.nvim_win_is_valid(preview_window) then
        return
    end

    local source_line_count = vim.api.nvim_buf_line_count(source_buffer)
    local preview_line_count = vim.api.nvim_buf_line_count(preview_buffer)

    if source_line_count == 0 or preview_line_count == 0 then
        return
    end

    local source_top_line = vim.fn.line("w0", source_window)
    local scroll_percentage = source_top_line / source_line_count
    local target_line = math.max(1, math.floor(scroll_percentage * preview_line_count) + 1)

    vim.api.nvim_win_set_cursor(preview_window, { math.min(target_line, preview_line_count), 0 })
    vim.cmd("redraw")
end

return M
