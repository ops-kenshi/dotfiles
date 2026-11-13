-- nvim-tree decorator that dims gitignored files/folders (icon and name).
-- Must come after the folder-color decorator so the dim wins on ignored folders.

local function define_highlight()
    vim.api.nvim_set_hl(0, "NvimTreeIgnoredDim", { link = "Comment" })
end
define_highlight()
vim.api.nvim_create_autocmd("ColorScheme", { callback = define_highlight })

---@class (exact) IgnoredDimDecorator: nvim_tree.api.Decorator
local IgnoredDimDecorator = require("nvim-tree.api").Decorator:extend()

function IgnoredDimDecorator:new()
    self.enabled = true
    self.highlight_range = "all"
    self.icon_placement = "before" -- required field; no icons() method, so nothing is added
end

---@param node nvim_tree.api.Node
---@return string?
function IgnoredDimDecorator:highlight_group(node)
    if node.git_status and node.git_status.file == "!!" then
        return "NvimTreeIgnoredDim"
    end
end

return IgnoredDimDecorator
