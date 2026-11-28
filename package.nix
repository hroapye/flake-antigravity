{
  lib,
  stdenv,
  alsa-lib,
  asar,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  copyDesktopItems,
  cups,
  dbus,
  expat,
  fetchurl,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  libGL,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeDesktopItem,
  makeShellWrapper,
  nspr,
  nss,
  pango,
  pipewire,
  systemdLibs,
  wrapGAppsHook3,
}:

let
  source = builtins.fromJSON (builtins.readFile ./vendor/antigravity-source.json);
in
stdenv.mkDerivation {
  pname = "antigravity";
  version = source.version;

  src = fetchurl {
    inherit (source) url hash;
    name = source.filename;
  };

  sourceRoot = "Antigravity-x64";

  nativeBuildInputs = [
    asar
    autoPatchelfHook
    copyDesktopItems
    makeShellWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gsettings-desktop-schemas
    gtk3
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    systemdLibs
  ];

  # These libraries are loaded by Chromium with dlopen(), so autoPatchelfHook
  # cannot discover them from DT_NEEDED entries.
  runtimeDependencies = map lib.getLib [
    libnotify
    libpulseaudio
    libsecret
    pipewire
  ];

  # ANGLE's bundled libraries dynamically load the system GL implementation.
  appendRunpaths = [ "${lib.getLib libGL}/lib" ];

  desktopItems = [
    (makeDesktopItem {
      name = "antigravity";
      desktopName = "Antigravity";
      comment = "Manage multiple autonomous agents across independent projects";
      exec = "antigravity %U";
      icon = "antigravity";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/antigravity" ];
      startupWMClass = "antigravity";
    })
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/antigravity
    cp -r . $out/share/antigravity

    asar extract-file resources/app.asar icon.png
    install -Dm644 icon.png $out/share/icons/hicolor/512x512/apps/antigravity.png

    runHook postInstall
  '';

  postFixup = ''
    makeShellWrapper $out/share/antigravity/antigravity $out/bin/antigravity \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  '';

  meta = {
    description = "Desktop environment for managing multiple autonomous agents";
    homepage = "https://antigravity.google";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
