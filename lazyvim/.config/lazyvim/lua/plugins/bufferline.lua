return {
  "akinsho/bufferline.nvim",
  optional = true,
  opts = function(_, opts)
    -- LazyVim pins opts.highlights to catppuccin's palette (distro colorscheme.lua),
    -- evaluated once at startup. That closure later paints stale catppuccin colors
    -- over onedark (dark mode) and stale mocha over catppuccin-latte (light mode) —
    -- producing a dark tabline over a light editor. Clearing the pin lets bufferline
    -- auto-derive its highlights from the ACTIVE scheme and stay in sync via its own
    -- ColorScheme autocmd — correct in both modes and on every theme toggle.
    opts.highlights = nil
  end,
}
