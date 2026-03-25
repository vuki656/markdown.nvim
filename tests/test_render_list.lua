local expect = MiniTest.expect
local helpers = require("tests.helpers")
local list = require("markdown.render.list")
local treesitter = require("markdown.treesitter")

local T = MiniTest.new_set()

local function render_list(markdown_text)
    local buffer_number = helpers.create_markdown_buffer(markdown_text)
    local root = treesitter.parse_buffer(buffer_number)

    local list_node = nil

    for child in root:iter_children() do
        if child:type() == "list" then
            list_node = child
            break
        end

        for grandchild in child:iter_children() do
            if grandchild:type() == "list" then
                list_node = grandchild
                break
            end
        end

        if list_node then
            break
        end
    end

    local result = list.render(list_node, buffer_number, 0)
    helpers.delete_buffer(buffer_number)

    return result
end

T["list"] = MiniTest.new_set()

T["list"]["renders unordered list with bullet characters"] = function()
    local result = render_list("- First item\n- Second item")

    expect.equality(vim.fn.strwidth(result.lines[1]) > 0, true)
    expect.equality(result.lines[1]:find("\u{2022}") ~= nil, true)
    expect.equality(result.lines[2]:find("\u{2022}") ~= nil, true)
end

T["list"]["renders ordered list with numbers"] = function()
    local result = render_list("1. First item\n2. Second item")

    expect.equality(result.lines[1]:find("1%.") ~= nil, true)
    expect.equality(result.lines[2]:find("2%.") ~= nil, true)
end

T["list"]["applies bullet highlight to unordered items"] = function()
    local result = render_list("- First item\n- Second item")
    local bullet_highlights = helpers.filter_highlights(result.highlights, "MarkdownBulletL1")

    expect.equality(#bullet_highlights, 2)
end

T["list"]["renders bold text within list items"] = function()
    local result = render_list("- **Bold** text")

    expect.equality(result.lines[1]:find("Bold") ~= nil, true)
    expect.equality(result.lines[1]:find("%*%*") == nil, true)

    local bold_highlights = helpers.filter_highlights(result.highlights, "MarkdownBold")
    expect.equality(#bold_highlights, 1)
end

return T
