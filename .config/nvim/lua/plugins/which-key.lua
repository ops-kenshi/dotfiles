-- popup listing the keys that can follow a prefix (e.g. <Space>) and what each does
return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        spec = {
            { "<leader>b", group = "Buffer" },
            { "<leader>c", group = "Code" },
            { "<leader>d", group = "Delete" },
            { "<leader>f", group = "Format" },
            { "<leader>g", group = "Git / Goto" },
            { "<leader>l", group = "LSP" },
            { "<leader>w", group = "Window" },
        },
    },
    keys = {
        { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer-local keymaps" },
    },
}
