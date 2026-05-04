local expect = MiniTest.expect
local helpers = require("tests.helpers")
local heading = require("markdown.render.heading")
local treesitter = require("markdown.treesitter")

local T = MiniTest.new_set()

local function render_heading(markdown_text)
    local buffer_number = helpers.create_markdown_buffer(markdown_text)
    local root = treesitter.parse_buffer(buffer_number)
    local section = root:named_child(0)
    local heading_node = nil

    for child in section:iter_children() do
        if child:type() == "atx_heading" then
            heading_node = child
            break
        end
    end

    local result = heading.render(heading_node, buffer_number)
    helpers.delete_buffer(buffer_number)

    return result
end

T["heading"] = MiniTest.new_set()

T["heading"]["renders h1 with surrounding blank lines"] = function()
    local result = render_heading("# Hello World")

    expect.equality(#result.lines, 3)
    expect.equality(result.lines[1], "")
    expect.equality(result.lines[2], "Hello World")
    expect.equality(result.lines[3], "")

    local heading_highlights = helpers.filter_highlights(result.highlights, "MarkdownH1")
    expect.equality(#heading_highlights, 1)
    expect.equality(heading_highlights[1].line, 1)
end

T["heading"]["renders h2 with surrounding blank lines"] = function()
    local result = render_heading("## Section Title")

    expect.equality(#result.lines, 3)
    expect.equality(result.lines[2], "Section Title")

    local heading_highlights = helpers.filter_highlights(result.highlights, "MarkdownH2")
    expect.equality(#heading_highlights, 1)
    expect.equality(heading_highlights[1].line, 1)
end

T["heading"]["renders h3 with surrounding blank lines"] = function()
    local result = render_heading("### Sub Section")

    expect.equality(#result.lines, 3)
    expect.equality(result.lines[2], "Sub Section")

    local heading_highlights = helpers.filter_highlights(result.highlights, "MarkdownH3")
    expect.equality(#heading_highlights, 1)
    expect.equality(heading_highlights[1].line, 1)
end

T["heading"]["renders h4 through h6 with h3 highlight"] = function()
    local result = render_heading("#### Deep Heading")

    expect.equality(result.lines[2], "Deep Heading")

    local heading_highlights = helpers.filter_highlights(result.highlights, "MarkdownH3")
    expect.equality(#heading_highlights, 1)
end

T["heading"]["renders heading with bold text"] = function()
    local result = render_heading("## **Bold** Title")

    expect.equality(result.lines[2], "Bold Title")

    local bold_highlights = helpers.filter_highlights(result.highlights, "MarkdownBold")
    expect.equality(#bold_highlights, 1)
    expect.equality(bold_highlights[1].column_start, 0)
    expect.equality(bold_highlights[1].column_end, 4)
end

return T
