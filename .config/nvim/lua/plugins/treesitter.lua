return {
    "nvim-treesitter/nvim-treesitter",
    -- `master` breaks on nvim 0.12 (its markdown injection directives crash the
    -- highlighter). Incremental selection is built in now: `an` / `in` in visual mode.
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter").install({ "c", "lua", "vim", "vimdoc", "query", "python", "javascript", "markdown", "markdown_inline", "typescript", "tsx", "vue", "html", "css", "just", "make" })
        vim.api.nvim_create_autocmd("FileType", {
            callback = function(args) pcall(vim.treesitter.start, args.buf) end,
        })
    end,
}
