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
--   light -> Catppuccin latte ; dark -> Atom One Dark
function M.spec()
  if M.mode() == "light" then
    return "light", "catppuccin-latte"
  end
  return "dark", "onedark"
end

-- Applica background + colorscheme a runtime (chiamata su SIGUSR1)
function M.apply()
  local bg, scheme = M.spec()
  vim.o.background = bg
  pcall(vim.cmd.colorscheme, scheme)
end

return M
