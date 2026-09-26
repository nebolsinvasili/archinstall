return {
  "acidsugarx/babel.nvim",
  version = "*", -- recomended for the latest tag, not main
  opts = {
    target = "ru",  -- target language
  },
  keys = {
    { "<leader>tr", mode = "v", desc = "Translate selection" },
    { "<leader>tw", desc = "Translate word" },
  },
  config = function()
		require("babel").setup({
			source = "auto",        -- source language (auto-detect)
			target = "ru",          -- target language
			provider = "google",    -- translation provider: "google", "deepl"
			display = "float",      -- "float" or "picker"
			picker = "auto",        -- "auto", "telescope", "fzf", "snacks", "mini"
			float = {
				border = "rounded",
				max_width = 80,
				max_height = 20,
			},
			keymaps = {
				translate = "<leader>tr",
				translate_word = "<leader>tw",
			},
			-- DeepL provider settings (optional)
			deepl = {
				api_key = nil,        -- or use DEEPL_API_KEY env variable
				pro = nil,            -- nil = auto-detect, true = Pro, false = Free
				formality = "default", -- "default", "more", "less", "prefer_more", "prefer_less"
			},
		})
	end,
}
