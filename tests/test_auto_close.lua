local expect = MiniTest.expect
local markdown = require("markdown")
local state = require("markdown.state")

local function reset_environment()
    state.reset()

    for _, window_id in ipairs(vim.api.nvim_list_wins()) do
        pcall(vim.api.nvim_win_close, window_id, true)
    end

    vim.cmd("silent! %bwipeout!")
    vim.cmd("enew")
end

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            markdown.setup({ auto_open = true, debounce_ms = 0 })
            reset_environment()
        end,
        post_case = reset_environment,
    },
})

T["auto close"] = MiniTest.new_set()

T["auto close"]["closes the preview when a non-markdown file is opened from the preview window"] = function()
    local markdown_path = vim.fn.tempname() .. ".md"
    vim.fn.writefile({ "# Heading", "", "body" }, markdown_path)

    local text_path = vim.fn.tempname() .. ".txt"
    vim.fn.writefile({ "plain text" }, text_path)

    vim.cmd("edit " .. markdown_path)
    vim.bo.filetype = "markdown"
    vim.wait(200, function()
        return state.is_active()
    end)
    expect.equality(state.is_active(), true)

    vim.api.nvim_set_current_win(state.state.preview_window)
    vim.wait(50)
    vim.cmd("edit " .. text_path)
    vim.wait(200, function()
        return not state.is_active()
    end)

    expect.equality(state.is_active(), false)
end

return T
