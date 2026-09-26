-- Import user environment settings
local env = require("config.user_env").config

return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local transparent_background = require("lualine.themes.auto")

		local lualine_modes = {
			"insert",
			"normal",
			"visual",
			"command",
			"replace",
			"inactive",
			"terminal",
		}

		for _, field in ipairs(lualine_modes) do
			if transparent_background[field] and transparent_background[field].c then
				transparent_background[field].c.bg = "NONE"
			end
		end

		local conditions = {
			buffer_not_empty = function()
				return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
			end,
			hide_in_width = function()
				return vim.fn.winwidth(0) > 80
			end,
			check_git_workspace = function()
				local filepath = vim.fn.expand("%:p:h")
				local gitdir = vim.fn.finddir(".git", filepath .. ";")
				return gitdir and #gitdir > 0 and #gitdir < #filepath
			end,
		}

		local nvim_tree_shift = {
			function()
				len = vim.api.nvim_win_get_width(require("nvim-tree.view").get_winnr()) - 1
				title = "Nvim-Tree"
				left = (len - #title) / 2
				right = len - left - #title

				return string.rep(" ", left) .. title .. string.rep(" ", right)
			end,

			-- function ()
			-- 	return string.rep(' ',
			-- 		vim.api.nvim_win_get_width(require'nvim-tree.view'.get_winnr()) - 1)
			-- end,
			cond = require("nvim-tree.view").is_visible,
			color = "NvimTreeNormal",
		}

		local mode = {
			"mode",
			fmt = function(str)
				return str
			end,
			padding = { left = 1, right = 1 },
		}

		local branch = {
			"b:gitsigns_head",
			icon = " ",
		}

		local filename = {
			"filename",
			file_status = true,
			path = 4,
			symbols = { modified = " ", readonly = " " },
		}

		local diagnostics = {
			"diagnostics",
			sources = { "nvim_diagnostic" },
			sections = { "error", "warn", "info", "hint" },
			symbols = { error = " ", warn = " ", info = " ", hint = " " },
			colored = true,
			update_in_insert = true,
			always_visible = false,
			padding = { left = 1, right = 3 },
		}
		local diff = {
			"diff",
			colored = true,
			symbols = { added = " ", modified = " ", removed = " " },
			padding = { left = 2, right = 10 },
		}
		local lsp = {
			-- LSP server name .
			function()
				local msg = "No Active Lsp"
				local buf_ft = vim.api.nvim_buf_get_option(0, "filetype")
				local clients = vim.lsp.get_active_clients()
				if next(clients) == nil then
					return msg
				end
				for _, client in ipairs(clients) do
					local filetypes = client.config.filetypes
					if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
						return client.name
					end
				end
				return msg
			end,
			icon = " LSP:",
			symbols = {
				-- Standard unicode symbols to cycle through for LSP progress:
				spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
				-- Standard unicode symbol for when LSP is done:
				done = "✓",
				-- Delimiter inserted between LSP names:
				separator = " ",
			},
			color = { fg = "#ffffff", gui = "bold" },
			padding = { left = 1, right = 1 },
			ignore_lsp = {}, -- List of LSP names to ignore (e.g., `null-ls`):
		}
		local filetype = {
			"filetype",
			padding = { left = 1, right = 1 },
		}

		local fileformat = {
			"fileformat",
			symbols = {
				unix = " ",
				dos = " ",
				mac = " ",
			},
		}

		local encoding = {
			"encoding",
		}

		local location = {
			"location",
		}

		local config = {
			options = {
				-- theme = transparent_background,
				icons_enabled = true,
				section_separators = { left = "", right = "" },
				component_separators = { left = "", right = "" },
				disabled_filetypes = { "alpha" },
				globalstatus = false,
			},
			sections = {
				lualine_a = {
					mode,
				},
				lualine_b = {
					branch,
				},
				lualine_c = {
					filename,
				},
				lualine_x = {
					diagnostics,
					diff,
					lsp,
					filetype,
				},
				lualine_y = {
					-- encoding,
					fileformat,
				},
				lualine_z = {
					location,
				},
			},
			inactive_sections = {
				lualine_a = {
					mode,
				},
				lualine_b = {
					branch,
				},
				lualine_c = {
					filename,
				},
				lualine_x = {
					diagnostics,
					diff,
					lsp,
					filetype,
				},
				lualine_y = {
					-- encoding,
					fileformat,
				},
				lualine_z = {
					location,
				},
			},
			tabline = { -- If you want tabline to shift too
				-- lualine_a = { nvim_tree_shift },
			},
			extensions = {
				"fugitive",
				"nvim-tree",
				"lazy",
				"mason",
				"man",
			},
		}

		require("lualine").setup(config)
	end,
}
