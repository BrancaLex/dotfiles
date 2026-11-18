-- Parità di tema con ghostty.
--
-- ghostty/.config/ghostty/config dichiara `theme = dark:Atom One Dark,light:Catppuccin Latte`.
-- Qui vengono installati i due colorscheme corrispondenti; la scelta fra i due NON è
-- cablata in questo file ma delegata a `config.theme`, che legge ~/.cache/theme_mode
-- (scritto da apply_theme.sh) — la stessa sorgente di verità che pilota ghostty via D-Bus.
--
-- NB: ghostty non partecipa alla pipeline pywal (usa temi fissi), quindi "seguire il
-- terminale" significa parità con questi due temi, non agganciarsi a ~/.cache/wal/.
return {
  -- dark → equivalente di "Atom One Dark" (stessa palette di accento:
  -- #e06c75 #98c379 #e5c07b #61afef #c678dd #56b6c2)
  {
    "navarasu/onedark.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      style = "dark",
      -- Lo sfondo lo mette ghostty (background-opacity = 0.50). I gruppi residui
      -- introdotti dagli extra di LazyVim sono azzerati in config/autocmds.lua.
      transparent = true,
    },
  },

  -- light → equivalente di "Catppuccin Latte"
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
      background = { light = "latte", dark = "mocha" },
      transparent_background = true,
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      -- Funzione, non stringa: la decisione dark/light è a runtime.
      colorscheme = function()
        require("config.theme").apply()
      end,
    },
  },
}
