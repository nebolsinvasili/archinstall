-- ==========================================================================
-- 2. GITSIGNS
-- ==========================================================================
return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		-- ----------------------------------------------------------------------
		-- Signs Configuration
		-- ----------------------------------------------------------------------
		-- Geometric Theme with linked Highlight Groups
		signs = {
			add = {
				hl = "GitSignsAdd",
				text = "▎",
				numhl = "GitSignsAddNr",
				linehl = "GitSignsAddLn",
			},
			change = {
				hl = "GitSignsChange",
				text = "▎",
				numhl = "GitSignsChangeNr",
				linehl = "GitSignsChangeLn",
			},
			delete = {
				hl = "GitSignsDelete",
				text = "▎",
				numhl = "GitSignsDeleteNr",
				linehl = "GitSignsDeleteLn",
			},
			topdelete = {
				hl = "GitSignsDelete",
				text = "▎",
				numhl = "GitSignsDeleteNr",
				linehl = "GitSignsDeleteLn",
			},
			changedelete = {
				hl = "GitSignsChange",
				text = "▎",
				numhl = "GitSignsChangeNr",
				linehl = "GitSignsChangeLn",
			},
			untracked = {
				hl = "GitSignsAdd",
				text = "┆",
				numhl = "GitSignsAddNr",
				linehl = "GitSignsAddLn",
			},
		},

		-- ----------------------------------------------------------------------
		-- General Settings
		-- ----------------------------------------------------------------------
		signcolumn = true, -- Toggle with :Gitsigns toggle_signs
		numhl = false, -- Toggle with :Gitsigns toggle_numhl
		linehl = false, -- Toggle with :Gitsigns toggle_linehl
		word_diff = false, -- Toggle with :Gitsigns toggle_word_diff
		current_line_blame = false, -- Toggle with :Gitsigns toggle_current_line_blame
		sign_priority = 6,
		attach_to_untracked = true,

		-- ----------------------------------------------------------------------
		-- Watch & Debounce
		-- ----------------------------------------------------------------------
		watch_gitdir = {
			interval = 1000,
			follow_files = true,
		},
		update_debounce = 100,

		-- ----------------------------------------------------------------------
		-- Preview Options
		-- ----------------------------------------------------------------------
		preview_config = {
			border = "single",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},

		-- ----------------------------------------------------------------------
		-- Custom Highlights & Keymaps
		-- ----------------------------------------------------------------------
		on_attach = function(bufnr)
			-- Force vibrant colors (adjust Hex codes if you prefer different shades)
			vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#98be65", bold = true }) -- Vibrant Green
			vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#ecbe7b", bold = true }) -- Vibrant Orange/Yellow
			vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#ff6c6b", bold = true }) -- Vibrant Red

			-- Keymap: 'gs' to preview the hunk at cursor
			local gs = package.loaded.gitsigns
			vim.keymap.set("n", "gs", gs.preview_hunk, { buffer = bufnr, desc = "Preview Git Hunk" })
		end,
	},
}
