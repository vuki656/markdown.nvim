local expect = MiniTest.expect
local helpers = require("tests.helpers")
local markdown_table = require("markdown.render.table")
local treesitter = require("markdown.treesitter")

local T = MiniTest.new_set()

local function render_table(markdown_text)
    local buffer_number = helpers.create_markdown_buffer(markdown_text)
    local root = treesitter.parse_buffer(buffer_number)

    local table_node = nil

    for child in root:iter_children() do
        if child:type() == "pipe_table" then
            table_node = child
            break
        end

        for grandchild in child:iter_children() do
            if grandchild:type() == "pipe_table" then
                table_node = grandchild
                break
            end
        end

        if table_node then
            break
        end
    end

    local result = markdown_table.render(table_node, buffer_number)
    helpers.delete_buffer(buffer_number)

    return result
end

T["table"] = MiniTest.new_set()

T["table"]["renders table with unicode box-drawing borders"] = function()
    local result = render_table("| Header | Value |\n| ------ | ----- |\n| foo | bar |")

    local has_top_border = false
    local has_bottom_border = false

    for _, line in ipairs(result.lines) do
        if line:find("\u{250C}") then
            has_top_border = true
        end
        if line:find("\u{2514}") then
            has_bottom_border = true
        end
    end

    expect.equality(has_top_border, true)
    expect.equality(has_bottom_border, true)
end

T["table"]["renders header with bold highlight"] = function()
    local result = render_table("| Name | Age |\n| ---- | --- |\n| Alice | 30 |")
    local header_highlights = helpers.filter_highlights(result.highlights, "MarkdownTableHeader")

    expect.equality(#header_highlights > 0, true)
end

T["table"]["renders border characters with border highlight"] = function()
    local result = render_table("| A | B |\n| - | - |\n| 1 | 2 |")
    local border_highlights = helpers.filter_highlights(result.highlights, "MarkdownTableBorder")

    expect.equality(#border_highlights > 0, true)
end

T["table"]["renders content only without padding"] = function()
    local result = render_table("| H |\n| - |\n| V |")

    expect.equality(result.lines[1]:find("\u{250C}") ~= nil, true)
    expect.equality(result.lines[#result.lines]:find("\u{2514}") ~= nil, true)
end

return T
