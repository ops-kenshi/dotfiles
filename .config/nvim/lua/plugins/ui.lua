return {
    -- devicons
    { "nvim-tree/nvim-web-devicons", lazy = true },

    -- status line
    { "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        opts = function()
            -- directory of the current file relative to its git root (cwd outside a repo),
            -- with a trailing slash; "" for files at the root. Cached per buffer.
            local function rel_dir()
                local name = vim.api.nvim_buf_get_name(0)
                if name == "" or vim.bo.buftype ~= "" then return "" end
                if vim.b.rel_dir_for ~= name then
                    local root = vim.fs.root(0, ".git")
                    local rel = root and vim.fs.relpath(root, name) or vim.fn.fnamemodify(name, ":~:.")
                    local dir = vim.fs.dirname(rel)
                    vim.b.rel_dir = (dir == "." or dir == nil) and "" or dir .. "/"
                    vim.b.rel_dir_for = name
                end
                return vim.b.rel_dir
            end

            local function file_name()
                local name = vim.fn.expand("%:t")
                if name == "" then name = "[No Name]" end
                if vim.bo.modified then name = name .. " [+]" end
                if vim.bo.readonly or not vim.bo.modifiable then name = name .. " [-]" end
                -- dir component hides itself when empty; keep the usual left gap then
                return (rel_dir() == "" and " " or "") .. name
            end

            return {
                options = {
                    icons_enabled = true,
                    theme = 'onedark',
                    component_separators = '|',
                    section_separators = '',
                },
                sections = {
                    -- path (dimmed like comments) glued to the filename (bold)
                    lualine_c = {
                        { rel_dir, separator = "", padding = { left = 1, right = 0 },
                            color = function()
                                local fg = vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg
                                return fg and { fg = string.format("#%06x", fg) } or nil
                            end },
                        { file_name, color = { gui = "bold" }, padding = { left = 0, right = 1 } },
                    },
                },
            }
        end,
    },

    -- bufferline
    { "akinsho/bufferline.nvim",
        version = "v4.*",
        dependencies = "nvim-tree/nvim-web-devicons",
        event = "VeryLazy",
        keys = {
            { "<leader>bp", "<cmd>BufferLineTogglePin<CR>",             desc = "Toggle Buffer Pin" },
            { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<CR>",  desc = "Close Unpinned Buffers" },
        },
        opts = {
            options = {
                diagnostics = "nvim_lsp",
                numbers = "buffer_id",
                always_show_bufferline = false
            }
        }
    },

    -- file tree sidebar
    { "nvim-tree/nvim-tree.lua",
        dependencies = "nvim-tree/nvim-web-devicons",
        keys = {
            -- opens with the current file revealed (parents expanded, cursor on it)
            { "<leader>e", "<cmd>NvimTreeFindFileToggle<CR>", desc = "Toggle File Tree (reveal current file)" },
        },
        config = function(_, opts)
            -- folder icons colored by name (src, tests, docs, ...), see core/nvim_tree_folders.lua
            opts.renderer = {
                decorators = {
                    "Git", "Open", "Hidden", "Modified", "Bookmark", "Diagnostics", "Copied", "Cut",
                    require("core.nvim_tree_folders"),
                    require("core.nvim_tree_ignored"), -- dims gitignored entries, see core/nvim_tree_ignored.lua
                },
            }
            require("nvim-tree").setup(opts)
        end,
        opts = {
            view = { side = "right" },
            -- show everything :Ex shows; gitignored entries are dimmed instead of hidden
            filters = { git_ignored = false, dotfiles = false },
            actions = { open_file = { quit_on_open = true } },
            on_attach = function(bufnr)
                local api = require("nvim-tree.api")
                api.map.on_attach.default(bufnr)
                vim.keymap.set("n", "<Esc>", api.tree.close, { buffer = bufnr, desc = "Close tree" })
                -- unmapped Ctrl+[ falls back to the Esc mapping, so pin it to nothing
                vim.keymap.set("n", "<C-[>", "<Nop>", { buffer = bufnr })
                -- VS Code explorer style: Space opens/toggles, Enter renames (use `o` to open).
                -- nowait: fire Space at once instead of waiting for <leader> mappings.
                vim.keymap.set("n", "<Space>", api.node.open.edit, { buffer = bufnr, nowait = true, desc = "Toggle folder / open file" })
                vim.keymap.set("n", "<CR>", api.fs.rename, { buffer = bufnr, desc = "Rename" })

                -- h/l like VS Code's Left/Right arrows
                vim.keymap.set("n", "h", function()
                    local node = api.tree.get_node_under_cursor()
                    if node and node.type == "directory" and node.open then
                        api.node.open.edit() -- collapse
                    else
                        api.node.navigate.parent()
                    end
                end, { buffer = bufnr, desc = "Collapse folder / go to parent" })
                vim.keymap.set("n", "l", function()
                    local node = api.tree.get_node_under_cursor()
                    if node and node.type == "directory" and node.open then
                        vim.cmd("normal! j") -- already open: step into its first child
                    else
                        api.node.open.edit()
                    end
                end, { buffer = bufnr, desc = "Expand folder / open file" })

                -- J/K jump to the next/prev sibling folder, skipping files (wraps around)
                local function sibling_dir(step)
                    return function()
                        local start = api.tree.get_node_under_cursor()
                        if not start then return end
                        for _ = 1, vim.api.nvim_buf_line_count(bufnr) do
                            step()
                            local n = api.tree.get_node_under_cursor()
                            if not n or n.type == "directory" or n.absolute_path == start.absolute_path then return end
                        end
                    end
                end
                vim.keymap.set("n", "J", sibling_dir(api.node.navigate.sibling.next), { buffer = bufnr, desc = "Next sibling folder" })
                vim.keymap.set("n", "K", sibling_dir(api.node.navigate.sibling.prev), { buffer = bufnr, desc = "Prev sibling folder" })

                -- "/" fuzzy-finds everything the tree shows right now, plus every
                -- file/dir under the folder at the cursor (even collapsed ones).
                vim.keymap.set("n", "/", function()
                    local root = api.tree.get_nodes()
                    local node = api.tree.get_node_under_cursor()
                    local dir = root.absolute_path
                    if node and node.name ~= ".." then
                        dir = node.type == "directory" and node.absolute_path or vim.fs.dirname(node.absolute_path)
                    end

                    local paths, seen = {}, {}
                    local function add(path)
                        path = path:gsub("/$", "")
                        if not seen[path] then
                            seen[path] = true
                            table.insert(paths, path)
                        end
                    end
                    local function add_visible(n)
                        for _, child in ipairs(n.nodes or {}) do
                            add(child.absolute_path)
                            if child.open then add_visible(child) end
                        end
                    end
                    add_visible(root)
                    -- ponytail: synchronous fd, switch to an async finder if huge folders stall
                    for _, p in ipairs(vim.fn.systemlist({ "fd", "--hidden", "--exclude", ".git", "--absolute-path", ".", dir })) do
                        add(p)
                    end

                    local actions = require("telescope.actions")
                    require("telescope.pickers").new(require("telescope.themes").get_ivy(), {
                        prompt_title = "Tree: " .. vim.fn.fnamemodify(dir, ":~"),
                        finder = require("telescope.finders").new_table({
                            results = paths,
                            entry_maker = function(path)
                                local rel = path:sub(#root.absolute_path + 2)
                                if vim.fn.isdirectory(path) == 1 then rel = rel .. "/" end
                                return { value = path, display = rel, ordinal = rel, path = path }
                            end,
                        }),
                        sorter = require("telescope.config").values.generic_sorter({}),
                        previewer = require("telescope.config").values.file_previewer({}),
                        attach_mappings = function(prompt_bufnr)
                            actions.select_default:replace(function()
                                local path = require("telescope.actions.state").get_selected_entry().value
                                actions.close(prompt_bufnr)
                                api.tree.find_file({ buf = path, focus = true })
                                if vim.fn.isdirectory(path) == 0 then api.node.open.edit() end
                            end)
                            return true
                        end,
                    }):find()
                end, { buffer = bufnr, desc = "Fuzzy find in tree" })
            end,
        },
    },

    -- show indent guides on blank lines
    { "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        ---@module "ibl"
        ---@type ibl.config
        opts = {}
    },
}
