local config = require("markdown.config")

local M = {}

local HIGHLIGHT_MAP = {
    { group = "MarkdownH1", key = "heading_1" },
    { group = "MarkdownH2", key = "heading_2" },
    { group = "MarkdownH3", key = "heading_3" },
    { group = "MarkdownCodeBlock", key = "code_block" },
    { group = "MarkdownCodeInline", key = "code_inline" },
    { group = "MarkdownBold", key = "bold" },
    { group = "MarkdownItalic", key = "italic" },
    { group = "MarkdownStrikethrough", key = "strikethrough" },
    { group = "MarkdownLink", key = "link" },
    { group = "MarkdownBulletL1", key = "bullet_level_1" },
    { group = "MarkdownBulletL2", key = "bullet_level_2" },
    { group = "MarkdownCheckboxUnchecked", key = "checkbox_unchecked" },
    { group = "MarkdownCheckboxChecked", key = "checkbox_checked" },
    { group = "MarkdownCheckboxDoneText", key = "checkbox_done_text" },
    { group = "MarkdownBlockquoteBar", key = "blockquote_bar" },
    { group = "MarkdownBlockquoteText", key = "blockquote_text" },
    { group = "MarkdownTableBorder", key = "table_border" },
    { group = "MarkdownTableHeader", key = "table_header" },
    { group = "MarkdownTableCell", key = "table_cell" },
    { group = "MarkdownTableCodeInline", key = "table_code_inline" },
    { group = "MarkdownHorizontalRule", key = "horizontal_rule" },
    { group = "MarkdownNormal", key = "normal" },
}

function M.setup()
    local highlights = config.get().highlights

    for _, mapping in ipairs(HIGHLIGHT_MAP) do
        local highlight_options = highlights[mapping.key]

        if highlight_options then
            vim.api.nvim_set_hl(0, mapping.group, highlight_options)
        end
    end
end

return M
