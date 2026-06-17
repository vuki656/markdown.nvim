local new_set = MiniTest.new_set
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local function wait_for_source(buffer_number)
    child.lua(string.format(
        [[vim.wait(1000, function()
            local state = require("markdown.state")
            return state.is_active() and state.state.source_buffer == %d
        end)]],
        buffer_number
    ))
end

local T = new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "tests/minimal_init.lua" })
            child.lua([[require("markdown").setup({ auto_open = true, debounce_ms = 0 })]])
        end,
        post_case = function()
            child.stop()
        end,
    },
})

T["auto open"] = new_set()

T["auto open"]["switches the preview to a markdown opened in place over an active preview"] = function()
    local first_path = child.fn.tempname() .. ".md"
    child.fn.writefile({ "# First", "", "first body" }, first_path)

    local second_path = child.fn.tempname() .. ".md"
    child.fn.writefile({ "# Second", "", "second body" }, second_path)

    child.cmd("edit " .. first_path)
    child.lua([[vim.bo.filetype = "markdown"]])
    local first_buffer = child.lua_get(string.format([[vim.fn.bufnr(%q)]], first_path))
    wait_for_source(first_buffer)

    child.lua([[vim.api.nvim_set_current_win(require("markdown.state").state.source_window)]])
    child.cmd("edit " .. second_path)
    child.lua([[vim.bo.filetype = "markdown"]])
    local second_buffer = child.lua_get(string.format([[vim.fn.bufnr(%q)]], second_path))
    wait_for_source(second_buffer)

    local source_buffer = child.lua_get([[require("markdown.state").state.source_buffer]])
    local source_window = child.lua_get([[require("markdown.state").state.source_window]])
    local window_buffer = child.lua_get(string.format([[vim.api.nvim_win_get_buf(%d)]], source_window))

    expect.equality(source_buffer, second_buffer)
    expect.equality(window_buffer, second_buffer)
end

return T
