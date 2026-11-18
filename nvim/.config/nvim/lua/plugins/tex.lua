-- LaTeX workflow ported from benbrastmckie/nvim, adapted to LazyVim.
--
-- LazyVim's `lazyvim.plugins.extras.lang.tex` already provides VimTeX (lazy=false,
-- required for inverse search), the texlab LSP and latex/bibtex treesitter parsers.
-- These specs OVERRIDE / EXTEND that baseline rather than redeclaring it:
--   * VimTeX: latexmk -> build/ dir, zathura viewer, quickfix filters, default maps off
--   * texlab: build-on-save, chktex off
--   * LuaSnip (from the coding.luasnip extra): load the snipmate `snippets/tex.snippets`
--   * blink.cmp: citation-aware completion via cmp-vimtex + the `omni` source, with
--     lsp/path/buffer gated off inside \cite/\ref/... contexts to avoid duplicates
--
-- The <leader>l (latex) and <leader>T (templates) which-key menus, PdfAnnots,
-- bibexport and the tex omnifunc live buffer-local in after/ftplugin/tex.lua.

-- Shared helper: true when the cursor sits inside a \ref/\cref/\eqref/\autoref{...}.
local function in_ref_context()
  if vim.bo.filetype ~= "tex" then
    return false
  end
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = vim.api.nvim_get_current_line():sub(1, col)
  return before:match("\\ref{[^}]*$")
    or before:match("\\[Cc]ref{[^}]*$")
    or before:match("\\eqref{[^}]*$")
    or before:match("\\autoref{[^}]*$")
end

-- Also true inside \cite/\citep/\citet{...} (where cmp-vimtex should be the sole source).
local function in_cite_or_ref_context()
  if vim.bo.filetype ~= "tex" then
    return false
  end
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = vim.api.nvim_get_current_line():sub(1, col)
  return in_ref_context()
    or before:match("\\cite[%w]*{[^}]*$")
    or before:match("\\citep?[%w]*{[^}]*$")
    or before:match("\\citet?[%w]*{[^}]*$")
end

return {
  -- VimTeX: compiler / viewer / build-dir settings (init runs before the plugin
  -- loads and merges with the extra's own `config`; keep the extra's lazy=false).
  {
    "lervag/vimtex",
    init = function()
      -- Viewer: zathura_simple, non zathura. Il backend `zathura` definisce
      -- _exists() -> xdo_exists(), che richiede xdotool (view/_template.vim);
      -- senza xdotool — e su Wayland è comunque inservibile — _exists() è sempre
      -- falso e VimTeX riavvia il viewer a ogni VimtexView. `zathura_simple`
      -- omette _exists() e delega la deduplicazione a D-Bus.
      vim.g.vimtex_view_method = "zathura_simple"
      vim.g.vimtex_context_pdf_viewer = "okular"

      -- Indentation (let the editor/latexindent own it, not VimTeX)
      vim.g.vimtex_indent_enabled = false
      vim.g.tex_indent_items = false
      vim.g.tex_indent_brace = false

      -- Compiler: latexmk, all artifacts into build/
      vim.g.vimtex_compiler_method = "latexmk"
      -- NB: `build_dir` non esiste più in VimTeX (v2.17): le sole chiavi onorate
      -- sono out_dir/aux_dir -> -outdir/-auxdir. _template#new() fa extend()
      -- senza validare le chiavi, quindi una chiave obsoleta sopravviverebbe muta.
      vim.g.vimtex_compiler_latexmk = {
        out_dir = "build",
        aux_dir = "build",
        options = {
          "-interaction=nonstopmode",
          "-file-line-error",
          "-synctex=1",
        },
      }

      -- Quickfix
      vim.g.vimtex_quickfix_mode = 0
      vim.g.vimtex_quickfix_ignore_filters = {
        "Underfull",
        "Overfull",
        "specifier changed to",
        "Token not allowed in a PDF string",
        "Package hyperref Warning",
      }
      vim.g.vimtex_log_ignore = {
        "Underfull",
        "Overfull",
        "specifier changed to",
        "Token not allowed in a PDF string",
      }

      -- Default mappings disabled: the workflow uses the <leader>l which-key menu.
      vim.g.vimtex_mappings_enabled = false
      vim.g.tex_flavor = "latex"
    end,
  },

  -- texlab tuning (LazyVim deep-merges into the extra's texlab server config).
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        texlab = {
          settings = {
            texlab = {
              -- Build-on-save DISATTIVATO: la compilazione appartiene a VimTeX
              -- (`latexmk -pvc`, che ricompila già a ogni salvataggio). texlab
              -- risolve autonomamente il root file e lancerebbe un SECONDO latexmk
              -- che, ereditando $out_dir dal .latexmkrc di progetto, scrive negli
              -- stessi main.aux/main.bcf/main.bbl del -pvc in corso. La sovrapposizione
              -- lascia il .bcf troncato a metà scrittura; biber aborta con
              --   ERROR - main.bcf is malformed, last biblatex run probably failed
              -- cancellando il .bbl. Risultato: citazioni irrisolte e un PDF di
              -- aspetto plausibile emesso comunque dalla passata successiva.
              build = { onSave = false },
              chktex = {
                onEdit = false,
                onOpenAndSave = false,
              },
              diagnosticsDelay = 300,
              -- Inlay hints DISATTIVATI (texlab li abilita entrambi di default).
              -- texlab li emette come virtual text *inline*: Neovim deve allora
              -- mappare le colonne del buffer su celle di schermo occupate da testo
              -- che nel buffer non esiste, e che con wrap/linebreak attivi
              -- (after/ftplugin/tex.lua) entra pure nel calcolo delle andate a capo.
              -- Il cursore finisce disegnato fuori posto, l'highlight sembra colpire
              -- il carattere sbagliato, `x` sembra cancellare più avanti e la
              -- selezione visual ingloba testo inesistente.
              --
              -- Servono ENTRAMBE le chiavi: coprono insiemi disgiunti. Misurato su
              -- Capitolo 2 via textDocument/inlayHint, 21 hint di default ->
              --   labelReferences=false   -> 11 residui (quelli sui \label)
              --   labelDefinitions=false  -> 10 residui (quelli sui \ref)
              --   entrambe                ->  0
              -- NB: il canale deve essere `settings` (pull workspace/configuration,
              -- sezione "texlab"); via `init_options` texlab le ignora del tutto.
              inlayHints = {
                labelReferences = false,
                labelDefinitions = false,
              },
            },
          },
        },
      },
    },
  },

  -- LuaSnip (added by the coding.luasnip extra): enable autosnippets and load the
  -- snipmate library from <config>/snippets (i.e. ~/.config/lazyvim/snippets).
  {
    "L3MON4D3/LuaSnip",
    opts = function(_, opts)
      opts = opts or {}
      opts.enable_autosnippets = true
      require("luasnip.loaders.from_snipmate").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/snippets" },
      })
      return opts
    end,
  },

  -- blink.cmp: citation/reference-aware completion for tex.
  {
    "saghen/blink.cmp",
    dependencies = {
      { "saghen/blink.compat", version = "2.*", opts = { impersonate_nvim_cmp = true } },
      {
        "micangl/cmp-vimtex",
        config = function()
          require("cmp_vimtex").setup({
            additional_information = {
              info_in_menu = true,
              info_in_window = true,
              info_max_length = 60,
              match_against_info = true,
              symbols_in_menu = true,
            },
            bibtex_parser = { enabled = true },
            search = {
              browser = "xdg-open",
              default = "google_scholar",
              search_engines = {
                google_scholar = {
                  name = "Google Scholar",
                  get_url = function(query)
                    return string.format("https://scholar.google.com/scholar?hl=en&q=%s", query)
                  end,
                },
              },
            },
          })
        end,
      },
    },
    opts = {
      sources = {
        per_filetype = {
          -- Snippets prioritized; `omni` routes VimTeX's completion (citations/refs).
          tex = { "lsp", "snippets", "omni", "path", "buffer" },
        },
        providers = {
          -- Gate the generic sources off inside \ref/\cite so VimTeX is the only
          -- provider there (avoids duplicated / noisy candidates).
          lsp = {
            enabled = function()
              return not in_ref_context()
            end,
          },
          path = {
            enabled = function()
              return not in_cite_or_ref_context()
            end,
          },
          buffer = {
            enabled = function()
              return not in_cite_or_ref_context()
            end,
          },
          omni = {
            name = "omni",
            enabled = function()
              return vim.bo.filetype == "tex" and vim.bo.omnifunc ~= ""
            end,
            async = true,
            timeout_ms = 5000,
            max_items = 50,
            min_keyword_length = 0,
            score_offset = 100,
          },
        },
      },
    },
  },
}
