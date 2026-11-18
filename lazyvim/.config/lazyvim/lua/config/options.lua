-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Il colorscheme che segue il tema GTK (dark/light) è applicato via
-- l'opzione `colorscheme` di LazyVim in lua/plugins/colorscheme.lua
-- (require("config.theme").apply()), con hot-reload su SIGUSR1 in autocmds.lua.

-- Forza Neovim ad usare il provider Python isolato che abbiamo creato in Docker
vim.g.python3_host_prog = "/opt/nvim-venv/bin/python3"
vim.opt.termguicolors = true
