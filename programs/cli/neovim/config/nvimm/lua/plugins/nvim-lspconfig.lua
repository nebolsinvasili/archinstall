-- ==========================================================================
-- 3. LSP CONFIG (Language Server Setup)
-- ==========================================================================
return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		"hrsh7th/cmp-nvim-lsp", -- Links LSP to Autocompletion
	},

	config = function()
		local lspconfig = require("lspconfig")
		local mason_lsp = require("mason-lspconfig")
		local capabilities = require("cmp_nvim_lsp").default_capabilities()

		-- 1. Diagnostic UI Configuration
		-- ----------------------------------------------------------------------
		local x = vim.diagnostic.severity
		local icons = require("config.icons")
		vim.diagnostic.config({
			virtual_text = {
				prefix = "",
				format = function(diagnostic)
					return icons.misc.Ghost .. " " .. diagnostic.message .. " "
				end,
			},
			signs = {
				text = {
					[x.ERROR] = " ",
					[x.WARN] = " ",
					[x.HINT] = " ",
					[x.INFO] = " ",
				},
			},
			underline = true, -- Underline errors
			update_in_insert = false, -- Don't update while typing
			severity_sort = true, -- Sort by severity
			float = {
				focusable = false,
				style = "minimal",
				border = "rounded",
				source = "always",
				header = "",
				prefix = "",
			},
		})

		-- 2. Setup Handlers (CRITICAL)
		-- ----------------------------------------------------------------------
		-- This function automatically sets up every server installed via Mason
		-- mason_lsp.setup_handlers({
		--     function(server_name)
		--         lspconfig[server_name].setup({
		--             capabilities = capabilities,
		--             -- Add 'on_attach' here if you want legacy keymaps
		--         })
		--     end,
		-- })

		-- 3. LspAttach Autocommand
		-- ----------------------------------------------------------------------
		-- Use this to set keymaps only when an LSP attaches to a buffer
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Example: Enable omnifunc
				-- vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

				-- NOTE: We are using Snacks.picker for LSP navigation (gd, gr, etc.)
				-- defined in keymaps.lua, so we don't need to duplicate them here.
				-- You can add buffer-local mappings here like 'K' for hover if needed.
			end,
		})
	end,
}
