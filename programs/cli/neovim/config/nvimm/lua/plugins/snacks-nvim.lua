-- ==========================================================================
-- 5. SNACKS.NVIM
-- ==========================================================================
-- A collection of small utilities (Picker, BigFile, etc.)
return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		-- Picker: Acts as a Telescope replacement
		picker = { enabled = true },

		-- Helpers: Run in background to improve performance/experience
		bigfile = { enabled = true },
		quickfile = { enabled = true },
	},
}
