return {
	"lervag/vimtex",
	lazy = true, -- VimTeX needs to be loaded at startup for .tex files
	init = function()
		-- Use Zathura as the PDF viewer
		vim.g.vimtex_view_method = "zathura"

		-- Ensure latexmk is the compiler (standard)
		vim.g.vimtex_compiler_method = "latexmk"

		-- Open viewer automatically after successful compilation
		vim.g.vimtex_view_automatic = 1

		-- Don't open quickfix window automatically (manual with <leader>le)
		vim.g.vimtex_quickfix_mode = 0

		-- Clean auxiliary files on exit
		vim.g.vimtex_compiler_clean_on_terminate = 1
	end,
}
