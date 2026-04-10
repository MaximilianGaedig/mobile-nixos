{ lib
, runCommand
, fetchurl
}:

runCommand "samsung-serranove-firmware" {
  # fetchTarball results in an empty directory for some reason
  src = fetchurl {
    url ="https://pepethekingprawn.gitlab.io/firmware/GT-I9195I.tar.xz";
    sha256 = "sha256-X+yUQKxUzk+qVrpRq92iXq/dGRMoOUuHuyFp68DJABs=";
  };
  # meta.license = [
  #   # We make no claims that it can be redistributed.
  #   lib.licenses.unfree
  # ];
} ''
  tar -xf $src
  fwpath="$out/lib/firmware"
  mkdir -p $fwpath/wlan/prima/

  # add modem to enable it later
  # cp -v ./{modem,wcnss}.mdt $fwpath/
  cp -v ./wcnss.mdt $fwpath/
  cp -v ./WCNSS_qcom_wlan_nv.bin $fwpath/wlan/prima/WCNSS_qcom_wlan_nv.bin
''
