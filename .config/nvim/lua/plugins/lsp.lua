return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
        -- Which TypeScript server to use: 'ts_ls' or 'vtsls'. Try 'vtsls' if Vue feels slow.
        local ts_server = 'ts_ls'
        local unused_ts_server = ts_server == 'ts_ls' and 'vtsls' or 'ts_ls'

        require('mason').setup()
        require('mason-lspconfig').setup {
            ensure_installed = { "basedpyright", "ruff", "lua_ls", ts_server, "tailwindcss", "vue_ls" },
            -- Don't auto-start the TypeScript server we're not using (it would attach twice).
            automatic_enable = { exclude = { unused_ts_server } },
        }

        -- mason-lspconfig v2 auto-enables installed servers. Do NOT call
        -- lspconfig.<server>.setup() as well -- that attaches every client twice.
        vim.lsp.config('*', {
            capabilities = require('cmp_nvim_lsp').default_capabilities(),
        })
        -- basedpyright defaults to "recommended", which flags every untyped
        -- third-party symbol; "off" matches Pylance's default (Django's runtime magic trips the rest).
        vim.lsp.config('basedpyright', {
            settings = {
                basedpyright = { analysis = { typeCheckingMode = 'off' } },
            },
        })
        -- TypeScript 7 (native) ships no tsserver.js for ts_ls; it has its own server,
        -- `tsc --lsp`. Pick per project by the installed TypeScript's major version.
        -- Returns the project root when its installed TypeScript is 7+.
        local function ts7_root(bufnr)
            local root = vim.fs.root(bufnr, 'node_modules')
            local ok, pkg = pcall(function()
                return vim.json.decode(table.concat(vim.fn.readfile(root .. '/node_modules/typescript/package.json'), '\n'))
            end)
            if ok and tonumber(pkg.version:match('^%d+')) >= 7 then return root end
        end
        local ts_server_root = vim.lsp.config[ts_server].root_dir
        -- vue_ls only handles a .vue file's template/style; its <script> types come from
        -- the TypeScript server running the @vue/typescript-plugin bundled with Mason's vue-language-server.
        local vue_plugin = {
            name = '@vue/typescript-plugin',
            location = vim.fn.stdpath('data') .. '/mason/packages/vue-language-server/node_modules/@vue/language-server',
            languages = { 'vue' },
            configNamespace = 'typescript',
        }
        local ts_server_config = {
            -- vue_ls already provides semantic tokens for .vue files; skip the duplicate from TS.
            on_attach = function(client, bufnr)
                if vim.bo[bufnr].filetype == 'vue' and client.server_capabilities.semanticTokensProvider then
                    client.server_capabilities.semanticTokensProvider.full = false
                end
            end,
            root_dir = function(bufnr, on_dir) if not ts7_root(bufnr) then ts_server_root(bufnr, on_dir) end end,
            filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue' },
        }
        if ts_server == 'ts_ls' then
            ts_server_config.init_options = { plugins = { vue_plugin } }
        else
            ts_server_config.settings = { vtsls = { tsserver = { globalPlugins = { vue_plugin } } } }
        end
        vim.lsp.config(ts_server, ts_server_config)

        vim.lsp.config('tsc', {
            filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
            root_dir = function(bufnr, on_dir)
                local root = ts7_root(bufnr)
                if root then on_dir(root) end
            end,
            cmd = function(dispatchers, config)
                return vim.lsp.rpc.start({ config.root_dir .. '/node_modules/.bin/tsc', '--lsp', '--stdio' }, dispatchers)
            end,
        })
        vim.lsp.enable('tsc')

        vim.lsp.config('lua_ls', {
            settings = {
                Lua = {
                    runtime = { version = 'LuaJIT' },
                    diagnostics = { globals = { 'vim' } },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false,
                    },
                },
            },
        })
    end
}
