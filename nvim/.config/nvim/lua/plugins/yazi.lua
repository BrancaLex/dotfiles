return {
  "mikavilpas/yazi.nvim",
  event = "VeryLazy",
  keys = {
    -- Open yazi in the current working directory
    { "<leader>y", "<cmd>Yazi<CR>", desc = "Open yazi" },
    -- Open yazi in the directory of the current file
    { "<leader>Y", "<cmd>Yazi cwd<CR>", desc = "Open yazi in current file's dir" },
  },
  opts = {
    open_for_directories = true,
  },
}
