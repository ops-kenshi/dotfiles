return {
    "nvim-telescope/telescope.nvim",
    event = 'VimEnter',
    dependencies = {
        'nvim-lua/plenary.nvim',
        {
            'nvim-telescope/telescope-fzf-native.nvim',
            build = 'make',
            cond = function()
                return vim.fn.executable 'make' == 1
            end
        },
        { 'nvim-telescope/telescope-ui-select.nvim' },
        { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
        -- 'space space' / Ctrl+P: like VSCode Ctrl+P. Files you've opened before (even
        -- gitignored ones like .env) come first, then everything rg finds.
        -- With `split_cmd` (e.g. 'belowright vsplit') the chosen file opens in a new split
        -- made by that command instead of the current window; cancelling leaves no split behind.
        local function find_files_recent(split_cmd)
            local cwd = vim.fn.getcwd() .. '/'
            local list, seen = {}, {}
            local function add(path)
                if path:sub(1, #cwd) == cwd then
                    path = path:sub(#cwd + 1)
                elseif path:sub(1, 1) == '/' or path == '' then
                    return -- outside this project
                end
                if not seen[path] then
                    seen[path] = true
                    table.insert(list, path)
                end
            end
            -- this session's buffers first: v:oldfiles only picks them up after a restart
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.bo[b].buflisted then add(vim.api.nvim_buf_get_name(b)) end
            end
            for _, f in ipairs(vim.v.oldfiles) do
                if vim.fn.filereadable(f) == 1 then add(f) end
            end
            -- ponytail: synchronous rg, switch to an async job if huge repos feel laggy
            for _, f in ipairs(vim.fn.systemlist({ 'rg', '--files', '--hidden', '--glob', '!.git' })) do
                add(f)
            end
            -- gitignored dotfiles too (.env, .env.local, ...), minus the usual junk dirs
            for _, f in ipairs(vim.fn.systemlist({
                'rg', '--files', '--hidden', '--no-ignore', '--glob', '.*',
                '--glob', '!.git', '--glob', '!node_modules', '--glob', '!.venv', '--glob', '!.DS_Store',
            })) do
                add(f)
            end

            local conf = require('telescope.config').values
            require('telescope.pickers').new(require('telescope.themes').get_ivy(), {
                prompt_title = 'Find Files',
                finder = require('telescope.finders').new_table({
                    results = list,
                    entry_maker = require('telescope.make_entry').gen_from_file({}),
                }),
                sorter = conf.file_sorter({}),
                previewer = conf.file_previewer({}),
                attach_mappings = function()
                    if type(split_cmd) ~= 'string' then return true end
                    local actions = require('telescope.actions')
                    actions.select_default:replace(function(prompt_bufnr)
                        local entry = require('telescope.actions.state').get_selected_entry()
                        actions.close(prompt_bufnr)
                        if entry then vim.cmd(split_cmd .. ' ' .. vim.fn.fnameescape(entry.path)) end
                    end)
                    return true
                end,
            }):find()
        end
        vim.keymap.set('n', '<leader><leader>', find_files_recent, { desc = 'Find files (recent first)' })
        vim.keymap.set('n', '<C-p>', find_files_recent, { desc = 'Find files (recent first)' })
        -- insert mode: nvim-cmp keeps <C-p> for the suggestion list and falls back here when it's closed
        vim.keymap.set('i', '<C-p>', '<Esc><C-p>', { remap = true, desc = 'Find files (recent first)' })

        -- <Space>w + h/j/k/l: go to the window in that direction; from the edge window
        -- there is none, so pick a file and open it in a new split on that side
        local sides = { h = 'leftabove vsplit', j = 'belowright split', k = 'leftabove split', l = 'belowright vsplit' }
        for key, split_cmd in pairs(sides) do
            vim.keymap.set('n', '<leader>w' .. key, function()
                if vim.fn.winnr(key) ~= vim.fn.winnr() then
                    vim.cmd('wincmd ' .. key)
                else
                    find_files_recent(split_cmd)
                end
            end, { desc = 'Go to window, or open a file in a new split on that side' })
        end

        -- Define actions first to keep the table clean
        local actions = require('telescope.actions')

        require('telescope').setup {
            defaults = {
                layout_strategy = 'horizontal',
                mappings = {
                    i = {
                        ['<C-k>'] = actions.move_selection_previous,
                        ['<C-j>'] = actions.move_selection_next,
                        ['<C-l>'] = actions.select_default,
                    },
                },
                scroll_strategy = 'limit',
            },
            pickers = {
                find_files = {
                    theme = 'ivy',
                    file_ignore_patterns = { 'node_modules', '.git', '.venv' },
                    hidden = true,
                },
                oldfiles = { theme = 'ivy' },                live_grep = { theme = 'ivy' },
                git_files = { theme = 'ivy' },
                git_commits = { theme = 'ivy' },
                git_branches = { theme = 'ivy' },
                git_status = { theme = 'ivy' },
                git_bcommits = { theme = 'ivy' },
                buffers = { theme = 'ivy' },
            },
            extensions = {
                ['ui-select'] = {
                    require('telescope.themes').get_dropdown(),
                },
                fzf = {},
            },
        } -- This closes the setup function

        -- Esc closes outright; Ctrl+[ is still "go to normal mode". Set here, not in
        -- `mappings`, which collapses <Esc> and <C-[> into the same termcode.
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "TelescopePrompt",
            callback = function(args)
                vim.keymap.set("i", "<Esc>", function() actions.close(args.buf) end, { buffer = args.buf })
                vim.keymap.set("i", "<C-[>", "<Cmd>stopinsert<CR>", { buffer = args.buf })
            end,
        })

        -- You must also load the extensions after setup
        require('telescope').load_extension('fzf')
        require('telescope').load_extension('ui-select')
        require('telescope').load_extension('file_browser')
    end -- This closes the config function,
    
}
