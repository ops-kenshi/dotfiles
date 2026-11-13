local opts = { noremap = true, silent = true }

local km = vim.keymap.set
local builtin = require('telescope.builtin')

-- Remove default behavior of space
km('', '<Space>', '<Nop>', opts)

-- Remove 'search' highlight when pressing normal mode 
km('n', '<Esc>', ':noh<CR>', { silent = true })
km('n', '<C-[>', ':noh<CR>', { silent = true })

-- Save file
km('', '<C-s>', ':w<CR>', opts)

km('n', 'j', 'gj', opts)
km('n', 'k', 'gk', opts)

-- Make 'x' remove character without copy to register
km('n', 'x', '"_x', opts)

-- Ctrl+d/u move the cursor half a page like '}'/'{' would; the view only scrolls
-- when the cursor runs into the edge (scrolloff), instead of always scrolling
local function half_page(dir)
    return function() return math.floor(vim.api.nvim_win_get_height(0) / 2) .. dir end
end
km({ 'n', 'v' }, '<C-d>', half_page('j'), { expr = true, silent = true })
km({ 'n', 'v' }, '<C-u>', half_page('k'), { expr = true, silent = true })

-- Ctrl+Shift+V: rich-cli preview of the current file in a split on the left. Renders
-- the saved file; press again (from either window) to refresh, q closes it.
km('n', '<C-S-v>', function()
    local file = vim.b.rich_preview or vim.fn.expand('%:p')
    if vim.fn.filereadable(file) == 0 then
        return vim.notify('Rich preview: save the file first', vim.log.levels.WARN)
    end
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.b[vim.api.nvim_win_get_buf(w)].rich_preview then vim.api.nvim_win_close(w, true) end
    end
    vim.cmd('topleft vnew')
    vim.fn.jobstart({ 'rich', file }, { term = true })
    vim.b.rich_preview = file
    vim.bo.bufhidden = 'wipe'
    vim.bo.buflisted = false
    km('n', 'q', '<Cmd>close<CR>', { buffer = true, silent = true })
end, { desc = 'Rich preview' })

-- Navigate through buffers
km('n', '<Tab>', ':bnext<cr>', opts) -- Next
km('n', '<S-Tab>', ':bprevious<cr>', opts) -- Previous

-- Windows: <Space>w acts as Ctrl-w (tmux uses Ctrl-w)
km('n', '<leader>w', '<C-w>', { desc = 'Window prefix' })
-- x and c swapped: x closes the window, c exchanges it with its neighbour
km('n', '<leader>wx', '<C-w>c', { desc = 'Close window' })
km('n', '<leader>wc', '<C-w>x', { desc = 'Exchange window with next' })

-- Disable the command-line window (opened by accident when typing :q)
km('n', 'q:', '<Nop>', opts)

-- Rename
-- km('n', '<leader>r', vim.lsp.buf.rename, { noremap = true, silent = true})
-- <leader>rn / <F2> live in plugins/renamer.lua

-- <Space><Space> lives in plugins/telescope.lua (find files, recent first)

-- <Space>rg Live grep 
km('n', '<leader>rg', builtin.live_grep, { desc = 'Telescope live grep' })


-- Advance New File
km("n", "<C-n>", ":Telescope file_browser hidden=true files=false depth=false<CR>", { noremap=true })

-- Manual command to delete current file
local km = vim.keymap.set

-- Close current buffer
km("n", "<leader>x", ":bdelete<CR>", { noremap = true, silent = true })

-- Comment out lines
km("n", "<C-_>", "gcc", { remap = true })
km("v", "<C-_>", "gcc", { remap = true })

-- Delete current file
 km("n", "<leader>df", function()
     local fb = require("telescope").extensions.file_browser
     fb.file_browser({
         path = "%:p:h",
         select_buffer = true,
         initial_mode = "normal"
     })
 end, { desc = "Delete current file via File Browser" })

-- Map Ctrl + . to code actions
km({'n', 'i'}, '<C-.>', vim.lsp.buf.code_action, { noremap = true, silent = true })

-- Esc closes the Lazy window (it only binds q); Ctrl+[ would fall back to Esc, so pin it to nothing
vim.api.nvim_create_autocmd("FileType", {
    pattern = "lazy",
    callback = function(args)
        km("n", "<Esc>", "q", { buffer = args.buf, remap = true })
        km("n", "<C-[>", "<Nop>", { buffer = args.buf })
    end,
})

-- <leader>[ / ]: collapse / expand the fold under the cursor
km('n', '<leader>[', function() pcall(vim.cmd, 'normal! zc') end, { desc = 'Collapse fold' })
km('n', '<leader>]', function() pcall(vim.cmd, 'normal! zo') end, { desc = 'Expand fold' })
