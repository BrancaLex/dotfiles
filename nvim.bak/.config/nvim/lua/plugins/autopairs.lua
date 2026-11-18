return {
  "windwp/nvim-autopairs",
  event = "InsertEnter", -- Si carica appena inizi a scrivere
  config = function()
    local autopairs = require("nvim-autopairs")

    autopairs.setup({
      check_ts = true, -- Abilita Treesitter per essere più intelligente
      ts_config = {
        lua = { "string" }, -- Non aggiungere coppie nelle stringhe Lua
        javascript = { "template_string" },
      },
    })

   -- Se vuoi che funzioni insieme a nvim-cmp (consigliato)
    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    local cmp = require("cmp")
    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
  end,
}
