-- nvim-tree decorator that colors folder icons by folder name, Material Icon Theme style.
-- Glyphs stay nvim-tree's own (open/closed/empty); only the icon highlight changes.

local colors = {
    Source = "#8BC34A",
    Ui     = "#FFCA28",
    Test   = "#26A69A",
    Docs   = "#42A5F5",
    Config = "#90A4AE",
    Script = "#FF7043",
    Asset  = "#FFA726",
    Logic  = "#AB47BC",
    Style  = "#EC407A",
    Meta   = "#5C6BC0",
    Build  = "#757575",
}

local groups = {
    Source = { "src", "source", "lib", "app", "core", "pkg", "internal", "cmd", "lua" },
    Ui     = { "components", "views", "pages", "layouts", "layout", "screens", "templates", "ui", "widgets" },
    Test   = { "test", "tests", "__tests__", "spec", "specs", "e2e", "fixtures", "__mocks__", "mocks" },
    Docs   = { "docs", "doc", "documentation", "examples", "example" },
    Config = { "config", "configs", "conf", ".config", "settings", "env", "environments" },
    Script = { "scripts", "script", "bin", "tools", "tasks", "migrations" },
    Asset  = { "assets", "images", "img", "icons", "fonts", "media", "public", "static", "resources" },
    Logic  = { "utils", "util", "helpers", "hooks", "store", "stores", "services", "api", "models", "plugins", "composables" },
    Style  = { "styles", "style", "css", "scss", "sass", "themes", "theme" },
    Meta   = { ".github", ".vscode", ".claude", ".husky", ".git", "ci", ".circleci" },
    Build  = { "node_modules", "vendor", "dist", "build", "out", "target", "coverage", ".cache", "__pycache__", ".venv", "venv" },
}

local hl_by_name = {}
for group, names in pairs(groups) do
    for _, name in ipairs(names) do
        hl_by_name[name] = "NvimTreeFolder" .. group
    end
end

local function define_highlights()
    for group, fg in pairs(colors) do
        vim.api.nvim_set_hl(0, "NvimTreeFolder" .. group, { fg = fg })
    end
end
define_highlights()
-- colorschemes clear highlights on load, so redefine after each one
vim.api.nvim_create_autocmd("ColorScheme", { callback = define_highlights })

---@class (exact) FolderColorDecorator: nvim_tree.api.Decorator
local FolderColorDecorator = require("nvim-tree.api").Decorator:extend()

function FolderColorDecorator:new()
    self.enabled = true
    self.highlight_range = "icon"
    self.icon_placement = "before" -- required field; no icons() method, so nothing is added
end

---@param node nvim_tree.api.Node
---@return string?
function FolderColorDecorator:highlight_group(node)
    if node.type ~= "directory" then return nil end
    return hl_by_name[node.name:lower()]
end

return FolderColorDecorator
