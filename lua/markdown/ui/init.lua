local state = require("markdown.state")

local M = {}

local function apply_preview_window_options(window_id, mode)
    vim.wo[window_id].number = mode == "pretty"
    vim.wo[window_id].relativenumber = false
    vim.wo[window_id].signcolumn = "no"
    vim.wo[window_id].foldcolumn = "0"
    vim.wo[window_id].statusline = " "
    vim.wo[window_id].cursorline = false
    vim.wo[window_id].wrap = true
    vim.wo[window_id].linebreak = true
    vim.wo[window_id].breakindent = true
    vim.wo[window_id].spell = false
    vim.wo[window_id].list = false
end

local function create_preview_buffer()
    local preview_buffer = vim.api.nvim_create_buf(false, true)
    vim.bo[preview_buffer].buftype = "nofile"
    vim.bo[preview_buffer].modifiable = false
    vim.bo[preview_buffer].swapfile = false
    vim.bo[preview_buffer].filetype = "markdown_preview"

    return preview_buffer
end

---@param source_buffer number
---@param source_window number
function M.open_pretty(source_buffer, source_window)
    local preview_buffer = create_preview_buffer()

    vim.api.nvim_win_set_buf(source_window, preview_buffer)
    apply_preview_window_options(source_window, "pretty")

    state.state.is_open = true
    state.state.mode = "pretty"
    state.state.source_buffer = source_buffer
    state.state.source_window = source_window
    state.state.preview_buffer = preview_buffer
    state.state.preview_window = source_window
end

---@param source_buffer number
---@param source_window number
function M.open_split(source_buffer, source_window)
    local preview_buffer = create_preview_buffer()

    vim.cmd("vsplit")
    local preview_window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(preview_window, preview_buffer)

    local total_width = vim.o.columns
    local half_width = math.floor(total_width / 2)
    vim.api.nvim_win_set_width(preview_window, half_width)

    apply_preview_window_options(preview_window, "split")

    state.state.is_open = true
    state.state.mode = "split"
    state.state.source_buffer = source_buffer
    state.state.source_window = source_window
    state.state.preview_buffer = preview_buffer
    state.state.preview_window = preview_window
end

function M.switch_to_edit()
    if state.state.mode == "split" and state.state.preview_window then
        if vim.api.nvim_win_is_valid(state.state.preview_window) then
            vim.api.nvim_win_close(state.state.preview_window, true)
        end
    elseif state.state.mode == "pretty" and state.state.source_window then
        if vim.api.nvim_win_is_valid(state.state.source_window) then
            vim.api.nvim_win_set_buf(state.state.source_window, state.state.source_buffer)
        end
    end

    if state.state.preview_buffer and vim.api.nvim_buf_is_valid(state.state.preview_buffer) then
        vim.api.nvim_buf_delete(state.state.preview_buffer, { force = true })
    end

    if state.state.source_window and vim.api.nvim_win_is_valid(state.state.source_window) then
        vim.api.nvim_set_current_win(state.state.source_window)
    end
end

function M.close()
    if state.state.mode == "pretty" and state.state.source_window then
        if vim.api.nvim_win_is_valid(state.state.source_window) then
            vim.api.nvim_win_set_buf(state.state.source_window, state.state.source_buffer)
        end
    end

    if state.state.mode == "split" and state.state.preview_window then
        if state.state.preview_window ~= state.state.source_window then
            if vim.api.nvim_win_is_valid(state.state.preview_window) then
                vim.api.nvim_win_close(state.state.preview_window, true)
            end
        end
    end

    if state.state.preview_buffer and vim.api.nvim_buf_is_valid(state.state.preview_buffer) then
        vim.api.nvim_buf_delete(state.state.preview_buffer, { force = true })
    end
end

return M
