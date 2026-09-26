-- ==========================================================================
-- 1. SNIPPET ENGINE (LuaSnip)
-- ==========================================================================
return {
	"L3MON4D3/LuaSnip",
	version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first is v2)
	build = "make install_jsregexp",
	dependencies = { "rafamadriz/friendly-snippets" },
	event = "InsertEnter", -- Load early for snippets

	config = function()
		local ls = require("luasnip")
		local types = require("luasnip.util.types")

		-- 1. LOAD SNIPPETS
		-- ----------------------------------------------------------------------
		-- NOTE: bin/snippets/ was a vendored copy of friendly-snippets and
		-- caused duplicate registration. Rely on the plugin below instead.
		-- Add your own .snippets here if desired:
		-- require("luasnip.loaders.from_snipmate").lazy_load({
		--     paths = { vim.fn.stdpath("config") .. "/bin/snippets" },
		-- })
		require("luasnip.loaders.from_lua").lazy_load({
			paths = { vim.fn.stdpath("config") .. "/bin/node_snippets/" },
		})

		-- Load standard community snippets (friendly-snippets) as fallback
		require("luasnip.loaders.from_vscode").lazy_load()

		-- 2. CONFIGURATION
		-- ----------------------------------------------------------------------
		ls.config.setup({
			history = true, -- Keep around last snippet local to jump back
			update_events = "TextChanged,TextChangedI", -- Update dynamic snippets as you type
			enable_autosnippets = true, -- Enable auto-trigger snippets
			store_selection_keys = "<A-p>", -- Key to store selection for visual snippets

			-- Visual feedback for Choice Nodes (multiple options in a snippet)
			ext_opts = {
				[types.choiceNode] = {
					active = {
						virt_text = { { "●", "GruvboxOrange" } },
					},
				},
			},
		})

		-- 3. SNIPPET NAVIGATION KEYMAPS
		-- ----------------------------------------------------------------------
		-- Must be defined here (after LuaSnip is loaded), not in
		-- lua/config/keymaps.lua which runs before this plugin loads.
		local smap = { noremap = true, silent = true }

		-- Jump to next/prev placeholder
		vim.keymap.set({ "i", "s" }, "<A-k>", function()
			if ls.jumpable(1) then
				ls.jump(1)
			end
		end, smap)

		vim.keymap.set({ "i", "s" }, "<A-j>", function()
			if ls.jumpable(-1) then
				ls.jump(-1)
			end
		end, smap)

		-- Cycle through choice nodes
		vim.keymap.set({ "i", "s" }, "<A-l>", function()
			if ls.choice_active() then
				ls.change_choice(1)
			end
		end, smap)

		vim.keymap.set({ "i", "s" }, "<A-h>", function()
			if ls.choice_active() then
				ls.change_choice(-1)
			end
		end, smap)
	end,
}
