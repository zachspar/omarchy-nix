{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
in
{
  config = lib.mkIf (cfg.enable && cfg.apps.enable) (
    lib.mkMerge [
      {
        programs.neovim.enable = true;
      }

      (lib.mkIf cfg.theme.enable {
        # Official neovim.lua specs name these colorscheme plugins. Packs
        # whose plugin is not in nixpkgs (or that have no neovim.lua) fall
        # back to highlight groups from current/neovim-palette.lua.
        programs.neovim.plugins = with pkgs.vimPlugins; [
          tokyonight-nvim
          catppuccin-nvim
          kanagawa-nvim
          gruvbox-nvim
          rose-pine
          nightfox-nvim
          everforest
          bamboo-nvim
        ];

        xdg.configFile."nvim/lua/omarchy-theme.lua".source = ./omarchy-theme.lua;

        programs.neovim.initLua = ''
          require("omarchy-theme").setup()
        '';
      })
    ]
  );
}
