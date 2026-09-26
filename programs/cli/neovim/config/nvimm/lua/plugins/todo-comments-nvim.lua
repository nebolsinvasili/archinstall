-- ==========================================================================
-- 1. TODO COMMENTS
-- ==========================================================================
return {
	"folke/todo-comments.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	event = { "BufReadPost", "BufNewFile" },

	opts = {
		-- ----------------------------------------------------------------------
		-- General Settings
		-- ----------------------------------------------------------------------
		signs = true, -- Show icons in the sign column
		sign_priority = 8, -- Sign priority
		merge_keywords = true, -- Merge with default keywords

		-- ----------------------------------------------------------------------
		-- Keywords
		-- ----------------------------------------------------------------------
		keywords = {
			-- FIX: Fix comment.
			FIX = {
				icon = " ", -- icon used for the sign, and in search results
				color = "error", -- can be a hex color, or a named color (see below)
				alt = { "FIXME", "BUG", "FIXIT", "ISSUE" }, -- a set of other keywords that all map to this FIX keywords
				-- signs = false, -- configure signs for some keywords individually
			},
			-- TODO: Todo comment.
			TODO = { icon = "", color = "info" },
			-- DONE: Done comment.
			DONE = { icon = "", color = "done" },
			-- HACK: Hack comment.
			HACK = { icon = "", color = "warning" },
			-- WARN: Warn comment.
			WARN = { icon = "", color = "warning", alt = { "WARNING", "XXX" } },
			-- PERF: Perf comment.
			PERF = { icon = "󰥔", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
			-- NOTE: Note comment.
			NOTE = { icon = "󱞁", color = "hint", alt = { "INFO" } },
			-- TEST: Test comment.
			TEST = { icon = "", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
		},

		-- ----------------------------------------------------------------------
		-- Highlighting
		-- ----------------------------------------------------------------------
		highlight = {
			before = "fg", -- Options: "fg", "bg", "wide", or empty
			keyword = "wide", -- Options: "fg", "bg", "wide", or empty
			after = "fg", -- Options: "fg", "bg", "wide", or empty
			pattern = [[.*<(KEYWORDS)\s*:]],
			comments_only = true, -- Match only inside comments
			max_line_len = 400, -- Ignore lines longer than this
			exclude = {}, -- List of filetypes to exclude
		},

		-- ----------------------------------------------------------------------
		-- Colors
		-- ----------------------------------------------------------------------
		colors = {
			error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
			warning = { "DiagnosticWarning", "WarningMsg", "#FBBF24" },
			info = { "DiagnosticInfo", "#7FB4CA" },
			done = { "DiagnosticDone", "#00A600" },
			hint = { "DiagnosticHint", "#10B981" },
			default = { "Identifier", "#C34043" },
		},

		-- ----------------------------------------------------------------------
		-- Search (Ripgrep)
		-- ----------------------------------------------------------------------
		search = {
			command = "rg",
			args = {
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
			},
			pattern = [[\b(KEYWORDS)\b\s*:]],
		},
	},
}
