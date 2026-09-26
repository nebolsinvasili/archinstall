-- ==========================================================================
-- COLORSCHEME (Kanagawa)
-- ==========================================================================
-- Applies the theme selected in lua/config/user_env.lua (theme = "kanagawa").
return {
	"rebelot/kanagawa.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		local ok, env = pcall(require, "config.user_env")
		local theme = ok and env.config.theme or "kanagawa"

		if theme == "kanagawa" then
			vim.cmd.colorscheme("kanagawa")
		end
	end,
}