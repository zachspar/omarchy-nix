-- Wallpaper picker for Elephant/Walker.
-- Adapted from basecamp/omarchy default/elephant/omarchy_background_selector.lua (MIT).
-- This port keeps the active theme under ~/.local/state/omarchy/current
-- (Omarchy uses ~/.config/omarchy/current/theme).

Name = "omarchyBackgroundSelector"
NamePretty = "Omarchy Background Selector"
Cache = false
HideFromProviderlist = true
SearchName = true

local function ShellEscape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function FormatName(filename)
  local name = filename:gsub("^%d+", ""):gsub("^%-", "")
  name = name:gsub("%.[^%.]+$", "")
  name = name:gsub("-", " ")
  name = name:gsub("%S+", function(word)
    return word:sub(1, 1):upper() .. word:sub(2):lower()
  end)
  return name
end

local function read_theme_name(home)
  local paths = {
    home .. "/.local/state/omarchy/current/theme.name",
    home .. "/.config/omarchy/current/theme.name",
  }
  for _, path in ipairs(paths) do
    local f = io.open(path, "r")
    if f then
      local name = f:read("*l")
      f:close()
      if name and name ~= "" then
        return name
      end
    end
  end
  return nil
end

function GetEntries()
  local entries = {}
  local home = os.getenv("HOME") or ""
  local theme_name = read_theme_name(home)

  local dirs = {
    home .. "/.local/state/omarchy/current/backgrounds",
    home .. "/.config/omarchy/current/theme/backgrounds",
  }
  if theme_name then
    table.insert(dirs, home .. "/.config/omarchy/backgrounds/" .. theme_name)
    table.insert(dirs, home .. "/.config/omarchy/themes/" .. theme_name .. "/backgrounds")
  end

  local seen = {}

  for _, wallpaper_dir in ipairs(dirs) do
    local handle = io.popen(
      "find -L "
        .. ShellEscape(wallpaper_dir)
        .. " -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.bmp' -o -name '*.webp' \\) 2>/dev/null | sort"
    )
    if handle then
      for background in handle:lines() do
        local filename = background:match("([^/]+)$")
        if filename and not seen[filename] then
          seen[filename] = true
          table.insert(entries, {
            Text = FormatName(filename),
            Value = background,
            Actions = {
              activate = "omarchy-theme-bg-set " .. ShellEscape(background),
            },
            Preview = background,
            PreviewType = "file",
          })
        end
      end
      handle:close()
    end
  end

  return entries
end
