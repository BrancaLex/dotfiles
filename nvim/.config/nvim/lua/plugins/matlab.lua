-- MATLAB in Neovim: LSP (MathWorks matlab-language-server) + REPL in uno split tmux.
--
-- Pensato per un server remoto via SSH con MATLAB installato nativamente.
-- Il language server non analizza il codice da solo: avvia un'istanza MATLAB vera,
-- quindi richiede `MATLAB.installPath` e una licenza valida *su quella macchina*.
-- Sul laptop `matlab` e' il wrapper distrobox (~/.local/bin/matlab): li' non c'e'
-- alcuna installazione nativa, quindi tutto questo resta inerte.
--
-- Risoluzione di installPath, in ordine:
--   1. $MATLAB_ROOT  (override esplicito, es. export MATLAB_ROOT=/usr/local/MATLAB/R2026a)
--   2. realpath di `matlab` nel PATH, tolto il suffisso /bin/matlab
-- Il candidato e' accettato solo se contiene bin/glnxa64 (layout reale di un'installazione).

local function matlab_root()
  local function valid(root)
    return root and root ~= "" and (vim.uv.fs_stat(root .. "/bin/glnxa64") ~= nil)
  end

  local env = vim.env.MATLAB_ROOT
  if valid(env) then
    return env
  end

  local exe = vim.fn.exepath("matlab")
  if exe ~= "" then
    local real = vim.uv.fs_realpath(exe) or exe
    local root = real:match("^(.*)/bin/matlab$")
    if valid(root) then
      return root
    end
  end
  return nil
end

local root = matlab_root()

return {
  -- LSP -----------------------------------------------------------------------
  -- Registrato solo se MATLAB e' davvero presente: altrove (laptop) il server
  -- non verrebbe avviato correttamente e produrrebbe solo errori a ogni apertura di .m
  {
    "neovim/nvim-lspconfig",
    optional = true,
    opts = function(_, opts)
      if not root then
        return
      end
      opts.servers = opts.servers or {}
      opts.servers.matlab_ls = {
        settings = {
          MATLAB = {
            installPath = root,
            indexWorkspace = true,
            matlabConnectionTiming = "onStart",
            telemetry = false,
          },
        },
      }
    end,
  },

  -- Pacchetto Mason (richiede node/npm sul server: la build e' `npm install`) -----
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      if root then
        opts.ensure_installed = opts.ensure_installed or {}
        table.insert(opts.ensure_installed, "matlab-language-server")
      end
    end,
  },

  -- REPL / celle / debugger via tmux -------------------------------------------
  -- Richiede di lanciare nvim *dentro* tmux (sessione persistente anche se cade l'SSH).
  {
    "idossha/matlab.nvim",
    ft = "matlab",
    enabled = root ~= nil,
    config = function()
      require("matlab").setup({
        executable = root .. "/bin/matlab",
        tmux_pane_direction = "right",
        panel_size = 40,
        panel_size_type = "percentage",
        default_mappings = true, -- <Leader>m* ; vedi :MatlabKeymaps
        minimal_notifications = true,
      })
    end,
  },
}
