return {
    -- multiple cursors
    -- Not lazy-loaded: VM registers all of its mappings from plugin/, so an
    -- event trigger leaves you with no keybindings until something else fires.
    { "mg979/vim-visual-multi", lazy = false,
        init = function()
            -- <C-n> is already taken by the Telescope file browser in core.keymaps
            vim.g.VM_maps = {
                ["Find Under"] = "<M-n>",
                ["Find Subword Under"] = "<M-n>",
            }
        end,
        config = function()
            -- VM's own entry points are \\c / <C-Down>, both awkward here:
            -- \\c is three keys against timeoutlen=300, and <C-Down> is
            -- swallowed by macOS Mission Control. This one is neither.
            vim.keymap.set("x", "<leader>m", "<Plug>(VM-Visual-Cursors)",
                { remap = true, desc = "Multi-cursor on selection" })

            -- VSCode-style I/A: in charwise/linewise visual, drop a live cursor
            -- on every selected line (first non-blank for I, end of line for A).
            -- Blockwise <C-v> keeps Vim's native behaviour, where I/A mean the
            -- block's own edges rather than the text's.
            -- When 'hlsearch' is off (see init.lua), VM restores it on start
            -- by queueing <Plug>(VM-Hls) into the typeahead. Entering insert
            -- mode before those keys drain types them into the buffer as
            -- literal text, so the insert step is queued separately below.
            local function visual_insert(after)
                local mode = vim.fn.mode()
                if mode ~= "v" and mode ~= "V" then
                    return after and "A" or "I"
                end
                vim.schedule(function()
                    vim.api.nvim_feedkeys(after and "$a" or "I", "m", false)
                end)
                return "<Plug>(VM-Visual-Cursors)"
            end

            vim.keymap.set("x", "I", function() return visual_insert(false) end,
                { expr = true, remap = true, desc = "Multi-cursor insert at line start" })
            vim.keymap.set("x", "A", function() return visual_insert(true) end,
                { expr = true, remap = true, desc = "Multi-cursor append at line end" })
        end
    },

    { "echasnovski/mini.pairs", event = "VeryLazy",
        config = function(_, opts)
            require('mini.pairs').setup(opts)
        end
    },

    -- auto-close and auto-rename JSX/HTML tags (uses treesitter)
    { "windwp/nvim-ts-autotag", event = { "BufReadPre", "BufNewFile" }, opts = {} },

    { "echasnovski/mini.surround",
        config = function(_, opts)
            require('mini.surround').setup(opts)
        end
    },
}
