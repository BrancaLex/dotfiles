return {
  "lervag/vimtex",
  -- tag = "v2.15", -- uncomment to pin to a specific release
  init = function()
    -- VimTeX configuration goes here, e.g.
    vim.g.vimtex_view_method = "zathura"
    vim.g.vimtex_compiler_enabled = 1
    vim.g.vimtex_view_automatic = 1
  end
}
