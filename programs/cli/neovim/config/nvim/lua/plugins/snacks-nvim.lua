-- ==========================================================================
-- SNACKS.NVIM (Telescope Replacement: Picker)
-- ==========================================================================
-- Provides the global "Snacks" used by lua/config/keymaps.lua and the
-- dashboard (utils/dash.lua). Loaded at startup so that keymaps can resolve it.
return {
	"folke/snacks.nvim",
	priority = 1000,
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		picker = { enabled = true },
	},
	config = function(_, opts)
		require("snacks").setup(opts)
	end,
}