vim.lsp.config("lua_ls", {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = {
		".luarc.json",
		".luarc.jsonp",
		".luacheckrc",
	},
})

vim.lsp.enable("lua_ls")

vim.lsp.config("matlab_ls", {
	settings = {
		MATLAB = {
			installPath = "/home/ale/MATLAB/R2026a",
			indexWorkspace = true,
			matlabConnectionTiming = "onStart",
		},
	},
})

vim.lsp.enable("matlab_ls")
