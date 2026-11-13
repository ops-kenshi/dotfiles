-- Prettier on save for web files. Conform prefers the project's node_modules/.bin/prettier,
-- so each project's own version and .prettierrc are used. Only the filetypes listed here
-- format on save (no LSP fallback), so Python etc. keep their current behaviour.
local prettier = { 'prettier' }
return {
    'stevearc/conform.nvim',
    event = 'BufWritePre',
    cmd = 'ConformInfo',
    opts = {
        formatters_by_ft = {
            javascript = prettier, javascriptreact = prettier,
            typescript = prettier, typescriptreact = prettier,
            vue = prettier, css = prettier, scss = prettier, html = prettier,
            json = prettier, jsonc = prettier, markdown = prettier, yaml = prettier,
        },
        format_on_save = { timeout_ms = 2000, lsp_format = 'never' },
    },
}
