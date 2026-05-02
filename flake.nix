{
  description = "X-AnyLabeling development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # System libraries required by pip-installed PyQt6, OpenCV, etc.
      # Per NixOS wiki: https://wiki.nixos.org/wiki/Python#Compiled_libraries
      runtimeLibs = with pkgs; [
        # C++ runtime — needed by virtually all pip binary wheels
        stdenv.cc.cc.lib
        # Core system
        glib
        zlib
        zstd
        expat
        dbus
        # X11 — base display stack
        libx11
        libxext
        libxrender
        libxi
        libxrandr
        libxshmfence
        # XCB + utility libs — required by PyQt6's xcb platform plugin
        libxcb
        libxcb-util
        libxcb-image
        libxcb-keysyms
        libxcb-render-util
        libxcb-wm              # provides libxcb-icccm (WM hints)
        xcb-util-cursor         # libxcb-cursor — required by Qt xcb plugin since Qt 6.5
        libxkbcommon            # provides libxkbcommon + libxkbcommon-x11
        # OpenGL — needed by PyQt6 & OpenCV
        libGL
        mesa
        # Fonts
        fontconfig
        freetype
        # Qt WebEngine dependencies
        nss
        nspr
        alsa-lib
        # Qt Multimedia — PyQt6.QtMultimedia requires libpulse + pipewire
        libpulseaudio
        pipewire
        # Kerberos — required by PyQt6.QtMultimedia (libgssapi_krb5.so.2)
        krb5
      ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          python312
          uv
        ] ++ runtimeLibs;

        shellHook = ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:$LD_LIBRARY_PATH"
          # Prevent uv from downloading its own Python binary (use Nix-provided one)
          export UV_PYTHON_DOWNLOADS=never

          if [ ! -d .venv ]; then
            echo "Creating virtual environment..."
            # Pass UV_PYTHON only here — global export would override VIRTUAL_ENV for uv pip
            UV_PYTHON="${pkgs.python312}/bin/python3.12" uv venv
          fi

          # Fix venv if Nix updated Python (store hash changed)
          EXPECTED_PYTHON="${pkgs.python312}/bin/python3.12"
          VENV_PYTHON=$(readlink -f .venv/bin/python 2>/dev/null || echo "")
          if [ "$VENV_PYTHON" != "$EXPECTED_PYTHON" ]; then
            echo "Updating venv Python symlink: $VENV_PYTHON -> $EXPECTED_PYTHON"
            ln -sfn "$EXPECTED_PYTHON" .venv/bin/python
          fi

          source .venv/bin/activate
        '';
      };
    };
}
