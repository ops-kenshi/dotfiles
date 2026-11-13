local syntax_ns = vim.api.nvim_create_namespace('GlanceListSyntax')

-- Treesitter highlight captures covering `row` of the source. Uses the loaded
-- buffer's parser (keeps injections, e.g. <script> in .vue) and falls back to
-- parsing the single line on its own when the file isn't loaded.
local function row_captures(location)
    local bufnr, row, source = location.bufnr, location.start_line, nil
    local parser

    if vim.api.nvim_buf_is_loaded(bufnr) then
        local ok, p = pcall(vim.treesitter.get_parser, bufnr)
        if ok and p then
            parser, source = p, bufnr
            parser:parse({ row, row + 1 })
        end
    end

    if not parser then
        local ft = vim.filetype.match({ filename = location.filename })
        local lang = ft and vim.treesitter.language.get_lang(ft)
        local ok, p = pcall(vim.treesitter.get_string_parser, location.full_text, lang or '')
        if not (lang and ok and p) then
            return {}
        end
        parser, source, row = p, location.full_text, 0
        parser:parse(true)
    end

    local captures = {}
    parser:for_each_tree(function(tree, ltree)
        local lang = ltree:lang()
        local query = vim.treesitter.query.get(lang, 'highlights')
        if not query then
            return
        end
        for id, node, metadata in query:iter_captures(tree:root(), source, row, row + 1) do
            local name = query.captures[id]
            if not name:match('^_') and name ~= 'spell' and name ~= 'nospell' then
                local sr, sc, er, ec = node:range()
                if sr <= row and er >= row then
                    table.insert(captures, {
                        from = sr < row and 0 or sc,
                        to = er > row and math.huge or ec,
                        group = '@' .. name .. '.' .. lang,
                        priority = tonumber(metadata.priority) or 100,
                    })
                end
            end
        end
    end)
    return captures
end

-- Paint syntax colours onto each location row of the list window. Priority
-- stays below Glance's own ListMatch extmark (4096) so the match highlight wins.
local function highlight_list(list)
    vim.api.nvim_buf_clear_namespace(list.bufnr, syntax_ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(list.bufnr, 0, -1, false)

    for lnum, item in pairs(list.items) do
        local text = lines[lnum]
        if text and not item.is_group and item.preview_line then
            local p = item.preview_line.value
            local shown = p.before .. p.inside .. p.after
            -- Where the shown snippet starts in the list row and in the source line.
            local list_col = #text - #shown
            local src_col = item.full_text:find(shown, 1, true)
            if src_col and list_col >= 0 then
                src_col = src_col - 1
                local src_end = src_col + #shown
                for _, c in ipairs(row_captures(item)) do
                    local from, to = math.max(c.from, src_col), math.min(c.to, src_end)
                    if from < to then
                        pcall(vim.api.nvim_buf_set_extmark, list.bufnr, syntax_ns, lnum - 1, list_col + from - src_col, {
                            end_col = list_col + to - src_col,
                            hl_group = c.group,
                            priority = c.priority,
                        })
                    end
                end
            end
        end
    end
end

return {
    'dnlhc/glance.nvim',
    cmd = 'Glance',
    keys = {
        { 'gr', '<cmd>Glance references<CR>', desc = 'References (peek)' },
    },
    opts = function()
        local actions = require('glance').actions
        return {
            border = { enable = true },
            mappings = {
                -- buffer-local, so they beat the global <C-n> (file browser) / <C-p> (find files)
                list = {
                    ['<C-n>'] = actions.next,
                    ['<C-p>'] = actions.previous,
                    -- scroll the preview without leaving the list (negative = down)
                    ['J'] = actions.preview_scroll_win(-3),
                    ['K'] = actions.preview_scroll_win(3),
                    ['j'] = actions.preview_scroll_win(-1),
                    ['k'] = actions.preview_scroll_win(1),
                },
            },
        }
    end,
    config = function(_, opts)
        require('glance').setup(opts)

        -- Glance has no hook for list rendering, so wrap it.
        local List = require('glance.list')
        local render = List.render
        List.render = function(self, groups)
            render(self, groups)
            pcall(highlight_list, self)
        end
    end,
}
