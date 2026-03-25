local M = {}

function M.setup()
    vim.api.nvim_create_user_command("MarkdownPreview", function()
        require("markdown").open()
    end, {
        desc = "Open markdown pretty preview",
    })

    vim.api.nvim_create_user_command("MarkdownEdit", function()
        require("markdown").edit()
    end, {
        desc = "Switch to raw markdown editing",
    })

    vim.api.nvim_create_user_command("MarkdownSplit", function()
        require("markdown").split()
    end, {
        desc = "Show raw and pretty side by side",
    })
end

return M
