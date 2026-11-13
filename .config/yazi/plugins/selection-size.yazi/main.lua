--- @since 26.8.15
-- Shows the total size of the selected files in the status bar, between the
-- hovered file's size and its name. Folders are summed recursively in the
-- background; the status component re-triggers the calculation whenever the
-- selection changes.

local snapshot = ya.sync(function()
	local urls, keys = {}, {}
	for _, f in pairs(cx.active.selected) do
		urls[#urls + 1] = f.url
		keys[#keys + 1] = tostring(f.url)
	end
	return table.concat(keys, "\n"), urls
end)

-- Only the latest requested selection may write its result, so a slow
-- calculation for an old selection can't overwrite a newer one.
local report = ya.sync(function(st, key, size, done)
	if st.pending ~= key then
		return
	end
	st.key, st.size = key, size
	if done then
		st.pending = nil
	end
	ui.render()
end)

local M = {}

function M:setup()
	local st = self
	Status:children_add(function(status)
		local keys = {}
		for _, f in pairs(status._tab.selected) do
			keys[#keys + 1] = tostring(f.url)
		end
		if #keys == 0 then
			st.key, st.size = nil, nil
			return ""
		end

		local key = table.concat(keys, "\n")
		if key ~= st.pending and (key ~= st.key or st.pending) then
			st.pending = key
			ya.emit("plugin", { "selection-size" })
		end

		local text = "…"
		if st.key == key then
			text = st.size and ya.readable_size(st.size) or "?"
			if st.pending then
				text = text .. "…"
			end
		end
		return ui.Span(" Σ " .. text):fg(status:style().alt:bg())
	end, 2500, Status.LEFT)
end

function M:entry()
	local key, urls = snapshot()
	local sum, last = 0, 0
	for _, url in ipairs(urls) do
		local it = fs.calc_size(url)
		if not it then
			return report(key, nil, true)
		end
		while true do
			local next, now = it:recv(), ya.time()
			if not next then
				break
			end
			sum = sum + next
			if now >= last + 0.1 then
				last = now
				report(key, sum, false)
			end
		end
	end
	report(key, sum, true)
end

return M
