local commands = require("markdown.commands")
local config = require("markdown.config")
local highlights = require("markdown.ui.highlights")
local state = require("markdown.state")
local preview_ui = require("markdown.ui")

local M = {}

local function should_ignore(filepath)
    local patterns = config.get().ignore_patterns

    for _, pattern in ipairs(patterns) do
        if filepath:match(pattern) then
            return true
        end
    end

    return false
end

local function is_preview_buffer(buffer_number)
    return buffer_number == state.state.preview_buffer
end

local function render_and_update()
    if not state.is_active() then
        return
    end

    if not vim.api.nvim_buf_is_valid(state.state.source_buffer) then
        return
    end

    local render = require("markdown.render")
    local result = render.render(state.state.source_buffer)

    vim.bo[state.state.preview_buffer].modifiable = true
    vim.api.nvim_buf_set_lines(state.state.preview_buffer, 0, -1, false, result.lines)
    vim.bo[state.state.preview_buffer].modifiable = false

    local namespace = vim.api.nvim_create_namespace("markdown_preview")
    vim.api.nvim_buf_clear_namespace(state.state.preview_buffer, namespace, 0, -1)

    for _, highlight in ipairs(result.highlights) do
        vim.api.nvim_buf_set_extmark(state.state.preview_buffer, namespace, highlight.line, highlight.column_start, {
            end_col = highlight.column_end ~= -1 and highlight.column_end or nil,
            end_row = highlight.column_end == -1 and highlight.line or nil,
            hl_eol = highlight.column_end == -1,
            hl_group = highlight.group,
        })
    end
end

local function schedule_render()
    local debounce_ms = config.get().debounce_ms

    if state.state.debounce_timer then
        state.state.debounce_timer:stop()
    end

    if not state.state.debounce_timer then
        state.state.debounce_timer = vim.uv.new_timer()
    end

    state.state.debounce_timer:start(
        debounce_ms,
        0,
        vim.schedule_wrap(function()
            render_and_update()
        end)
    )
end

local function setup_buffer_autocmds(source_buffer)
    local group = vim.api.nvim_create_augroup("MarkdownPreviewBuffer", { clear = true })
    state.state.autocmd_group = group

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group,
        buffer = source_buffer,
        callback = function()
            schedule_render()
        end,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        group = group,
        buffer = source_buffer,
        callback = function()
            M.close()
        end,
    })

    vim.api.nvim_create_autocmd("WinScrolled", {
        group = group,
        callback = function()
            if not state.is_active() then
                return
            end

            local current_window = vim.api.nvim_get_current_win()

            if current_window == state.state.source_window then
                local scroll = require("markdown.ui.scroll")
                scroll.sync(
                    state.state.source_buffer,
                    state.state.source_window,
                    state.state.preview_buffer,
                    state.state.preview_window
                )
            end
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        pattern = tostring(state.state.preview_window),
        callback = function()
            state.reset()
        end,
    })
end

---@param options? MarkdownConfig
function M.setup(options)
    config.setup(options)
    highlights.setup()
    commands.setup()

    if config.get().auto_open then
        vim.api.nvim_create_autocmd("BufEnter", {
            group = vim.api.nvim_create_augroup("MarkdownPreviewAutoOpen", { clear = true }),
            pattern = "*.md",
            callback = function(event)
                if is_preview_buffer(event.buf) then
                    return
                end

                if vim.bo[event.buf].buftype ~= "" then
                    return
                end

                local filepath = vim.api.nvim_buf_get_name(event.buf)

                if should_ignore(filepath) then
                    return
                end

                vim.schedule(function()
                    M.open()
                end)
            end,
        })

        vim.api.nvim_create_autocmd("BufLeave", {
            group = vim.api.nvim_create_augroup("MarkdownPreviewAutoClose", { clear = true }),
            pattern = "*.md",
            callback = function()
                if not state.is_active() then
                    return
                end

                vim.schedule(function()
                    local current_buffer = vim.api.nvim_get_current_buf()

                    if is_preview_buffer(current_buffer) then
                        return
                    end

                    local current_filetype = vim.bo[current_buffer].filetype

                    if current_filetype == "markdown" then
                        return
                    end

                    M.close()
                end)
            end,
        })
    end
end

function M.open()
    if state.is_active() then
        local current_buffer = vim.api.nvim_get_current_buf()

        if current_buffer == state.state.source_buffer then
            return
        end

        M.close()
    end

    local source_buffer = vim.api.nvim_get_current_buf()
    local source_window = vim.api.nvim_get_current_win()

    preview_ui.open(source_buffer, source_window)
    setup_buffer_autocmds(source_buffer)

    vim.api.nvim_set_current_win(source_window)

    render_and_update()
end

function M.close()
    if state.state.autocmd_group then
        vim.api.nvim_del_augroup_by_id(state.state.autocmd_group)
    end

    preview_ui.close()
    state.reset()
end

function M.toggle()
    if state.is_active() then
        M.close()
    else
        M.open()
    end
end

return M
