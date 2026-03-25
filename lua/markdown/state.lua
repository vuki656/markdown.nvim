---@alias MarkdownViewMode "pretty"|"edit"|"split"

---@class MarkdownPreviewState
---@field is_open boolean
---@field mode MarkdownViewMode
---@field source_buffer number|nil
---@field source_window number|nil
---@field preview_buffer number|nil
---@field preview_window number|nil
---@field debounce_timer uv.uv_timer_t|nil
---@field autocmd_group number|nil

local M = {}

local DEFAULT_STATE = {
    is_open = false,
    mode = "pretty",
    source_buffer = nil,
    source_window = nil,
    preview_buffer = nil,
    preview_window = nil,
    debounce_timer = nil,
    autocmd_group = nil,
}

---@type MarkdownPreviewState
M.state = vim.deepcopy(DEFAULT_STATE)

function M.reset()
    if M.state.debounce_timer then
        M.state.debounce_timer:stop()
        M.state.debounce_timer:close()
    end

    M.state = vim.deepcopy(DEFAULT_STATE)
end

---@return boolean
function M.is_active()
    if not M.state.is_open then
        return false
    end

    if not M.state.preview_buffer or not vim.api.nvim_buf_is_valid(M.state.preview_buffer) then
        return false
    end

    return true
end

return M
