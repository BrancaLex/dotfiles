--return {
 --   'nvim-telescope/telescope.nvim', version = '0.2.1',
   -- dependencies = {
     --   'nvim-lua/plenary.nvim',
       -- -- optional but recommended
        --{ 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
   -- }

--}--


return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.x',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('telescope').setup({
      defaults = {
        -- Your default configs here
      },
      pickers = {
        -- This is the part you need to fix find_files
        find_files = {
          hidden = true,      -- Show hidden files (e.g. .zshrc)
          no_ignore = true,   -- DON'T skip files in .gitignore
          follow = true,      -- Follow symlinks
        },
      },
    })

    -- Your Keymaps (Example)
    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
    vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
  end
}
