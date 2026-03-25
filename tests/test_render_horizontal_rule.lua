local expect = MiniTest.expect
local helpers = require("tests.helpers")
local horizontal_rule = require("markdown.render.horizontal_rule")

local T = MiniTest.new_set()

T["horizontal_rule"] = MiniTest.new_set()

T["horizontal_rule"]["renders with blank lines around it"] = function()
    local result = horizontal_rule.render()

    expect.equality(result.lines[1], "")
    expect.equality(result.lines[3], "")
end

T["horizontal_rule"]["renders with unicode line characters"] = function()
    local result = horizontal_rule.render()

    expect.equality(result.lines[2]:find("\u{2500}") ~= nil, true)
end

T["horizontal_rule"]["applies horizontal rule highlight"] = function()
    local result = horizontal_rule.render()
    local rule_highlights = helpers.filter_highlights(result.highlights, "MarkdownHorizontalRule")

    expect.equality(#rule_highlights, 1)
    expect.equality(rule_highlights[1].line, 1)
end

return T
