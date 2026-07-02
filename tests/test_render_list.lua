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

T["list"]["renders wrapped item text on separate lines without duplication"] = function()
    local result = render_list("- First line of item\n  continuation line of item")

    expect.equality(#result.lines, 2)
    expect.equality(result.lines[1]:find("First line of item", 1, true) ~= nil, true)
    expect.equality(result.lines[2]:find("continuation line of item", 1, true) ~= nil, true)
    expect.equality(result.lines[1]:find("continuation", 1, true), nil)
    expect.equality(result.lines[2]:find("\u{2022}", 1, true), nil)
end

T["list"]["renders code span wrapped across item lines"] = function()
    local result = render_list('- domain `[["calendar_id", "in",\n  [ids]]]` trailing')

    expect.equality(result.lines[1]:find("`", 1, true), nil)
    expect.equality(result.lines[2]:find("`", 1, true), nil)
    expect.equality(result.lines[1]:find('[["calendar_id", "in",', 1, true) ~= nil, true)
    expect.equality(result.lines[2]:find("[ids]]]", 1, true) ~= nil, true)

    local code_highlights = helpers.filter_highlights(result.highlights, "MarkdownCodeInline")
    expect.equality(#code_highlights, 2)
end

T["list"]["preserves blank line between spaced items"] = function()
    local result = render_list("- first item\n\n- second item")

    expect.equality(#result.lines, 3)
    expect.equality(result.lines[2], "")
    expect.equality(result.lines[3]:find("second item", 1, true) ~= nil, true)
end

T["list"]["renders fenced code block inside list item"] = function()
    local markdown_text = table.concat({
        "1. Save the shape:",
        "",
        "   ```json",
        '   {"key": "value"}',
        "   ```",
        "",
        "   Then run it.",
    }, "\n")

    local result = render_list(markdown_text)
    local joined = table.concat(result.lines, "\n")

    expect.equality(joined:find('{"key": "value"}', 1, true) ~= nil, true)
    expect.equality(joined:find("```", 1, true), nil)
    expect.equality(result.lines[#result.lines]:find("Then run it.", 1, true) ~= nil, true)

    local code_highlights = helpers.filter_highlights(result.highlights, "MarkdownCodeBlock")
    expect.equality(#code_highlights, 1)
end

T["list"]["renders second paragraph of an item under the bullet"] = function()
    local result = render_list("- first paragraph\n\n  second paragraph")

    expect.equality(#result.lines, 3)
    expect.equality(result.lines[2], "")
    expect.equality(result.lines[3]:find("second paragraph", 1, true) ~= nil, true)
    expect.equality(result.lines[3]:find("\u{2022}", 1, true), nil)

    local bullet_highlights = helpers.filter_highlights(result.highlights, "MarkdownBulletL1")
    expect.equality(#bullet_highlights, 1)
end

T["task list"] = MiniTest.new_set()

T["task list"]["renders unchecked task with checkbox glyph"] = function()
    local result = render_list("- [ ] do something")

    expect.equality(result.lines[1]:find("\u{2610}") ~= nil, true)
    expect.equality(result.lines[1]:find("do something") ~= nil, true)
    expect.equality(result.lines[1]:find("%[") == nil, true)

    local unchecked_highlights = helpers.filter_highlights(result.highlights, "MarkdownCheckboxUnchecked")
    expect.equality(#unchecked_highlights, 1)
end

T["task list"]["renders checked task with checkbox glyph"] = function()
    local result = render_list("- [x] done thing")

    expect.equality(result.lines[1]:find("\u{2611}") ~= nil, true)
    expect.equality(result.lines[1]:find("done thing") ~= nil, true)
    expect.equality(result.lines[1]:find("%[") == nil, true)

    local checked_highlights = helpers.filter_highlights(result.highlights, "MarkdownCheckboxChecked")
    expect.equality(#checked_highlights, 1)
end

T["task list"]["treats uppercase X as checked"] = function()
    local result = render_list("- [X] also done")

    expect.equality(result.lines[1]:find("\u{2611}") ~= nil, true)

    local checked_highlights = helpers.filter_highlights(result.highlights, "MarkdownCheckboxChecked")
    expect.equality(#checked_highlights, 1)
end

T["task list"]["applies done-text highlight only to checked tasks"] = function()
    local checked = render_list("- [x] done thing")
    local unchecked = render_list("- [ ] do something")

    local checked_done = helpers.filter_highlights(checked.highlights, "MarkdownCheckboxDoneText")
    local unchecked_done = helpers.filter_highlights(unchecked.highlights, "MarkdownCheckboxDoneText")

    expect.equality(#checked_done, 1)
    expect.equality(#unchecked_done, 0)
end

T["task list"]["mixes task items with regular bullets"] = function()
    local result = render_list("- [ ] task one\n- regular item\n- [x] task two")

    expect.equality(result.lines[1]:find("\u{2610}") ~= nil, true)
    expect.equality(result.lines[2]:find("\u{2022}") ~= nil, true)
    expect.equality(result.lines[3]:find("\u{2611}") ~= nil, true)

    local bullet_highlights = helpers.filter_highlights(result.highlights, "MarkdownBulletL1")
    expect.equality(#bullet_highlights, 1)
end

T["task list"]["replaces ordered marker with checkbox for ordered task items"] = function()
    local result = render_list("1. [x] done thing")

    expect.equality(result.lines[1]:find("\u{2611}") ~= nil, true)
    expect.equality(result.lines[1]:find("1%.") == nil, true)
end

return T
