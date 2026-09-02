-- Dynamic Omarchy theme menu for Elephant/Walker.
-- Adapted from basecamp/omarchy default/elephant/omarchy_themes.lua (MIT).
-- Paths follow this port: user themes in ~/.config/omarchy/themes, packaged
-- packs in $OMARCHY_THEME_DIR (not $OMARCHY_PATH/themes).
--
-- Themes without preview.png / preview.jpg / backgrounds/ still appear as
-- text-only rows so stub palettes with no wallpaper stay pickable.

Name = "omarchythemes"
NamePretty = "Omarchy Themes"
HideFromProviderlist = true

local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function first_image_in_dir(dir)
  local handle = io.popen("ls -1 '" .. dir .. "' 2>/dev/null | head -n 1")
  if handle then
    local file = handle:read("*l")
    handle:close()
    if file and file ~= "" then
      return dir .. "/" .. file
    end
  end
  return nil
end

local function find_preview_path(dir)
  local png = dir .. "/preview.png"
  local jpg = dir .. "/preview.jpg"
  if file_exists(png) then
    return png
  end
  if file_exists(jpg) then
    return jpg
  end
  return first_image_in_dir(dir .. "/backgrounds")
end

local function shell_escape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function title_case(theme_name)
  local display_name = theme_name:gsub("_", " "):gsub("%-", " ")
  display_name = display_name:gsub("(%a)([%w_']*)", function(first, rest)
    return first:upper() .. rest:lower()
  end)
  return display_name .. " "
end

function GetEntries()
  local entries = {}
  local home = os.getenv("HOME") or ""
  local user_theme_dir = home .. "/.config/omarchy/themes"
  local default_theme_dir = os.getenv("OMARCHY_THEME_DIR") or ""
  if default_theme_dir == "" then
    local omarchy_path = os.getenv("OMARCHY_PATH") or ""
    if omarchy_path ~= "" then
      default_theme_dir = omarchy_path .. "/themes"
    end
  end

  local seen_themes = {}

  local function process_themes_from_dir(theme_dir)
    if theme_dir == nil or theme_dir == "" then
      return
    end

    local handle = io.popen("find -L '" .. theme_dir .. "' -mindepth 1 -maxdepth 1 -type d 2>/dev/null")
    if not handle then
      return
    end

    for theme_path in handle:lines() do
      local theme_name = theme_path:match(".*/(.+)$")

      if theme_name and not seen_themes[theme_name] then
        seen_themes[theme_name] = true

        local preview_path = find_preview_path(theme_path)
          or find_preview_path(default_theme_dir .. "/" .. theme_name)

        local entry = {
          Text = title_case(theme_name),
          Actions = {
            activate = "omarchy-theme-set " .. shell_escape(theme_name),
          },
        }
        if preview_path and preview_path ~= "" then
          entry.Preview = preview_path
          entry.PreviewType = "file"
        end
        table.insert(entries, entry)
      end
    end

    handle:close()
  end

  process_themes_from_dir(user_theme_dir)
  process_themes_from_dir(default_theme_dir)

  return entries
end
