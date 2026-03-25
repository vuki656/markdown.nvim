local expect = MiniTest.expect
local inline = require("markdown.render.inline")

local T = MiniTest.new_set()

T["inline"] = MiniTest.new_set()

T["inline"]["renders plain text without modification"] = function()
    local result = inline.render("Hello world")

    expect.equality(result.lines[1], "Hello world")
    expect.equality(#result.highlights, 0)
end

T["inline"]["renders bold text with highlight"] = function()
    local result = inline.render("Hello **bold** world")

    expect.equality(result.lines[1], "Hello bold world")

    local bold_highlights = {}
    for _, highlight in ipairs(result.highlights) do
        if highlight.group == "MarkdownBold" then
            table.insert(bold_highlights, highlight)
        end
    end

    expect.equality(#bold_highlights, 1)
    expect.equality(bold_highlights[1].column_start, 6)
    expect.equality(bold_highlights[1].column_end, 10)
end

T["inline"]["renders italic text with highlight"] = function()
    local result = inline.render("Hello *italic* world")

    expect.equality(result.lines[1], "Hello italic world")

    local italic_highlights = {}
    for _, highlight in ipairs(result.highlights) do
        if highlight.group == "MarkdownItalic" then
            table.insert(italic_highlights, highlight)
        end
    end

    expect.equality(#italic_highlights, 1)
end

T["inline"]["renders inline code with highlight"] = function()
    local result = inline.render("Use `vim.api` here")

    expect.equality(result.lines[1], "Use vim.api here")

    local code_highlights = {}
    for _, highlight in ipairs(result.highlights) do
        if highlight.group == "MarkdownCodeInline" then
            table.insert(code_highlights, highlight)
        end
    end

    expect.equality(#code_highlights, 1)
    expect.equality(code_highlights[1].column_start, 4)
    expect.equality(code_highlights[1].column_end, 11)
end

T["inline"]["renders links as text only"] = function()
    local result = inline.render("Visit [Claude Code](https://claude.ai) today")

    expect.equality(result.lines[1], "Visit Claude Code today")

    local link_highlights = {}
    for _, highlight in ipairs(result.highlights) do
        if highlight.group == "MarkdownLink" then
            table.insert(link_highlights, highlight)
        end
    end

    expect.equality(#link_highlights, 1)
end

T["inline"]["renders strikethrough text"] = function()
    local result = inline.render("Hello ~~removed~~ world")

    expect.equality(result.lines[1], "Hello removed world")

    local strike_highlights = {}
    for _, highlight in ipairs(result.highlights) do
        if highlight.group == "MarkdownStrikethrough" then
            table.insert(strike_highlights, highlight)
        end
    end

    expect.equality(#strike_highlights, 1)
end

T["inline"]["handles multi-line text"] = function()
    local result = inline.render("Line one\nLine two")

    expect.equality(#result.lines, 2)
    expect.equality(result.lines[1], "Line one")
    expect.equality(result.lines[2], "Line two")
end

return T
