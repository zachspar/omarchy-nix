{
  lib,
  stdenvNoCC,
  fetchgit,
  imagemagick,
  dejavu_fonts,
  writeText,
  themeName ? "tokyo-night",
  background ? "1a1b26",
  foreground ? "a9b1d6",
  failedColor ? "f7768e",
  logo ? null,
}:
let
  assets = import ./assets.nix { inherit fetchgit; };

  strip = value: lib.removePrefix "#" (lib.toLower value);
  bg = strip background;
  fg = strip foreground;
  fail = strip failedColor;

  # Same QML layout as basecamp/omarchy default/sddm/omarchy/Main.qml (MIT).
  # Colors are baked here: Omarchy rewrites /usr/share at runtime; NixOS
  # cannot, so the declared theme.name (or a logo override) is the generation.
  mainQml = writeText "Main.qml" ''
    import QtQuick 2.0

    Rectangle {
        id: root
        width: 640
        height: 480
        color: "#${bg}"

        property string currentUser: userModel.lastUser
        property bool loginFailed: false
        property int sessionIndex: {
            for (var i = 0; i < sessionModel.rowCount(); i++) {
                var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
                if (name.indexOf("uwsm") !== -1)
                    return i
            }
            return sessionModel.lastIndex
        }

        Connections {
            target: sddm
            function onLoginFailed() {
                root.loginFailed = true
                password.text = ""
                password.focus = true
            }
            function onLoginSucceeded() {
                root.loginFailed = false
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 40

            Image {
                id: logo
                source: "logo.png"
                width: Math.min(sourceSize.width, root.width * 0.8)
                height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15

                Image {
                    source: root.loginFailed ? "lock-failed.png" : "lock.png"
                    width: 34
                    height: 38
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: entry.width
                    height: entry.height

                    Image {
                        id: entry
                        source: root.loginFailed ? "entry-failed.png" : "entry.png"
                        anchors.centerIn: parent
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Repeater {
                            model: Math.min(password.text.length, 21)

                            Image {
                                source: "bullet.png"
                                width: 7
                                height: 7
                            }
                        }
                    }

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        font.letterSpacing: 5
                        passwordCharacter: "\u2022"
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        cursorDelegate: Item {}
                        focus: true

                        onTextChanged: root.loginFailed = false

                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login(root.currentUser, password.text, root.sessionIndex)
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }

        Component.onCompleted: password.forceActiveFocus()
    }
  '';

  metadata = writeText "metadata.desktop" ''
    [SddmGreeterTheme]
    Name=Omarchy
    Description=Minimal terminal-style login theme matching the Omarchy decrypt screen
    Author=Omarchy
    Copyright=(c) David Heinemeier Hansson
    License=MIT
    Type=sddm-theme
    Version=1.0
    Website=https://omarchy.org
    MainScript=Main.qml
    ConfigFile=theme.conf
    Theme-Id=omarchy
    Theme-API=2.0
    QtVersion=6
  '';

  themeConf = writeText "theme.conf" ''
    [General]
  '';

  # Same file as basecamp/omarchy default/sddm/hyprland.conf (master):
  # misc + animations only. Do not invent windowrules — they are not
  # upstream and the old syntax is a parse error on Hyprland 0.53+.
  hyprlandConf = ./hyprland.conf;

  logoArg = if logo == null then "" else logo;
  dejavuBold = "${dejavu_fonts}/share/fonts/truetype/DejaVuSans-Bold.ttf";
in
stdenvNoCC.mkDerivation {
  pname = "omarchy-greeter";
  version = "0.1.0";

  nativeBuildInputs = [ imagemagick ];

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    src=${assets}
    mkdir -p work
    cd work

    bg="${bg}"
    fg="${fg}"
    fail="${fail}"

    # Official unlock.png for this pack, then Omarchy's default logo, then
    # a generated wordmark so a missing file still looks intentional.
    if [ -n "${logoArg}" ] && [ -f "${logoArg}" ]; then
      cp "${logoArg}" logo.png
    elif [ -f "$src/themes/${themeName}/unlock.png" ]; then
      cp "$src/themes/${themeName}/unlock.png" logo.png
    elif [ -f "$src/default/plymouth/logo.png" ]; then
      cp "$src/default/plymouth/logo.png" logo.png
    else
      magick -size 520x140 xc:none \
        -font "${dejavuBold}" \
        -fill "#$fg" -pointsize 56 -gravity center \
        -annotate +0+0 'omarchy' logo.png
    fi

    chrome_dir=""
    if [ -d "$src/default/plymouth" ]; then
      chrome_dir="$src/default/plymouth"
    elif [ -d "$src/default/sddm/omarchy" ]; then
      chrome_dir="$src/default/sddm/omarchy"
    fi

    for asset in bullet entry lock progress_bar progress_box; do
      if [ -n "$chrome_dir" ] && [ -f "$chrome_dir/$asset.png" ]; then
        # Same ImageMagick recolor Omarchy's omarchy-plymouth-set uses.
        magick "$chrome_dir/$asset.png" -channel RGB +level-colors "#$fg","#$fg" "$asset.png"
      else
        magick -size 32x32 "xc:#$fg" "$asset.png"
      fi
    done

    magick entry.png -channel RGB +level-colors "#$fail","#$fail" entry-failed.png
    magick lock.png -channel RGB +level-colors "#$fail","#$fail" lock-failed.png

    bg_r=$(awk -v n=$((16#''${bg:0:2})) 'BEGIN{printf "%.3f", n/255}')
    bg_g=$(awk -v n=$((16#''${bg:2:2})) 'BEGIN{printf "%.3f", n/255}')
    bg_b=$(awk -v n=$((16#''${bg:4:2})) 'BEGIN{printf "%.3f", n/255}')

    if [ -f "$src/default/plymouth/omarchy.script" ]; then
      sed \
        -e "s/^Window.SetBackgroundTopColor.*/Window.SetBackgroundTopColor($bg_r, $bg_g, $bg_b);/" \
        -e "s/^Window.SetBackgroundBottomColor.*/Window.SetBackgroundBottomColor($bg_r, $bg_g, $bg_b);/" \
        "$src/default/plymouth/omarchy.script" > omarchy.script
    else
      printf '%s\n' \
        "Window.SetBackgroundTopColor($bg_r, $bg_g, $bg_b);" \
        "Window.SetBackgroundBottomColor($bg_r, $bg_g, $bg_b);" \
        'logo.image = Image("logo.png");' \
        "logo.sprite = Sprite(logo.image);" \
        "logo.sprite.SetX(Window.GetWidth() / 2 - logo.image.GetWidth() / 2);" \
        "logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2);" \
        > omarchy.script
    fi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    sddm="$out/share/sddm/themes/omarchy"
    ply="$out/share/plymouth/themes/omarchy"
    mkdir -p "$sddm" "$ply" "$out/share/sddm"

    cp logo.png bullet.png entry.png lock.png \
      entry-failed.png lock-failed.png "$sddm/"
    cp ${mainQml} "$sddm/Main.qml"
    cp ${metadata} "$sddm/metadata.desktop"
    cp ${themeConf} "$sddm/theme.conf"
    cp ${hyprlandConf} "$out/share/sddm/hyprland.conf"

    cp logo.png bullet.png entry.png lock.png \
      progress_bar.png progress_box.png omarchy.script "$ply/"

    printf '%s\n' \
      '[Plymouth Theme]' \
      'Name=Omarchy' \
      'Description=Omarchy splash and LUKS unlock.' \
      'ModuleName=script' \
      "" \
      '[script]' \
      "ImageDir=$ply" \
      "ScriptFile=$ply/omarchy.script" \
      'ConsoleLogBackgroundColor=0x${bg}' \
      > "$ply/omarchy.plymouth"

    runHook postInstall
  '';

  meta = {
    description = "Omarchy SDDM greeter and Plymouth unlock theme";
    homepage = "https://omarchy.org";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
