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
        # The AOSS ucore drops the QMP link across system sleep and upstream has
        # no PM ops, so from the first resume onward every message to the
        # always-on processor fails with "ucore did not ack channel".
        # OFF pending re-test: added in mobile-nixos 5b9f2a0d, one of the two
        # commits rewound on 2026-09-04 when the phone regressed (USB gadget
        # died at switch_root, phosh froze on unlock). The rewound baseline
        # WITHOUT this and without the UFS lane-clk patch is verified good:
        # gadget up, USB ssh up, journal persisting. Re-add this one ALONE and
        # boot-test before assuming it is innocent.
        # ./patches/qcom-aoss-qmp-pm-ops.patch
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
        # ufs_qcom_enable_lane_clks() lacked the is_lane_clks_enabled guard its
        # disable counterpart has, so every runtime suspend/resume leaked one
        # reference per lane clock. Those are parented to gpll0 -> rpmhcc XO, so
        # the leak pinned xo.lvl = 0x3 in the RPMH sleep set and AOSS could never
        # sleep. This is what kept aosd/cxsd at 0.
        # DISABLED 2026-09-03: these two, together with an uncommitted
        # phy-qcom-qmp-ufs runtime-PM change that only ever lived in the
        # scratchpad tree, jam the UFS request queue during early boot.
        # scsi_id/blkid and ~32 udev-workers wedge in D state on UFS I/O, the
        # udev queue never drains, and stage-1 gives up before reaching the
        # LUKS unlock -- an unbootable phone recoverable only over the initrd
        # telnet shell. Ordinary bulk reads/writes still worked, and there were
        # no UIC errors or aborts, so the jam is silent; CONFIG_DETECT_HUNG_TASK
        # is off, so not even a hung-task warning appears. Reverting all three
        # to upstream took D-state processes 39+ -> 0 and load 58 -> 1.
        # Re-introduce ONE AT A TIME with a boot test; the refcount-leak fix is
        # probably innocent, but it was reverted together with the others so it
        # has not actually been cleared.
        # BISECTED 2026-09-03 -- THIS PATCH IS THE BOOT-JAMMER. Enabled on its
        # own (idle-tuning and the PHY runtime-PM change both out) it still
        # hangs the boot, so it is not innocent and must stay off.
        #
        # Mechanism, confirmed on-device: the guard makes
        # ufs_qcom_enable_lane_clks() skip the enable when is_lane_clks_enabled
        # is already set, but the resume path *needs* that second enable. The
        # lane clocks stay off, ufs_qcom_resume() never completes, and the UFS
        # host sits in power/runtime_status = "resuming" forever. SCSI never
        # calls blk_post_runtime_resume(), so every LUN queue stays frozen and
        # all I/O blocks in __bio_queue_enter -- silently, with no UIC error and
        # no abort. Nothing can be written to the eMMC/UFS at all in that state,
        # which makes the phone unflashable as well as unbootable.
        #
        # The underlying refcount leak it describes is real (xo.lvl pinned at
        # 0x3, aosd/cxsd stuck at 0), so a correct fix is still wanted -- but it
        # must balance the count WITHOUT skipping a needed enable: drop the
        # redundant enable in ufs_qcom_resume(), or make the disable side
        # symmetric, rather than guarding the shared enable helper.
        # ./patches/ufs-qcom-lane-clk-refcount-leak.patch
        # ALSO DISABLED -- boot-tested 2026-09-03 and it wedges too.
        # It does achieve the goal: lane-clk enable_count reaches 0 while
        # suspended (measured 0, vs 1 baseline and 1->5 growth unpatched), so
        # the refcount really is balanced. But the link then cannot exit
        # hibern8 with those clocks actually off, and the host hangs at
        # power/runtime_status = "resuming" exactly like the guard-the-enable
        # version did.
        #
        # Conclusion: the second lane-clk reference is LOAD-BEARING, not a
        # leak. Both ways of balancing it (skip an enable, or add a disable)
        # hang the resume, so the AOSD blocker cannot be fixed by refcount
        # bookkeeping here. Freeing the XO vote needs the lane clocks genuinely
        # gated around hibern8 (or handed to the PHY), which is a deeper change.
        # ./patches/ufs-qcom-lane-clk-balance-disable.patch
        #
        # BOOT-TESTED AND KEPT -- this is the one that works:
        ./patches/ufs-qcom-lane-clks-only.patch
        #
        # BOOT-TESTED 2026-09-04 VIA `fastboot boot` (RAM, boot_a untouched):
        # IT ALSO WEDGES. ./patches/ufs-qcom-stock-call-sites.patch -- do not use.
        # Reason, and this closes the question: ufshcd's CLOCK GATING path
        # (ufshcd_gate_work -> hibern8 enter -> ufshcd_setup_clocks(false), and
        # ufshcd_ungate_work on the way back) goes through
        # ufs_qcom_setup_clocks() ONLY -- it never calls ufs_qcom_suspend/resume.
        # So mainline's extra enable/disable pair is not redundant with the
        # suspend/resume pair: it is the hook that serves clock gating. Remove it
        # and the lane clocks are never re-enabled on ungate, so the link cannot
        # exit hibern8 and the host hangs at runtime_status "resuming".
        # That also explains every earlier failure: the two pairs serve two
        # different callers (gating vs runtime/system PM), both fire for a
        # runtime cycle, and the count cannot be balanced by touching one side
        # without starving the other. A real fix has to make the gating path and
        # the PM path share one reference, not cancel each other.
        # Found by counting call sites against downstream: stock touches the
        # lane clocks from exactly FOUR places (enable in hce_enable_notify and
        # resume, disable in suspend and exit) and its setup_clocks() does not
        # touch them at all. Mainline adds a fifth and sixth inside
        # ufs_qcom_setup_clocks(), both conditional on is_link_hibern8 -- two
        # enables per resume against one effective disable per suspend. That is
        # the leak, AND it is why stock's is_lane_clks_enabled guard hangs here:
        # the setup_clocks enable is conditional, so when the link is not
        # hibern8 on resume that path does not enable and a guarded resume()
        # skips its enable too on a stale flag, leaving the lane clocks off.
        # Dropping the mainline-only pair makes the call sites identical to
        # downstream: 1 enable + 1 disable per cycle, count reaches 0, and no
        # path can skip an enable a resume needs.
        # Root cause found by diffing against downstream: mainline's
        # ufs_qcom_init_lane_clks() uses devm_clk_bulk_get_all(), taking ALL
        # NINE clocks in the ufshc node -- but core_clk/bus_aggr/iface/unipro/
        # ref/ice are already on hba->clk_list (ufshcd_parse_operating_points()
        # builds it from the same clock-names) and are enabled and gated by the
        # ufshcd core. They are therefore owned twice, and the variant's
        # reference is never released, which is what pins the XO. Downstream
        # holds only rx/tx_lane[01]_sync_clk. The patch narrows the variant to
        # the three lane sync clocks so the core's gating can reach zero.
        # This also explains why both refcount-balancing attempts hung: the
        # count was never the variant's to balance.
        # Measured with it applied: gcc_ufs_phy_ice_core_clk and
        # gcc_ufs_phy_axi_clk now sit at 0 while suspended and STAY 0 across
        # four forced suspend/resume cycles (previously 1, climbing to 5), and
        # the boot is healthy (load 0.8, 0 D-state, reaches the LUKS prompt).
        #
        # Residual, deliberately left alone: the three lane sync clocks the
        # variant still owns do still climb +1/cycle. Re-adding stock's
        # is_lane_clks_enabled guard on top of this narrowed clock set was
        # built and boot-tested to fix that -- and it STILL wedges the boot
        # (D-state 16, runtime_status "resuming"). So the guard cannot be
        # ported even with the correct clock set; mainline's call sites differ
        # from downstream's in some further way. Those symbol clocks are
        # parented to the UFS PHY PLL rather than gpll0, so they are not the
        # XO holder anyway.
        # Note: do NOT add freq-table-hz to the DT to "fix" the
        # "freq-table-hz property not specified" boot message -- that message is
        # benign (the legacy path declining), and
        # ufshcd_parse_operating_points() explicitly errors out with
        # "operating-points and freq-table-hz are incompatible", so adding it
        # breaks probe.
        # Tighter UFS idle timings (autosuspend 100ms, clkgate 10ms, AH8 5ms).
        # ./patches/ufs-qcom-idle-tuning.patch
        ./patches/sdm845-enchilada-bt-baud-min-svs.patch
        # Give uart6 an RX-edge wakeup IRQ + sleep pinctrl so the BT UART can
        # runtime-suspend and stop pinning CX at performance state 256.
        # Mirrors sc7180-trogdor; WCN3990 here has no host-wake GPIO.
        ./patches/sdm845-enchilada-uart6-wakeup.patch
        # NOT applied: allow-set-time does not work on this device. The driver
        # honours the property (rtc-pm8xxx.c) but TrustZone has the pm8998 RTC
        # counter locked, so the SPMI write is refused and RTC_SET_TIME still
        # fails. The RTC is read-only here; correcting the clock has to come
        # from NTP (and swclock-offset across reboots), not from writing the RTC.
        # ./patches/sdm845-enchilada-rtc-set-time.patch
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
        # Forward IMPLEMENTATION DEFINED sysreg traps to the VMM instead of
        # injecting undef, so a guest driving SoC-specific registers can run
        # under KVM. HCR_EL2.TIDCP traps the IMPDEF *encoding space*, which is
        # architectural, so this works on Kryo as much as on Apple cores --
        # the host CPU need not implement the registers at all; the VMM
        # emulates them. Same patch as the pc host carries.
        ./patches/kvm-arm-impdef-sysreg-to-user.patch
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
