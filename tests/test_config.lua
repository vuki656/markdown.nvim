local expect = MiniTest.expect
local config = require("markdown.config")

local T = MiniTest.new_set()

T["setup"] = MiniTest.new_set()

T["setup"]["uses defaults when no options provided"] = function()
    config.setup()
    local options = config.get()

    expect.equality(options.auto_open, true)
    expect.equality(options.debounce_ms, 150)
    expect.equality(options.padding, 4)
    expect.equality(#options.ignore_patterns, 0)
end

T["setup"]["merges user options with defaults"] = function()
    config.setup({
        auto_open = false,
        debounce_ms = 300,
    })
    local options = config.get()

    expect.equality(options.auto_open, false)
    expect.equality(options.debounce_ms, 300)
    expect.equality(options.padding, 4)
end

T["setup"]["deep merges highlight overrides"] = function()
    config.setup({
        highlights = {
            heading_1 = { fg = "#FF0000", bold = true },
        },
    })
    local options = config.get()

    expect.equality(options.highlights.heading_1.fg, "#FF0000")
    expect.equality(options.highlights.heading_2.fg, "#61afef")
end

T["setup"]["merges ignore patterns"] = function()
    config.setup({
        ignore_patterns = { "CLAUDE.md", "CHANGELOG.md" },
    })
    local options = config.get()

    expect.equality(#options.ignore_patterns, 2)
    expect.equality(options.ignore_patterns[1], "CLAUDE.md")
    expect.equality(options.ignore_patterns[2], "CHANGELOG.md")
end

return T
