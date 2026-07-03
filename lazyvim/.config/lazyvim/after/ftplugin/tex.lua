-- LaTeX buffer-local setup, ported from benbrastmckie/nvim and adapted to LazyVim.
--
-- Adaptations vs upstream:
--   * notifications: neotex.util.notifications -> a small vim.notify wrapper
--   * template paths: hardcoded ~/.config/nvim -> vim.fn.stdpath("config")
--     (resolves to ~/.config/lazyvim under NVIM_APPNAME=lazyvim)
--   * surround: nvim-surround.buffer_setup -> mini.surround buffer-local config
--     (LazyVim ships mini.surround; invoke with `gsa <char>`)
--   * options scoped buffer-local (conceallevel, synmaxcol); omnifunc set here
--   * template maps rewired to files that exist upstream (no Glossary.tex /
--     MultipleAnswer.tex; glossary is lowercase)

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "LaTeX" })
end

local templates = vim.fn.stdpath("config") .. "/templates"

-- Full-line syntax highlighting and visible backticks for LaTeX (buffer-local).
vim.opt_local.synmaxcol = 0 -- no limit
vim.opt_local.conceallevel = 0 -- keep `` visible

-- VimTeX omni-completion (consumed by blink's `omni` source, see lua/plugins/tex.lua).
vim.bo.omnifunc = "vimtex#complete#omnifunc"

-- LaTeX surrounds via mini.surround (buffer-local). `gsa e` prompts for an env, etc.
vim.b.minisurround_config = {
  custom_surroundings = {
    ["e"] = {
      output = function()
        local env = vim.fn.input("Environment: ")
        return { left = "\\begin{" .. env .. "}", right = "\\end{" .. env .. "}" }
      end,
    },
    ["Q"] = { output = { left = "``", right = "''" } },
    ["q"] = { output = { left = "`", right = "'" } },
    ["b"] = { output = { left = "\\textbf{", right = "}" } },
    ["i"] = { output = { left = "\\textit{", right = "}" } },
    ["t"] = { output = { left = "\\texttt{", right = "}" } },
    ["$"] = { output = { left = "$", right = "$" } },
  },
}

-- Export annotations from the compiled PDF to markdown (needs `pdfannots`).
function PdfAnnots()
  local ok, pdf = pcall(vim.api.nvim_eval, "vimtex#context#get().handler.get_actions().entry.file")
  if not ok then
    notify("No file found", vim.log.levels.WARN)
    return
  end

  local cwd = vim.fn.getcwd()
  vim.fn.chdir(vim.b.vimtex.root)

  if vim.fn.isdirectory("Annotations") == 0 then
    vim.fn.mkdir("Annotations")
  end

  local md = vim.fn.printf("Annotations/%s.md", vim.fn.fnamemodify(pdf, ":t:r"))
  vim.fn.system(string.format('pdfannots -o "%s" "%s"', md, pdf))
  vim.cmd.edit(vim.fn.fnameescape(md))

  vim.fn.chdir(cwd)
end

-- Async bibexport from build/<file>.aux (needs `bibexport`).
local function run_bibexport()
  local filedir = vim.fn.expand("%:p:h")
  local filename = vim.fn.expand("%:t:r")
  local output_bib = filename .. ".bib"
  local aux_file = "build/" .. filename .. ".aux"

  local aux_path = filedir .. "/" .. aux_file
  if vim.fn.filereadable(aux_path) == 0 then
    notify("Bibexport failed: " .. aux_file .. " not found", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format('bibexport -o "%s" "%s"', output_bib, aux_file)
  local stderr_lines = {}

  vim.fn.jobstart(cmd, {
    cwd = filedir,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if exit_code == 0 then
          notify("Bibexport complete: " .. filedir .. "/" .. output_bib, vim.log.levels.INFO)
        else
          local msg = table.concat(stderr_lines, "\n")
          if msg ~= "" then
            local lines = {}
            for line in msg:gmatch("[^\n]+") do
              table.insert(lines, line)
            end
            local truncated = {}
            for i = math.max(1, #lines - 4), #lines do
              table.insert(truncated, lines[i])
            end
            notify("Bibexport failed: " .. table.concat(truncated, "; "), vim.log.levels.ERROR)
          else
            notify("Bibexport failed (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
          end
        end
      end)
    end,
  })
end

-- Copy a template directory (report/springer) into the cwd.
local function copy_template_dir(name)
  local src = templates .. "/" .. name
  local dst = vim.fn.getcwd()
  vim.fn.system("cp -r " .. vim.fn.shellescape(src) .. " " .. vim.fn.shellescape(dst))
  notify("Template '" .. name .. "' copied to " .. dst, vim.log.levels.INFO)
end

-- Buffer-local which-key menus.
local ok_wk, wk = pcall(require, "which-key")
if ok_wk then
  wk.add({
    { "<leader>l", group = "latex", icon = "󰙩", buffer = 0 },
    { "<leader>la", "<cmd>lua PdfAnnots()<CR>", desc = "annotate", icon = "󰏪", buffer = 0 },
    { "<leader>lb", function() run_bibexport() end, desc = "bib export", icon = "󰈝", buffer = 0 },
    { "<leader>lc", "<cmd>VimtexCompile<CR>", desc = "compile", icon = "󰖷", buffer = 0 },
    { "<leader>ld", "<cmd>terminal LATEXMK_DRAFT_MODE=1 latexmk -pdf -e '$draft_mode=1' %:p<CR>", desc = "draft mode", icon = "󰌶", buffer = 0 },
    { "<leader>le", "<cmd>VimtexErrors<CR>", desc = "errors", icon = "󰅚", buffer = 0 },
    { "<leader>lf", "<cmd>terminal latexmk -pdf %:p<CR>", desc = "final build", icon = "󰸞", buffer = 0 },
    { "<leader>lg", "<cmd>exe 'edit ' . stdpath('config') . '/templates/glossary.tex'<CR>", desc = "glossary", icon = "󰈚", buffer = 0 },
    { "<leader>lh", "<cmd>terminal latexindent -w %:p:r.tex<CR>", desc = "format", icon = "󰉣", buffer = 0 },
    { "<leader>li", "<cmd>VimtexTocOpen<CR>", desc = "index", icon = "󰋽", buffer = 0 },
    { "<leader>lk", "<cmd>VimtexClean<CR>", desc = "kill aux", icon = "󰩺", buffer = 0 },
    { "<leader>lm", "<plug>(vimtex-context-menu)", desc = "menu", icon = "󰍉", buffer = 0 },
    { "<leader>lv", "<cmd>VimtexView<CR>", desc = "view", icon = "󰛓", buffer = 0 },
    { "<leader>lw", "<cmd>VimtexCountWords!<CR>", desc = "word count", icon = "󰆿", buffer = 0 },
    { "<leader>lx", "<cmd>VimtexClearCache All<CR>", desc = "clear cache", icon = "󰃢", buffer = 0 },
    {
      "<leader>ls",
      function()
        local vimtex = vim.b.vimtex
        if vimtex and vim.fn.expand("%:p") == vimtex.tex then
          notify("Already on main file")
        else
          vim.cmd("VimtexToggleMain")
        end
      end,
      desc = "subfile toggle",
      icon = "󰔏",
      buffer = 0,
    },
  })

  wk.add({
    { "<leader>T", group = "templates", icon = "󰈭", buffer = 0 },
    { "<leader>Ta", "<cmd>exe 'read ' . stdpath('config') . '/templates/article.tex'<CR>", desc = "article.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tb", "<cmd>exe 'read ' . stdpath('config') . '/templates/beamer_slides.tex'<CR>", desc = "beamer_slides.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tg", "<cmd>exe 'read ' . stdpath('config') . '/templates/glossary.tex'<CR>", desc = "glossary.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Th", "<cmd>exe 'read ' . stdpath('config') . '/templates/handout.tex'<CR>", desc = "handout.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tl", "<cmd>exe 'read ' . stdpath('config') . '/templates/letter.tex'<CR>", desc = "letter.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tk", "<cmd>exe 'read ' . stdpath('config') . '/templates/arc_tikz.tex'<CR>", desc = "arc_tikz.tex", icon = "󰈙", buffer = 0 },
    { "<leader>Tr", function() copy_template_dir("report") end, desc = "copy report/ dir", icon = "󰉖", buffer = 0 },
    { "<leader>Ts", function() copy_template_dir("springer") end, desc = "copy springer/ dir", icon = "󰉖", buffer = 0 },
  })
end
