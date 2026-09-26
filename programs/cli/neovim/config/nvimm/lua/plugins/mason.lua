-- ==========================================================================
-- 2. MASON (Tool Installer)
-- ==========================================================================
return {
	"williamboman/mason.nvim",
	cmd = "Mason",
	dependencies = {
		"williamboman/mason-lspconfig.nvim", -- Bridge between Mason & LSPConfig
		"WhoIsSethDaniel/mason-tool-installer.nvim", -- Auto-installer for Linters/Formatters
	},

	config = function()
		local mason = require("mason")
		local mason_lspconfig = require("mason-lspconfig")
		local mason_tool_installer = require("mason-tool-installer")

		-- 1. Setup Mason UI
		-- ----------------------------------------------------------------------
		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		-- 2. Setup Tool Installer (Formatters & Linters)
		-- ----------------------------------------------------------------------
		mason_tool_installer.setup({
			ensure_installed = {
				"prettier", -- JS/TS/HTML/CSS Formatter
				"stylua", -- Lua Formatter
				"black", -- Python Formatter
				"isort", -- Python Import Sorter
				"flake8", -- Python Linter
				"shellcheck", -- Bash Linter
				"shfmt", -- Bash Formatter
				"clang-format", -- C/C++ Formatter
				"eslint_d", -- JS/TS Linter
				"jdtls",
			},
		})

		-- 3. Setup Mason-LSPConfig (Language Servers)
		-- ----------------------------------------------------------------------
		mason_lspconfig.setup({
			ensure_installed = {
				"lua_ls",
				"pyright",
				-- Add other servers here (e.g., "tsserver", "clangd")
			},
			automatic_installation = true,
		})
	end,
}
