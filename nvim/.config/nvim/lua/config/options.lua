-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Tema e sfondo seguono il terminale (ghostty). Il colorscheme è scelto dall'opzione
-- `colorscheme` di LazyVim in lua/plugins/colorscheme.lua, che chiama
-- require("config.theme").apply(); qui registriamo le autocmd di supporto
-- (ColorScheme → trasparenza, SIGUSR1 → ricarica il tema).
-- Va fatto da options.lua, non da autocmds.lua: LazyVim carica questo file prima dei
-- plugin, autocmds.lua solo su VeryLazy — troppo tardi per il colorscheme d'avvio.
require("config.theme").setup()

-- Forza Neovim ad usare il provider Python isolato che abbiamo creato in Docker
vim.g.python3_host_prog = "/opt/nvim-venv/bin/python3"
vim.opt.termguicolors = true
vim.opt.clipboard = "wl-copy" -- Usa la clipboard di sistema (xclip/wl-copy) per + e *
vim.opt.shell = "/usr/bin/fish" -- Fish shell come default

-- Clipboard via OSC 52 per sessioni senza display server (devcontainer, SSH).
-- Dentro il container non esistono $DISPLAY/$WAYLAND_DISPLAY, quindi Neovim non trova
-- alcun provider (has('clipboard')==0) e xclip/wl-copy non raggiungono la clipboard host.
-- OSC 52 delega la scrittura al terminale (che gira sull'host) via escape sequence.
-- Guardato: sull'host GUI (display presente) NON si attiva → resta il provider nativo
-- wl-clipboard/xclip. Requisiti: terminale con supporto OSC 52 (kitty, wezterm, foot,
-- alacritty>=0.13, ...); dentro tmux serve `set -g set-clipboard on`.

vim.opt.expandtab = true --
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
