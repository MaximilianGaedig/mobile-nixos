#!/usr/bin/env python3
"""NIXOS_BOOT_CFG - Mobile NixOS generation selection storage

Layout: 1MB misc partition divided into two 512KB blocks
  Block 0 (primary): offset 0, contains config at start
  Block 1 (backup): offset 524288, contains config at start

Format (75 bytes):
  0-13:   Magic "NIXOS_BOOT_CFG"
  14:     Null byte
  15:     Version (1)
  16:     Flags
  17-20:  Reserved
  21-74:  Path (null-terminated, max 53 chars)
"""

import sys
import os
import struct

MISC_PART = "/dev/disk/by-partlabel/misc"
BLOCK_SIZE = 524288  # 512KB
CFG_SIZE = 75


class BootConfig:
    def __init__(self, flags=0, path=""):
        self.version = 1
        self.flags = flags
        self.path = path[:53]  # Max 53 chars

    def to_bytes(self):
        """Serialize to 75 bytes"""
        data = b"NIXOS_BOOT_CFG\x00"  # 15 bytes
        data += struct.pack("B", self.version)  # 1 byte
        data += struct.pack("B", self.flags)  # 1 byte
        data += b"\x00\x00\x00\x00"  # 4 bytes reserved
        path_bytes = self.path.encode("utf-8")
        data += path_bytes  # path
        data += b"\x00" * (54 - len(path_bytes))  # padding
        return data

    @classmethod
    def from_bytes(cls, data):
        """Deserialize from bytes"""
        if len(data) < 22:
            return None
        if data[:15] != b"NIXOS_BOOT_CFG\x00":
            return None
        if data[15] != 1:
            return None

        config = cls()
        config.version = data[15]
        config.flags = data[16]
        # Extract path up to first null
        path_bytes = data[21:75]
        null_idx = path_bytes.find(b"\x00")
        if null_idx >= 0:
            path_bytes = path_bytes[:null_idx]
        config.path = path_bytes.decode("utf-8", errors="replace")
        return config


def read_boot_cfg(misc_path=MISC_PART):
    """Read config, trying primary then backup"""
    for block_num in [0, 1]:
        offset = block_num * BLOCK_SIZE
        try:
            with open(misc_path, "rb") as f:
                f.seek(offset)
                data = f.read(CFG_SIZE)
                if len(data) >= CFG_SIZE:
                    config = BootConfig.from_bytes(data)
                    if config:
                        return config, block_num
        except (IOError, OSError):
            pass
    return None, None


def write_boot_cfg(flags, path, misc_path=MISC_PART):
    """Write config to both blocks"""
    config = BootConfig(flags, path)
    data = config.to_bytes()

    try:
        # Write to backup first (block 1)
        with open(misc_path, "r+b") as f:
            f.seek(BLOCK_SIZE)
            f.write(data)

        # Then write to primary (block 0)
        with open(misc_path, "r+b") as f:
            f.seek(0)
            f.write(data)

        return True
    except (IOError, OSError) as e:
        print(f"Error writing: {e}", file=sys.stderr)
        return False


def clear_boot_cfg(misc_path=MISC_PART):
    """Clear both blocks"""
    try:
        zeros = b"\x00" * CFG_SIZE
        with open(misc_path, "r+b") as f:
            f.seek(0)
            f.write(zeros)
            f.seek(BLOCK_SIZE)
            f.write(zeros)
        return True
    except (IOError, OSError):
        return False


def main():
    if len(sys.argv) < 2:
        print("Usage: nixos-boot-cfg {read|write|clear} [args...]", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    misc_path = MISC_PART if len(sys.argv) < 4 else sys.argv[-1]

    if cmd == "read":
        config, block = read_boot_cfg(misc_path)
        if config:
            print(f"{config.version} {config.flags} {config.path} {block}")
            sys.exit(0)
        else:
            sys.exit(1)

    elif cmd == "write":
        if len(sys.argv) < 4:
            print(
                "Usage: nixos-boot-cfg write <flags> <path> [misc_partition]",
                file=sys.stderr,
            )
            sys.exit(1)
        flags = int(sys.argv[2])
        path = sys.argv[3]
        if write_boot_cfg(flags, path, misc_path):
            sys.exit(0)
        else:
            sys.exit(1)

    elif cmd == "clear":
        if clear_boot_cfg(misc_path):
            sys.exit(0)
        else:
            sys.exit(1)

    else:
        print("Unknown command", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
