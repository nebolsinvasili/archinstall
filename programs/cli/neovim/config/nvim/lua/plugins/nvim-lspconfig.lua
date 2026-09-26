-- ==========================================================================
-- LSP CONFIGURATION (nvim-lspconfig)
-- ==========================================================================
-- Bridges servers installed by Mason with nvim's built-in LSP client.
-- nvim-lspconfig 1.0 / Nvim 0.11+: servers are started via `vim.lsp.enable`
-- by mason-lspconfig's automatic_enable (see lua/plugins/mason.lua).
-- Default on_attach Keymaps live in lua/config/keymaps.lua (Snacks picker).
return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
	},
	config = function()
		vim.api.nvim_create_autocmd("LspAttach", {
			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if client and client:supports_method("textDocument/formatting") then
					vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, {
						buffer = event.buf,
						desc = "Format buffer",
					})
				end
			end,
		})
	end,
}