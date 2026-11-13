-- vim: ts=2 sts=2 sw=2 et

-- External tools required
-- Windows Terminal + pwsh
-- mingw64 toolchain: https://www.msys2.org/
-- ripgrep: https://github.com/BurntSushi/ripgrep
-- win32yank for clipboard integration
-- sharkdp/fd

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  -- bootstrap lazy.nvim
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

vim.g.loaded_python3_provider = 0

local opt = vim.opt

opt.encoding = "utf-8"
opt.fileencoding = "utf-8"

opt.clipboard = "unnamedplus"
opt.completeopt = "menu,menuone,noselect"
opt.mouse = "a"

opt.autowrite = true
opt.confirm = true
opt.inccommand = "nosplit"
opt.laststatus = 0
opt.list = true

opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true

opt.cursorline = true
opt.number = true
opt.relativenumber = true

opt.splitbelow = true
opt.splitright = true

opt.scrolloff = 4
opt.sidescrolloff = 8
opt.winminwidth = 5

opt.expandtab = true
opt.shiftwidth = 4
opt.shiftround = true
opt.tabstop = 4

opt.showmode = false
opt.signcolumn = "yes"
opt.termguicolors = true
opt.hidden = true

opt.undofile = true
opt.undolevels = 10000

opt.secure = true
opt.exrc = true

-- set leader key to space
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>')

-- terminal settings (Windows only -- setting these on macOS/Linux points
-- 'shell' at a non-existent powershell and breaks :terminal, :!, system(),
-- plugin `build` steps and mason installs)
if vim.fn.has("win32") == 1 then
local powershell_options = {
  shell = vim.fn.executable "pwsh" == 1 and "pwsh" or "powershell",
  shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;",
  shellredir = "-RedirectStandardOutput %s -NoNewWindow -Wait",
  shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode",
  shellquote = "",
  shellxquote = "",
}

for option, value in pairs(powershell_options) do
  vim.opt[option] = value
end
end

-- minimize terminal split
vim.keymap.set('n', '<C-g>', "3<C-w>_")

-- plugins

require("lazy").setup({
  { import = "plugins" },
})

-- set colour scheme
vim.g.everforest_enable_italic = true
vim.cmd.colorscheme "vitesse"

-- up / down with line wrap
vim.keymap.set('n', '<Up>', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', '<Down>', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- lsp keybindings
-- tsserver can return extra results besides the real definition, which makes Neovim
-- open a quickfix list instead of jumping. Drop:
--  * Vue's generated `__VLS_unwrap` helper (in Mason's vue-language-server package),
--    returned for variables used in a .vue <template>
--  * the symbol under the cursor itself, returned for shorthand properties like
--    `return { focusedDay }`
local function goto_definition()
  local file = vim.api.nvim_buf_get_name(0)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1
  local function is_cursor(item)
    if item.filename ~= file then return false end
    local end_lnum, end_col = item.end_lnum or item.lnum, item.end_col or item.col
    return (row > item.lnum or (row == item.lnum and col >= item.col))
      and (row < end_lnum or (row == end_lnum and col < end_col))
  end
  vim.lsp.buf.definition({
    on_list = function(res)
      local items = vim.tbl_filter(function(item)
        return not item.filename:find('/vue-language-server/', 1, true) and not is_cursor(item)
      end, res.items)
      if #items == 0 then items = res.items end
      vim.fn.setqflist({}, ' ', { title = res.title, items = items, context = res.context })
      vim.cmd(#items == 1 and 'cfirst' or 'copen')
    end,
  })
end

vim.keymap.set('n', '<leader>gd', goto_definition, {desc = 'Goto Definition'})
vim.keymap.set('n', 'gd', goto_definition, {desc = 'Goto Definition'})
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, {desc = 'Code Action'})
vim.keymap.set('n', 'K', vim.lsp.buf.hover, {desc = 'Hover Documentation'})
vim.keymap.set('n', '<leader>ff', vim.lsp.buf.format, {desc = 'Format Code'})
vim.keymap.set('n', '<leader>lr', '<cmd>LspRestart<CR>', {desc = 'Restart LSP'})
vim.diagnostic.config({
  virtual_lines = { current_line=true },  -- Enables inline error/warning text
})

-- Own Settings
require 'core.opts'
require 'core.keymaps'
