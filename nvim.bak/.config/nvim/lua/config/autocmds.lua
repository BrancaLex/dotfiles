-- SIGUSR1: reload pywal colorscheme + sync background nelle istanze aperte
local signal = vim.uv.new_signal()
signal:start("sigusr1", function()
    vim.schedule(function()
        pcall(vim.cmd, "colorscheme pywal")
        local ok, lines = pcall(vim.fn.readfile, vim.fn.expand("~/.cache/theme_mode"))
        if ok and lines[1] then
            vim.o.background = lines[1]
        end
    end)
end)
