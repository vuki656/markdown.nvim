if vim.g.loaded_markdown_preview then
    return
end
vim.g.loaded_markdown_preview = true

if vim.fn.has("nvim-0.11") ~= 1 then
    vim.notify("markdown.nvim requires Neovim 0.11 or later", vim.log.levels.ERROR)
    return
end
