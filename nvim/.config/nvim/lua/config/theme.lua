-- Ponte fra il tema del terminale e Neovim.
--
-- apply_theme.sh scrive ~/.cache/theme_mode e commuta `color-scheme` su D-Bus; ghostty
-- ascolta D-Bus e ruota fra `Atom One Dark` e `Catppuccin Latte`, noi leggiamo il file e
-- carichiamo il colorscheme equivalente (lua/plugins/colorscheme.lua). Lo sfondo lo mette
-- ghostty (`background-opacity = 0.50`): Neovim resta trasparente.
--
-- M.setup() va chiamata da lua/config/options.lua, non da autocmds.lua: LazyVim carica
-- `options` prima dei plugin e `autocmds` solo su VeryLazy, cioè DOPO che il colorscheme
-- d'avvio è già stato applicato — da lì l'autocmd ColorScheme perderebbe il primo giro.
local M = {}

-- Legge la preferenza dark/light scritta da apply_theme.sh (default: dark)
function M.mode()
  local ok, lines = pcall(vim.fn.readfile, vim.fn.expand("~/.cache/theme_mode"))
  if ok and lines[1] == "light" then
    return "light"
  end
  return "dark"
end

-- Mappa mode -> background, colorscheme
--   light -> Catppuccin Latte ; dark -> Atom One Dark (onedark.nvim)
function M.spec()
  if M.mode() == "light" then
    return "light", "catppuccin-latte"
  end
  return "dark", "onedark"
end

-- Gruppi il cui sfondo va azzerato per lasciar passare la traslucenza di ghostty.
-- Le opzioni `transparent` di onedark/catppuccin coprono solo i gruppi che quei plugin
-- definiscono: tutto ciò che introducono gli extra di LazyVim (snacks, mini-files, noice,
-- bufferline, telescope, ...) resterebbe opaco.
M.transparent_groups = {
  -- core
  "Normal",
  "NormalNC",
  "NormalFloat",
  "FloatBorder",
  "FloatTitle",
  "SignColumn",
  "LineNr",
  "CursorLineNr",
  "EndOfBuffer",
  "FoldColumn",
  "MsgArea",
  "WinBar",
  "WinBarNC",
  -- statusline / tabline
  "StatusLine",
  "StatusLineNC",
  "TabLine",
  "TabLineFill",
  "TabLineSel",
  -- popup
  "Pmenu",
  "PmenuSbar",
  "PmenuThumb",
  "NormalSB",
  -- plugin
  "TelescopeNormal",
  "TelescopeBorder",
  "SnacksNormal",
  "SnacksNormalNC",
  "SnacksDashboardNormal",
  "MiniFilesNormal",
  "MiniFilesBorder",
  "NoiceCmdlinePopup",
  "BufferLineFill",
  "WhichKeyNormal",
  "LazyNormal",
  "MasonNormal",
  "TroubleNormal",
}

-- Toglie lo sfondo preservando fg, stili e link.
function M.transparent()
  for _, name in ipairs(M.transparent_groups) do
    pcall(function()
      -- Rileggere il gruppo e togliere solo `bg`: passare una tabella nuova
      -- appiattirebbe anche fg, stili e link.
      local hl = vim.api.nvim_get_hl(0, { name = name })
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end)
  end
end

-- Applica background + colorscheme a runtime (all'avvio e su SIGUSR1).
-- L'ordine conta: `background` va impostato prima, altrimenti un colorscheme che ne
-- deriva le varianti (catppuccin) sceglie il flavour sbagliato.
-- NB: la trasparenza NON si riapplica qui — ci pensa l'autocmd ColorScheme, che scatta
-- come effetto di questa chiamata e sopravvive anche a un `:colorscheme` manuale.
function M.apply()
  local bg, scheme = M.spec()
  vim.o.background = bg
  if pcall(vim.cmd.colorscheme, scheme) then
    return
  end
  -- Fallback esplicito: meglio catppuccin del colorscheme `default` di Neovim, e con
  -- un avviso — un fallimento silenzioso qui è indistinguibile da un tema mal reso.
  vim.notify(
    ("config.theme: colorscheme %q non disponibile, fallback su catppuccin"):format(scheme),
    vim.log.levels.WARN
  )
  pcall(vim.cmd.colorscheme, "catppuccin")
end

function M.setup()
  local group = vim.api.nvim_create_augroup("theme_terminal", { clear = true })

  -- Ogni `:colorscheme` ricostruisce da zero la tabella degli highlight: la trasparenza
  -- va riapplicata a ogni cambio, non una tantum, altrimenti sparisce al primo toggle.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    pattern = "*",
    callback = M.transparent,
  })

  -- SIGUSR1: segui il tema dark/light inviato da apply_theme.sh (`pkill -SIGUSR1 nvim`).
  -- apply() cambia colorscheme → scatta ColorScheme → la trasparenza si ridipinge da sé.
  --
  -- vim.schedule è obbligatorio: il callback di un segnale gira in *fast event context*,
  -- dove nvim_get_hl/nvim_set_hl sollevano E5560. Il `:colorscheme` passa comunque,
  -- quindi il sintomo è subdolo — tema commutato ma sfondo tornato opaco, con l'errore
  -- ingoiato dal pcall in M.transparent().
  vim.api.nvim_create_autocmd("Signal", {
    group = group,
    pattern = "SIGUSR1",
    callback = function()
      vim.schedule(M.apply)
    end,
  })
end

return M
