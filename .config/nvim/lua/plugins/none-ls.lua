-- linting + formatting
return {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local null_ls = require("null-ls")

        -- diagnostics.ruff is no longer shipped with none-ls; the ruff LSP
        -- (see plugins/lsp.lua) already provides those diagnostics.
        null_ls.setup({
            sources = {
                null_ls.builtins.formatting.black,
            }
        })
    end
}
