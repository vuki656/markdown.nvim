local expect = MiniTest.expect
local helpers = require("tests.helpers")
local blockquote = require("markdown.render.blockquote")
local treesitter = require("markdown.treesitter")

local T = MiniTest.new_set()

local function render_blockquote(markdown_text)
    local buffer_number = helpers.create_markdown_buffer(markdown_text)
    local root = treesitter.parse_buffer(buffer_number)

    local quote_node = nil

    for child in root:iter_children() do
        if child:type() == "block_quote" then
            quote_node = child
            break
        end

        for grandchild in child:iter_children() do
            if grandchild:type() == "block_quote" then
                quote_node = grandchild
                break
            end
        end

        if quote_node then
            break
        end
    end

    local result = blockquote.render(quote_node, buffer_number)
    helpers.delete_buffer(buffer_number)

    return result
end

T["blockquote"] = MiniTest.new_set()

T["blockquote"]["renders with left bar character"] = function()
    local result = render_blockquote("> This is a quote")

    expect.equality(result.lines[1]:find("\u{2595}") ~= nil, true)
    expect.equality(result.lines[1]:find("This is a quote") ~= nil, true)
end

T["blockquote"]["strips leading > marker"] = function()
    local result = render_blockquote("> Hello world")

    expect.equality(result.lines[1]:find("^>") == nil, true)
end

T["blockquote"]["applies bar and text highlights"] = function()
    local result = render_blockquote("> Some text")
    local bar_highlights = helpers.filter_highlights(result.highlights, "MarkdownBlockquoteBar")
    local text_highlights = helpers.filter_highlights(result.highlights, "MarkdownBlockquoteText")

    expect.equality(#bar_highlights, 1)
    expect.equality(#text_highlights, 1)
end

T["blockquote"]["renders multi-line blockquote"] = function()
    local result = render_blockquote("> Line one\n> Line two")

    expect.equality(#result.lines, 2)
    expect.equality(result.lines[1]:find("Line one") ~= nil, true)
    expect.equality(result.lines[2]:find("Line two") ~= nil, true)
end

return T
