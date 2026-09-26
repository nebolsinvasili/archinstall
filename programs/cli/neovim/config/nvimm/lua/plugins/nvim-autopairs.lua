-- ==========================================================================
-- 4. UTILS (Autopairs)
-- ==========================================================================
return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	opts = {},

	config = function(_, opts)
		local np = require("nvim-autopairs")
		np.setup(opts)

		-- Connect autopairs to cmp for correct parens handling
		local cmp_autopairs = require("nvim-autopairs.completion.cmp")
		require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
	end,
}
