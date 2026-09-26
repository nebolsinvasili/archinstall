-- ==========================================================================
-- 4. CONFORM (Auto-Formatting)
-- ==========================================================================
return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	opts = {
		-- Define formatters per language
		formatters_by_ft = {
			lua = { "stylua" },
			python = { "isort", "black" },
			javascript = { "prettier" },
			typescript = { "prettier" },
			css = { "prettier" },
			html = { "prettier" },
			json = { "prettier" },
			yaml = { "prettier" },
			markdown = { "prettier" },
			bash = { "shfmt" },
		},

		-- Format on save settings
		format_on_save = {
			timeout_ms = 500,
			lsp_fallback = true, -- Use LSP formatting if no formatter defined above
		},
	},
}
