return {
  "folke/tokyonight.nvim",
  config = function()
    require("tokyonight").setup({
      style = "night", 
      transparent = true, -- Attiva il nero assoluto del terminale
    })
    vim.cmd.colorscheme "tokyonight"
  end
}
