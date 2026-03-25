local M = {}

function M.setup()
    vim.api.nvim_create_user_command("MarkdownPreview", function()
        require("markdown").open()
    end, {
        desc = "Open markdown preview",
    })

    vim.api.nvim_create_user_command("MarkdownPreviewClose", function()
        require("markdown").close()
    end, {
        desc = "Close markdown preview",
    })

    vim.api.nvim_create_user_command("MarkdownPreviewToggle", function()
        require("markdown").toggle()
    end, {
        desc = "Toggle markdown preview",
    })
end

return M
