return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night", -- The darkest variant
      transparent = true, -- This will use your terminal's background
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}
