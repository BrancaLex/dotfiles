return {
    "mason-org/mason.nvim",
    opts = {

	ensure_installed = {
		'pyright',
		'lua_ls',
		'c',
		'clangd',
		'clang-format',
		'codelldb'
	},

        ui = {
            icons = {
                package_installed = "✓",
                package_pending = "➜",
                package_uninstalled = "✗"
            }
        }
    },

    "neovim/nvim-lspconfig"
}
