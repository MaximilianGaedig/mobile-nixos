{
  lib,
  fetchFromGitLab,
  runCommand,
}:

let
  baseFw = fetchFromGitLab {
    owner = "sdm845-mainline";
    repo = "firmware-oneplus-sdm845";
    rev = "176ca713448c5237a983fb1f158cf3a5c251d775";
    sha256 = "sha256-ZrBvYO+MY0tlamJngdwhCsI1qpA/2FXoyEys5FAYLj4=";
  };
in
runCommand "oneplus-sdm845-firmware"
  {
    inherit baseFw;
    meta.license = lib.licenses.unfree;
  }
  ''
    mkdir -p $out/lib/firmware
    cp -r --no-preserve=mode $baseFw/lib/firmware/* $out/lib/firmware/

    mkdir -p $out/lib/firmware/qcom/sdm845/OnePlus

    ln -s ../oneplus6 $out/lib/firmware/qcom/sdm845/OnePlus/enchilada
    ln -s ../oneplus6 $out/lib/firmware/qcom/sdm845/OnePlus/fajita

    mkdir -p $out/usr/share/qcom/sdm845/OnePlus/oneplus6
    cp -r --no-preserve=mode $baseFw/usr/share/qcom/sdm845/OnePlus/oneplus6/* $out/usr/share/qcom/sdm845/OnePlus/oneplus6/
    
    ln -s oneplus6 $out/usr/share/qcom/sdm845/OnePlus/fajita
    ln -s oneplus6 $out/usr/share/qcom/sdm845/OnePlus/enchilada
    ''
