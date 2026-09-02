-- Load the active Omarchy pack's neovim.lua (LazyVim spec) and apply it.
-- Official packs name a real colorscheme plugin; packs without neovim.lua,
-- or whose plugin is not on the runtimepath, use highlight groups from
-- neovim-palette.lua (the same colors.toml keys Omarchy templates from).

local M = {}

local function state_dir()
  local state = vim.env.XDG_STATE_HOME
  if not state or state == "" then
    state = vim.fs.joinpath(vim.env.HOME, ".local", "state")
  end
  return vim.fs.joinpath(state, "omarchy", "current")
end

local function readable(path)
  return path and vim.fn.filereadable(path) == 1
end

local function load_palette()
  local path = vim.fs.joinpath(state_dir(), "neovim-palette.lua")
  if not readable(path) then
    return nil
  end
  local ok, palette = pcall(dofile, path)
  if ok and type(palette) == "table" then
    return palette
  end
  return nil
end

local function hl(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

function M.apply_palette(palette)
  if type(palette) ~= "table" or not palette.background then
    return false
  end

  local bg = palette.background
  local fg = palette.foreground
  local bright = palette.bright_foreground or fg
  local dark_fg = palette.dark_foreground or palette.muted or fg
  local muted = palette.muted or dark_fg
  local accent = palette.accent or palette.blue or fg
  local sel = palette.selection or palette.selection_background or muted
  local sel_fg = palette.selection_foreground or bright
  local red = palette.red or fg
  local yellow = palette.yellow or fg
  local orange = palette.orange or yellow
  local green = palette.green or fg
  local cyan = palette.cyan or fg
  local blue = palette.blue or accent
  local magenta = palette.magenta or fg
  local comment = dark_fg

  vim.o.termguicolors = true
  vim.o.background = (palette.mode == "light") and "light" or "dark"

  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  hl("Normal", { fg = fg, bg = bg })
  hl("NormalNC", { fg = fg, bg = bg })
  hl("NormalFloat", { fg = fg, bg = palette.dark_background or bg })
  hl("FloatBorder", { fg = muted, bg = palette.dark_background or bg })
  hl("Comment", { fg = comment, italic = true })
  hl("Conceal", { fg = muted })
  hl("Constant", { fg = orange })
  hl("String", { fg = green })
  hl("Character", { fg = green })
  hl("Number", { fg = orange })
  hl("Boolean", { fg = orange })
  hl("Float", { fg = orange })
  hl("Identifier", { fg = blue })
  hl("Function", { fg = blue })
  hl("Statement", { fg = magenta })
  hl("Conditional", { fg = magenta })
  hl("Repeat", { fg = magenta })
  hl("Label", { fg = magenta })
  hl("Operator", { fg = cyan })
  hl("Keyword", { fg = magenta })
  hl("Exception", { fg = red })
  hl("PreProc", { fg = cyan })
  hl("Include", { fg = cyan })
  hl("Define", { fg = cyan })
  hl("Macro", { fg = cyan })
  hl("Type", { fg = yellow })
  hl("StorageClass", { fg = yellow })
  hl("Structure", { fg = yellow })
  hl("Typedef", { fg = yellow })
  hl("Special", { fg = accent })
  hl("SpecialChar", { fg = orange })
  hl("Tag", { fg = accent })
  hl("Delimiter", { fg = muted })
  hl("Underlined", { fg = blue, underline = true })
  hl("Todo", { fg = bg, bg = yellow, bold = true })
  hl("Error", { fg = red, bold = true })
  hl("ErrorMsg", { fg = red, bold = true })
  hl("WarningMsg", { fg = yellow })
  hl("Title", { fg = accent, bold = true })
  hl("Directory", { fg = blue })
  hl("LineNr", { fg = muted })
  hl("CursorLineNr", { fg = bright, bold = true })
  hl("CursorLine", { bg = palette.lighter_background or sel })
  hl("CursorColumn", { bg = palette.lighter_background or sel })
  hl("ColorColumn", { bg = palette.lighter_background or sel })
  hl("SignColumn", { fg = muted, bg = bg })
  hl("Folded", { fg = dark_fg, bg = palette.lighter_background or sel })
  hl("FoldColumn", { fg = muted, bg = bg })
  hl("VertSplit", { fg = muted, bg = bg })
  hl("WinSeparator", { fg = muted, bg = bg })
  hl("Visual", { fg = sel_fg, bg = sel })
  hl("VisualNOS", { bg = sel })
  hl("Search", { fg = bg, bg = yellow })
  hl("IncSearch", { fg = bg, bg = accent })
  hl("CurSearch", { fg = bg, bg = accent })
  hl("MatchParen", { fg = accent, bold = true })
  hl("StatusLine", { fg = bright, bg = palette.lighter_background or sel })
  hl("StatusLineNC", { fg = muted, bg = palette.dark_background or bg })
  hl("TabLine", { fg = muted, bg = palette.dark_background or bg })
  hl("TabLineFill", { bg = palette.dark_background or bg })
  hl("TabLineSel", { fg = bright, bg = bg, bold = true })
  hl("Pmenu", { fg = fg, bg = palette.dark_background or bg })
  hl("PmenuSel", { fg = sel_fg, bg = sel })
  hl("PmenuSbar", { bg = muted })
  hl("PmenuThumb", { bg = accent })
  hl("WildMenu", { fg = bg, bg = accent })
  hl("NonText", { fg = muted })
  hl("SpecialKey", { fg = muted })
  hl("Whitespace", { fg = muted })
  hl("EndOfBuffer", { fg = muted })
  hl("DiffAdd", { fg = green })
  hl("DiffChange", { fg = yellow })
  hl("DiffDelete", { fg = red })
  hl("DiffText", { fg = blue, bold = true })
  hl("DiagnosticError", { fg = red })
  hl("DiagnosticWarn", { fg = yellow })
  hl("DiagnosticInfo", { fg = cyan })
  hl("DiagnosticHint", { fg = blue })
  hl("DiagnosticOk", { fg = green })
  hl("Cursor", { fg = bg, bg = palette.cursor or bright })
  hl("TermCursor", { fg = bg, bg = palette.cursor or bright })

  vim.g.colors_name = "omarchy"
  return true
end

local function module_candidates(item)
  local names = {}
  local function add(name)
    if name and name ~= "" then
      names[#names + 1] = name
    end
  end
  add(item.name)
  local repo = item[1]
  if type(repo) == "string" then
    local last = repo:match("([^/]+)$") or repo
    add(last:gsub("%.nvim$", ""):gsub("%-nvim$", ""):gsub("%-neovim$", ""):gsub("^nvim%-", ""))
    add(last:gsub("%.nvim$", ""))
    add(last)
  end
  return names
end

local function try_setup(item, extra)
  local opts = vim.tbl_extend("force", item.opts or {}, extra or {})
  for _, mod in ipairs(module_candidates(item)) do
    local ok, plugin = pcall(require, mod)
    if ok and type(plugin) == "table" and type(plugin.setup) == "function" then
      pcall(plugin.setup, opts)
      return true
    end
  end
  return false
end

local function colorscheme_aliases(name)
  local aliases = {
    ["catppuccin-nvim"] = { "catppuccin", "catppuccin-mocha" },
  }
  local list = { name }
  for _, alias in ipairs(aliases[name] or {}) do
    list[#list + 1] = alias
  end
  return list
end

local function try_colorscheme(name)
  if not name or name == "" then
    return false
  end
  if name == "omarchy" then
    return M.apply_palette(load_palette())
  end
  for _, candidate in ipairs(colorscheme_aliases(name)) do
    local ok = pcall(vim.cmd.colorscheme, candidate)
    if ok and vim.g.colors_name == candidate then
      return true
    end
  end
  return false
end

local function light_mode()
  return readable(vim.fs.joinpath(state_dir(), "light.mode"))
end

function M.apply()
  vim.o.termguicolors = true
  vim.o.background = light_mode() and "light" or "dark"

  local neovim_lua = vim.fs.joinpath(state_dir(), "neovim.lua")
  local spec = nil
  if readable(neovim_lua) then
    local ok, loaded = pcall(dofile, neovim_lua)
    if ok and type(loaded) == "table" then
      spec = loaded
    end
  end

  local colorscheme = nil
  local extra = {}
  if spec then
    for _, item in ipairs(spec) do
      if type(item) == "table" and item[1] == "LazyVim/LazyVim" and type(item.opts) == "table" then
        colorscheme = item.opts.colorscheme
        if item.opts.background then
          extra.background = item.opts.background
          vim.g.everforest_background = item.opts.background
        end
      end
    end
    for _, item in ipairs(spec) do
      if type(item) == "table" and item[1] and item[1] ~= "LazyVim/LazyVim" then
        try_setup(item, extra)
      end
    end
  end

  if not try_colorscheme(colorscheme) then
    M.apply_palette(load_palette())
  end

  vim.schedule(function()
    vim.cmd("redraw!")
  end)
end

function M.setup()
  M.apply()

  local runtime = vim.env.XDG_RUNTIME_DIR
  if runtime and runtime ~= "" then
    pcall(vim.fn.serverstart, vim.fs.joinpath(runtime, "omarchy-nvim-" .. tostring(vim.fn.getpid()) .. ".sock"))
  end

  vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1",
    group = vim.api.nvim_create_augroup("omarchy_theme_sigusr1", { clear = true }),
    nested = true,
    callback = function()
      M.apply()
    end,
  })
end

return M
