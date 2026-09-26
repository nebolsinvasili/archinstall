-- ==========================================================================
-- 2. COMPLETION ENGINE (Cmp)
-- ==========================================================================
return {
	"hrsh7th/nvim-cmp",
	version = false,
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-nvim-lsp", -- LSP source for nvim-cmp
		"hrsh7th/cmp-buffer", -- Buffer source for nvim-cmp
		"hrsh7th/cmp-path", -- Path source for nvim-cmp
		"hrsh7th/cmp-cmdline", -- Cmdline source for nvim-cmp
		"hrsh7th/cmp-nvim-lua", -- Neovim Lua API source
		"saadparwaiz1/cmp_luasnip", -- LuaSnip source
		"notomo/cmp-neosnippet", -- NeoSnippet source
		-- "zbirenbaum/copilot-cmp",        -- Copilot source (Optional)
		-- "tzachar/cmp-tabnine",           -- Tabnine source (Optional)
	},

	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")

		-- 1. ICONS (Custom Set)
		-- ----------------------------------------------------------------------
		local kind_icons = {
			Array = "",
			Boolean = "",
			Class = "",
			Color = "",
			Constant = "",
			Field = "",
			File = "",
			Folder = "󰉋",
			Function = "",
			Key = "",
			Keyword = "",
			Method = "",
			Module = " ",
			Namespace = "",
			Null = "󰟢",
			Object = "",
			Operator = "",
			Package = "",
			Property = "",
			Reference = "",
			String = "",
			Text = "",
			TypeParameter = "",
			Unit = "",
			Value = "",
			Variable = "",
			Copilot = "",
			Constructor = "",
			Interface = "",
			Enum = "",
			Snippet = "",
			EnumMember = "",
			Struct = "פּ",
			Event = "",
			Table = " ",
			Tag = " ",
			Number = "",
			Calendar = " ",
			Watch = "",
		}

		-- 2. SETUP
		-- ----------------------------------------------------------------------
		cmp.setup({
			-- Snippet Expansion Logic
			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},

			-- UI Customization
			window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			},

			-- Key Mappings
			mapping = cmp.mapping.preset.insert(require("config.keymaps").cmp(cmp, luasnip)),

			-- Formatting (Icons + Text)
			formatting = {
				fields = { "abbr", "kind", "menu" },
				format = function(_, vim_item)
					-- Concatenate icon with kind name
					vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)
					return vim_item
				end,
			},

			-- Sources (Order determines priority)
			sources = {
				-- { name = "copilot"   , group_index = 2 },
				-- { name = "cmp_tabnine", group_index = 2 },
				{ name = "nvim_lsp", group_index = 2 },
				{ name = "luasnip", group_index = 2 },
				{ name = "buffer", group_index = 2 }, -- Text in the current Buffer
				{ name = "path", group_index = 2 },
			},

			-- Experimental Features
			experimental = {
				ghost_text = true,
				native_menu = false,
			},
		})
	end,
}
