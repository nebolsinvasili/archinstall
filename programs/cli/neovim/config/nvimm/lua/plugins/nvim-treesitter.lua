-- ==========================================================================
-- 1. TREESITTER (Syntax Highlighting)
-- ==========================================================================
return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },

	opts = {
		ensure_installed = {
			"lua",
			"python",
			"java",
			"markdown",
			"markdown_inline",
			"bash",
			"vim",
			"vimdoc",
		},
		sync_install = false,
		auto_install = true,

		-- Highlighting Configuration
		highlight = {
			enable = true,
			-- Note: turning this on may slow down large files
			additional_vim_regex_highlighting = true,
		},

		-- Indentation
		indent = {
			enable = true,
		},
	},

	config = function(_, opts)
		require("nvim-treesitter").setup(opts)
	end,
}
