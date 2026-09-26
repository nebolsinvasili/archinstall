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
		-- Load custom snippets from config path (Legacy SnipMate support)
		require("luasnip.loaders.from_snipmate").lazy_load({
			paths = { vim.fn.stdpath("config") .. "/bin/snippets" },
		})
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
	end,
}
