require("config.lazy")
require("config.lsp")
require("config.mappings")

vim.g.mapleader = " "
vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)
vim.keymap.set("n", "<leader>w", vim.cmd.w)
vim.opt.number = true

local builtin = require("telescope.builtin")
--vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find_files no_ignore=true hidden=true' })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })

-- Add this to your keymaps section
vim.keymap.set("n", "<leader>pf", function()
	local ok = pcall(require("telescope.builtin").git_files)
	if not ok then
		require("telescope.builtin").find_files()
	end
end, { desc = "Project Files (Git or Local)" })

require("nvim-treesitter").setup({
	-- Directory to install parsers and queries to (prepended to `runtimepath` to have priority)
	install_dir = vim.fn.stdpath("data") .. "/site",
})

require("nvim-treesitter").install({ "lua", "c", "python", "rust", "javascript", "zig" })

vim.opt.termguicolors = true

require("mason-lspconfig").setup({
	automatic_enable = {
		"lua_ls",
		"vimls",
	},
})

vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>")
vim.wo.number = true
