{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.omarchy;
  themeTools = pkgs.callPackage ../../pkgs/omarchy-theme-tools { };
  currentTheme = "${config.xdg.stateHome}/omarchy/current";
  elephantBin = lib.getExe pkgs.elephant;
  walkerBin = lib.getExe cfg.shell.launcherPackage;
  findPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnused
    pkgs.bash
  ];
  # Fallback tokens when the theme pillar is off or walker.css is not seeded yet.
  fallbackWalkerCss = ''
    @define-color selected-text #7aa2f7;
    @define-color text #c0caf5;
    @define-color base #1a1b26;
    @define-color border #c0caf5;
    @define-color foreground #c0caf5;
    @define-color background #1a1b26;
  '';
  structuralCss = builtins.readFile ./walker/style.css;
  walkerStyle =
    if cfg.theme.enable then
      ''
        @import url("file://${currentTheme}/walker.css");

        ${structuralCss}
      ''
    else
      ''
        ${fallbackWalkerCss}

        ${structuralCss}
      '';
in
{
  config = lib.mkIf (cfg.enable && cfg.shell.enable) (
    lib.mkMerge [
      {
        home.packages = [
          themeTools
          pkgs.elephant
          pkgs.libqalculate
          pkgs.wl-clipboard
        ];

        home.sessionVariables.OMARCHY_THEME_DIR = "${themeTools}/share/omarchy/themes";

        xdg.configFile = {
          "walker/config.toml".source = ./walker/config.toml;
          "walker/themes/omarchy-default/style.css".text = walkerStyle;
          "walker/themes/omarchy-default/layout.xml".source = ./walker/layout.xml;
          "elephant/desktopapplications.toml".source = ./walker/desktopapplications.toml;
          "elephant/calc.toml".source = ./walker/calc.toml;
          "elephant/symbols.toml".source = ./walker/symbols.toml;
        };

        # Elephant is a user-session daemon. Started here (not services.elephant)
        # so the module evaluates on nixpkgs pins that lack that option.
        systemd.user.services.omarchy-elephant = {
          Unit = {
            Description = "Elephant application launcher backend (Walker)";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = elephantBin;
            Restart = "on-failure";
            RestartSec = 2;
            Environment = [
              "PATH=${findPath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
              "OMARCHY_THEME_DIR=${themeTools}/share/omarchy/themes"
            ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        # Keep a Walker instance warm (GTK startup is slow). Omarchy uses
        # GSK_RENDERER=cairo to avoid GTK4 renderer glitches on Hyprland.
        systemd.user.services.omarchy-walker = {
          Unit = {
            Description = "Walker application launcher (gapplication service)";
            PartOf = [ "graphical-session.target" ];
            After = [
              "graphical-session.target"
              "omarchy-elephant.service"
            ];
            Requires = [ "omarchy-elephant.service" ];
          };
          Service = {
            ExecStart = "${walkerBin} --gapplication-service";
            Restart = "on-failure";
            RestartSec = 2;
            Environment = [
              "GSK_RENDERER=cairo"
              "PATH=${findPath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
              "OMARCHY_THEME_DIR=${themeTools}/share/omarchy/themes"
            ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      }

      (lib.mkIf cfg.theme.enable {
        xdg.configFile = {
          "elephant/menus/omarchy_themes.lua".source = ./walker/omarchy_themes.lua;
          "elephant/menus/omarchy_background_selector.lua".source = ./walker/omarchy_background_selector.lua;
        };
      })
    ]
  );
}
