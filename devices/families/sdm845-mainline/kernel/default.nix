{
  mobile-nixos,
  fetchFromGitLab,
  pkgs,
  lib,
  ...
}:

let
  # `make kernelrelease` for the pinned tarball (no git tree → no setlocalversion
  # -g<sha>/+ suffix): plain 7.1.0-rc1. Must equal the runtime `uname -r` and the
  # /lib/modules/<version>/ naming. (The scratchpad dev build, being a git tree,
  # produced 7.1.0-rc1-sdm845-g85f1df2a4ec7+ — that suffix is git-tree-only.)
  version = "7.1.0-rc1";

  # ── FAST LOCAL ITERATION (dev only) ────────────────────────────────────
  # Flip to true to skip the from-source build and copy a natively-built
  # kernel from the scratchpad instead — a quick dev cycle for kernel hacking.
  # The default (false) builds reproducibly from the pinned source + the
  # committed patch series below, so the config is buildable from a commit.
  useLocalBuild = true;
  localKernelBuild = /tmp/claude-1000/-home-user-proj-system/c9959eb2-a3a8-496e-9a34-3b74359adc13/scratchpad/staging;
  # ───────────────────────────────────────────────────────────────────────

  # Collect an ordered patch series from a directory (NNNN-*.patch names sort
  # lexically, which is the apply order git format-patch intends).
  series =
    dir:
    map (n: dir + "/${n}") (
      builtins.filter (lib.hasSuffix ".patch") (builtins.attrNames (builtins.readDir dir))
    );

  kernel = mobile-nixos.kernel-builder {
    inherit version;
    configfile = ./config.aarch64;

    src = fetchFromGitLab {
      owner = "sdm845-mainline";
      repo = "linux";
      rev = "sdm845-7.1-rc1-r0"; # 85f1df2a4ec71d7a91dd95a7a49f889d1595ffa8
      hash = "sha256-/K74EnSqTkkNJAUe7+g7Rw+aqNVBO5dFyXrSwAKvsdc=";
    };

    # Applied in order. The two upstream series are Dawid Wróbel's unmodified
    # commits (github.com/wrobelda/linux), so they stay perfectly upstream-shaped;
    # the OnePlus 6 delta is only the machine allowlist entry and the DT node.
    patches =
      [
        # NOTE: 0001-oneplus-enchilada-enable-nfc.patch is malformed (line 39)
        # and is a separate concern from fingerprint — omitted until fixed.
      ]
      ++ [
        # Qualcomm QSEECOM TEE driver (41 Wróbel commits squashed).
        ./patches/tee-qseecom-driver.patch
        # Goodix SPI fingerprint sensor driver + DT binding + docs (generic).
        ./patches/goodix-fp-spi-driver.patch
        # Take gcc out of the CX power domain entirely. clk_core_prepare()
        # pins the clock controller runtime-active (~40 prepared clocks), so
        # as a cx member it made genpd_power_off(cx) impossible and mirrored
        # into the sleep vote; and as a cx_ao member its mere *enabled* state
        # pinned the shared cx.lvl ACTIVE vote at enable_corner. gcc votes
        # perf 0 either way, so only the enable-hold is lost.
        ./patches/sdm845-gcc-no-cx-power-domain.patch
        # Drop the BT link from 3.2 to 3 Mbaud. The GENI SE clock request is
        # baud * 16, and 51.2 MHz resolves to the 102.4 MHz QUP rate, which the
        # OPP core rounds up to the 128 MHz entry = rpmhpd_opp_nom -- a vote the
        # port holds for as long as the tty is open, so merely having Bluetooth
        # up pinned CX at 256. 48 MHz is an exact QUP rate and rounds to the
        # 50 MHz OPP = rpmhpd_opp_min_svs.
        # All four remoteprocs took the sleep-voting rpmhcc XO as their "xo",
        # so having the DSPs loaded pinned xo.lvl = 0x3 in the RPMH sleep set
        # and AOSS could never reach its deep states (aosd and cxsd both 0).
        ./patches/sdm845-remoteproc-xo-active-only.patch
        # UFS host/PHY and both USB HS PHYs hold the sleep-voting XO for their
        # whole lifetime, pinning xo.lvl on in the RPMH sleep set. None need the
        # crystal while the AP is asleep. Takes bi_tcxo refs from 302 to 7.
        ./patches/sdm845-ufs-usb-xo-active-only.patch
        ./patches/sdm845-enchilada-bt-baud-min-svs.patch
        # Give uart6 an RX-edge wakeup IRQ + sleep pinctrl so the BT UART can
        # runtime-suspend and stop pinning CX at performance state 256.
        # Mirrors sc7180-trogdor; WCN3990 here has no host-wake GPIO.
        ./patches/sdm845-enchilada-uart6-wakeup.patch
        # wcd934x had no dev_pm_ops at all: it enabled five supplies at probe
        # and dropped them only at driver removal, so the audio codec was
        # powered from boot to shutdown whether or not anything played sound.
        # Drop them across system sleep.
        ./patches/wcd934x-system-sleep-pm.patch
        # Command-mode inter-frame DSI clock gating -- the TODO upstream left
        # disabled ("once mdp driver support it"), plus the missing DPU half.
        # This panel really is INTF_MODE_CMD (confirmed at runtime), so between
        # frames the link need not run; letting the host suspend releases
        # mdss_gdsc and the CX rail. Opt-in via cmd_mode_clk_gating=1.
        ./patches/msm-dsi-cmd-mode-clk-gating.patch
        # msm_dsi_host_power_on() takes a pm_runtime reference on its success
        # path and puts only on the error unwind, while power_off() takes its
        # own second reference and drops only that one -- so every display
        # enable leaks +1 (measured: usage 5 -> 6 -> 7 across wake cycles).
        # The DSI host lives in the CX rpmhpd, and rpmhpd's cx is not
        # active_only, so to_active_sleep() mirrors the active corner into the
        # RPMH_SLEEP_STATE vote. A leaked reference therefore keeps CX voted on
        # in the sleep set and cxsd can never leave 0.
        ./patches/msm-dsi-host-power-off-refcount.patch
        # OnePlus 6 delta (minimal, each independently upstream-able):
        ./0003-qseecom-enable-oneplus6.patch # qcom_scm QSEECOM machine allowlist
      ]
      ++ series ./patches/oneplus-enchilada; # the goodix,gf3626 DT node for enchilada

    isModular = true;
    isCompressed = "gz";
    nativeBuildInputs = [ pkgs.zstd ];
  };
in
if !useLocalBuild then
  kernel
else
  # Dev shortcut: ignore src/patches and copy the pre-built scratchpad kernel.
  kernel.overrideAttrs (_old: {
    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;
    dontBuild = true;
    patches = [ ];
    prePatch = "";
    postPatch = "";
    preConfigure = "";
    postConfigure = "";
    preInstall = "";
    postInstall = "";
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r ${localKernelBuild}/. $out/
      runHook postInstall
    '';
  })
