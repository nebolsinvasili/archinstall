-- ==========================================================================
-- TREESITTER (Syntax Highlighting & Indentation)
-- ==========================================================================
-- nvim-treesitter is a full rewrite (2025): parser management via
-- require('nvim-treesitter').install / :TSUpdate, highlighting is the
-- native `vim.treesitter.start()`. Does NOT support lazy-loading.
-- Query overrides live in after/queries/<lang>/highlights.scm
return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local parsers = {
			"bash",
			"c",
			"cpp",
			"css",
			"html",
			"javascript",
			"json",
			"lua",
			"markdown",
			"python",
			"rust",
			"typescript",
			"vim",
			"yaml",
		}

		-- Install missing parsers (async; no-op when already installed).
		-- Requires tree-sitter-cli and a C compiler (see the plugin README).
		if vim.fn.executable("tree-sitter") == 1 then
			pcall(function()
				require("nvim-treesitter").install(parsers)
			end)
		end

		-- Highlighting: enable `vim.treesitter.start()` for known filetypes.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = parsers,
			callback = function()
				vim.treesitter.start()
			end,
		})

		-- Experimental tree-sitter indentation for the same filetypes.
		vim.api.nvim_create_autocmd("FileType", {
			pattern = parsers,
			callback = function()
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}