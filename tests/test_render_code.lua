local expect = MiniTest.expect
local helpers = require("tests.helpers")
local code = require("markdown.render.code")
local treesitter = require("markdown.treesitter")

local T = MiniTest.new_set()

local function render_code_block(markdown_text)
    local buffer_number = helpers.create_markdown_buffer(markdown_text)
    local root = treesitter.parse_buffer(buffer_number)

    local code_node = nil

    for child in root:iter_children() do
        if child:type() == "fenced_code_block" then
            code_node = child
            break
        end

        for grandchild in child:iter_children() do
            if grandchild:type() == "fenced_code_block" then
                code_node = grandchild
                break
            end
        end

        if code_node then
            break
        end
    end

    local result = code.render_block(code_node, buffer_number)
    helpers.delete_buffer(buffer_number)

    return result
end

T["code_block"] = MiniTest.new_set()

T["code_block"]["renders code block content only"] = function()
    local result = render_code_block("```\nhello world\n```")

    expect.equality(#result.lines, 1)
    expect.equality(result.lines[1], "  hello world")
end

T["code_block"]["renders multi-line code block"] = function()
    local result = render_code_block("```lua\nlocal x = 1\nlocal y = 2\n```")

    expect.equality(#result.lines, 2)
    expect.equality(result.lines[1], "  local x = 1")
    expect.equality(result.lines[2], "  local y = 2")
end

T["code_block"]["applies code block highlight to each line"] = function()
    local result = render_code_block("```\nline one\nline two\n```")
    local code_highlights = helpers.filter_highlights(result.highlights, "MarkdownCodeBlock")

    expect.equality(#code_highlights, 2)
    expect.equality(code_highlights[1].column_end, -1)
    expect.equality(code_highlights[2].column_end, -1)
end

T["code_block"]["handles empty code block"] = function()
    local result = render_code_block("```\n```")

    expect.equality(#result.lines, 0)
    expect.equality(#result.highlights, 0)
end

return T
