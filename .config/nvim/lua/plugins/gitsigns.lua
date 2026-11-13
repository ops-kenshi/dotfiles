return {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
        { '<leader>gb', function() require('gitsigns').blame_line({ full = true }) end, desc = 'Blame Line (full)' },
        { '<leader>gB', '<cmd>Gitsigns toggle_current_line_blame<CR>', desc = 'Toggle Inline Blame' },
    },
    opts = {
        -- GitLens-style author/date/summary at the end of the cursor line
        current_line_blame = true,
        current_line_blame_opts = {
            virt_text_pos = 'eol',
            delay = 300,
        },
        current_line_blame_formatter = '<author>, <author_time:%R> • <summary>',
    },
}
