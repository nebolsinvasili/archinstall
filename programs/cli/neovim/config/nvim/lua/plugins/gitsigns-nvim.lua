-- ==========================================================================
-- GITSIGNS (Git Signs in Sign Column)
-- ==========================================================================
-- Provides the "b:gitsigns_head" variable and diff data used by lualine.
return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		on_attach = function(bufnr)
			vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { buffer = bufnr, desc = "Toggle line blame" })
		end,
	},
}