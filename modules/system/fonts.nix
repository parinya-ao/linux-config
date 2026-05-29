{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.system.fonts;

  mkFont =
    {
      pname,
      version,
      url,
      hash,
      isZip ? true,
      stripRoot ? false,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version;

      src = pkgs.fetchzip {
        inherit url hash stripRoot;
        extension = if isZip then "zip" else null;
      };

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share/fonts/truetype
        mkdir -p $out/share/fonts/opentype

        find . -type f \( -iname \*.ttf -o -iname \*.otf \) -exec bash -c '
          for file; do
            if [[ "$file" == *.ttf || "$file" == *.TTF ]]; then
              cp "$file" $out/share/fonts/truetype/
            elif [[ "$file" == *.otf || "$file" == *.OTF ]]; then
              cp "$file" $out/share/fonts/opentype/
            fi
          done
        ' bash {} +

        runHook postInstall
      '';
    };

  grabInter = mkFont {
    pname = "grab-inter-font";
    version = "1.0";
    url = "https://github.com/grab/inter-font-extensions/archive/refs/tags/1.0.zip";
    hash = "sha256-j435FmMeOs+IgdfnHGyz07jNGidzNe88pMhDEy0b0PM=";
    stripRoot = true;
  };

  aptos = mkFont {
    pname = "microsoft-aptos-fonts";
    version = "1.0";
    url = "https://download.microsoft.com/download/8/6/0/860a94fa-7feb-44ef-ac79-c072d9113d69/Microsoft%20Aptos%20Fonts.zip";
    hash = "sha256-jkYOP5upe+zMnuQtDLCAcaG1ocbx1iHm1ygW9pqGTig=";
    stripRoot = false;
  };

  thSarabunNew = mkFont {
    pname = "th-sarabun-new";
    version = "1.0";
    url = "https://www.f0nt.com/?dl_name=sipafonts/THSarabunNew.zip";
    hash = "sha256-VLiGhYiKPoB4q+DnwlfEqqOP8Q7WqlAQYhB54bIS+Gg=";
    stripRoot = false;
  };

  firaCodeNerd = mkFont {
    pname = "firacode-nerd-font";
    version = "3.4.0";
    url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip";
    hash = "sha256-cz+8zV+I2RBfAVmAiUGyIXRk2rZ7zM/Z2vQrOtbrP6Y=";
    stripRoot = false;
  };

in
{
  options.my.system.fonts.enable = lib.mkEnableOption "Production grade system fonts collection";

  config = lib.mkIf cfg.enable {
    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
      inter
      ibm-plex
      fira-code
      noto-fonts
      noto-fonts-cjk-sans
      intel-one-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
      cascadia-code

      grabInter
      aptos
      thSarabunNew
      firaCodeNerd
    ];
  };
}
