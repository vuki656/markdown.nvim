local state = require("markdown.state")

local M = {}

local function apply_window_options(window_id)
    vim.wo[window_id].number = false
    vim.wo[window_id].relativenumber = false
    vim.wo[window_id].signcolumn = "no"
    vim.wo[window_id].foldcolumn = "0"
    vim.wo[window_id].statusline = " "
    vim.wo[window_id].cursorline = false
    vim.wo[window_id].wrap = true
    vim.wo[window_id].linebreak = true
    vim.wo[window_id].spell = false
    vim.wo[window_id].list = false
end

---@param source_buffer number
---@param source_window number
function M.open(source_buffer, source_window)
    local preview_buffer = vim.api.nvim_create_buf(false, true)
    vim.bo[preview_buffer].buftype = "nofile"
    vim.bo[preview_buffer].modifiable = false
    vim.bo[preview_buffer].swapfile = false
    vim.bo[preview_buffer].filetype = "markdown_preview"

    vim.cmd("vsplit")
    local preview_window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(preview_window, preview_buffer)

    local total_width = vim.o.columns
    local half_width = math.floor(total_width / 2)
    vim.api.nvim_win_set_width(preview_window, half_width)

    apply_window_options(preview_window)

    vim.api.nvim_win_set_hl_ns(preview_window, vim.api.nvim_create_namespace("markdown_preview_window"))

    state.state.is_open = true
    state.state.source_buffer = source_buffer
    state.state.source_window = source_window
    state.state.preview_buffer = preview_buffer
    state.state.preview_window = preview_window
end

function M.close()
    if state.state.preview_window and vim.api.nvim_win_is_valid(state.state.preview_window) then
        vim.api.nvim_win_close(state.state.preview_window, true)
    end

    if state.state.preview_buffer and vim.api.nvim_buf_is_valid(state.state.preview_buffer) then
        vim.api.nvim_buf_delete(state.state.preview_buffer, { force = true })
    end
end

return M
