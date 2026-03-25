---@class MarkdownHighlights
---@field heading_1 table
---@field heading_2 table
---@field heading_3 table
---@field code_block table
---@field code_inline table
---@field bold table
---@field italic table
---@field strikethrough table
---@field link table
---@field bullet_level_1 table
---@field bullet_level_2 table
---@field blockquote_bar table
---@field blockquote_text table
---@field table_border table
---@field table_header table
---@field table_cell table
---@field horizontal_rule table
---@field normal table

---@class MarkdownConfig
---@field auto_open boolean
---@field debounce_ms number
---@field ignore_patterns string[]
---@field padding number
---@field highlights MarkdownHighlights

local M = {}

---@type MarkdownConfig
M.defaults = {
    auto_open = true,
    debounce_ms = 150,
    ignore_patterns = {},
    padding = 4,
    highlights = {
        heading_1 = { fg = "#89ca78", bold = true },
        heading_2 = { fg = "#61afef", bold = true },
        heading_3 = { fg = "#d55fde", bold = true },
        code_block = { bg = "#21252b" },
        code_inline = { fg = "#d19a66", bg = "#3C4048" },
        bold = { fg = "#a5afbe", bold = true },
        italic = { fg = "#a5afbe", italic = true },
        strikethrough = { fg = "#5c6370", strikethrough = true },
        link = { fg = "#61afef", underline = true },
        bullet_level_1 = { fg = "#e5c07b" },
        bullet_level_2 = { fg = "#5c6370" },
        blockquote_bar = { fg = "#5c6370" },
        blockquote_text = { fg = "#5c6370", italic = true },
        table_border = { fg = "#5c6370" },
        table_header = { fg = "#a5afbe", bold = true },
        table_cell = { fg = "#a5afbe" },
        horizontal_rule = { fg = "#5c6370" },
        normal = { fg = "#a5afbe" },
    },
}

---@type MarkdownConfig
M.options = {}

---@param options? MarkdownConfig
function M.setup(options)
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, options or {})
end

---@return MarkdownConfig
function M.get()
    return M.options
end

return M
