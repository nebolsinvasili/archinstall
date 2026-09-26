-- ==========================================================================
-- 1. FILE EXPLORER (NvimTree)
-- ==========================================================================
return {
	"nvim-tree/nvim-tree.lua",
	version = "*",
	lazy = true,
	dependencies = { "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle Explorer" },
	},

	config = function()
		local nvim_tree = require("nvim-tree")

		-- ----------------------------------------------------------------------
		-- Setup Options
		-- ----------------------------------------------------------------------
		nvim_tree.setup({
			-- on_attach               = on_attach,
			on_attach = require("config.keymaps").nvim_tree(),
			disable_netrw = true,
			hijack_netrw = true,
			sync_root_with_cwd = true,
			auto_reload_on_write = true,

			-- Update behavior
			update_focused_file = {
				enable = true,
				update_root = true,
			},

			-- Git integration
			git = {
				enable = true,
				ignore = true,
				timeout = 500,
			},

			-- Filters
			filters = {
				dotfiles = true,
				git_ignored = true,
				custom = { ".git" },
				exclude = {},
			},

			-- UI / View
			view = {
				width = 30,
				side = "left",
			},

			-- Renderer & Icons
			renderer = {
				full_name = true,
				highlight_git = true,
				highlight_hidden = "name",
				hidden_display = function(hidden_stats)
					local total = 0
					local parts = {}
					local reasons = {
						bookmark = "закладки",
						buf = "буферы",
						custom = "пользовательские",
						dotfile = "dot-файлы",
						git = "git",
						live_filter = "фильтр",
					}

					for reason, count in pairs(hidden_stats) do
						if count > 0 then
							total = total + count
							table.insert(parts, reasons[reason] .. ": " .. count)
						end
					end

					if total > 0 then
						return "Скрыто: " .. total .. " (" .. table.concat(parts, ", ") .. ")"
					end
					return nil
				end,
				root_folder_label = function(path)
					return "./" .. vim.fn.fnamemodify(path, ":t")
				end,
				indent_markers = {
					enable = true,
					--icons = {
					--corner = '└ ',
					--edge = '│ ',
					--none = '  ',
					--},
				},
				icons = {
					padding = " ",
					web_devicons = {
						file = {
							enable = true,
							color = true,
						},
						folder = {
							enable = false,
							color = true,
						},
					},
					diagnostics_placement = "before",
					glyphs = {
						default = " ",
						symlink = " ",
						folder = {
							arrow_open = " ",
							arrow_closed = " ",
							default = " ",
							open = " ",
							empty = " ",
							empty_open = " ",
							symlink = " ",
							symlink_open = " ",
						},
						git = {
							unstaged = " ",
							staged = " ",
							unmerged = " ",
							renamed = " ",
							untracked = " ",
							deleted = " ",
							ignored = " ",
						},
					},
				},
			},
			hijack_directories = {
				enable = true,
				auto_open = true,
			},
			system_open = {
				cmd = "",
				args = {},
			},
			diagnostics = {
				enable = true,
				show_on_dirs = true,
				icons = {
					hint = " ",
					info = " ",
					warning = " ",
					error = " ",
				},
			},
			actions = {
				use_system_clipboard = true,
				change_dir = {
					enable = true,
					global = false,
					restrict_above_cwd = false,
				},
				open_file = {
					quit_on_open = false,
					resize_window = true,
					relative_path = true,
					window_picker = {
						enable = true,
						chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
						exclude = {
							filetype = { "notify", "qf", "diff", "fugitive", "fugitiveblame" },
							buftype = { "nofile", "terminal", "help" },
						},
					},
				},
			},
		})
	end,
}
