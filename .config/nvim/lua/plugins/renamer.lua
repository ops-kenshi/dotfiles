return {
    'filipdutescu/renamer.nvim',
    dependencies = 'nvim-lua/plenary.nvim',
    keys = {
        { '<leader>r', function() require('renamer').rename() end, mode = { 'n', 'v' }, desc = 'Rename Symbol' },
        { '<F2>', function() require('renamer').rename() end, mode = 'i', desc = 'Rename Symbol' },
    },
    opts = {},
}
