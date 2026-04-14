#!/bin/sh
# Tests for NIXOS_BOOT_CFG C implementation

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/nixos-boot-cfg"

TEST_MISC="/tmp/test_misc_partition_$$"
PASSED=0
FAILED=0

pass() { echo "✓ $1"; PASSED=$((PASSED + 1)); }
fail() { echo "✗ $1"; FAILED=$((FAILED + 1)); }

# Test 1: Basic write/read
echo "Test 1: Basic write/read"
dd if=/dev/zero of="$TEST_MISC" bs=1M count=1 2>/dev/null
"$BIN" write 5 "/nix/var/nix/profiles/system-123" "$TEST_MISC"
if result=$("$BIN" read "$TEST_MISC"); then
    read version flags path copy <<< "$result"
    if [ "$version" = "1" ] && [ "$flags" = "5" ] && [ "$path" = "/nix/var/nix/profiles/system-123" ] && [ "$copy" = "0" ]; then
        pass "Basic write/read"
    else
        fail "Basic write/read: version=$version flags=$flags path=$path copy=$copy"
    fi
else
    fail "Basic write/read: read failed"
fi

# Test 2: Backup fallback
echo "Test 2: Backup fallback"
dd if=/dev/zero of="$TEST_MISC" bs=1M count=1 2>/dev/null
"$BIN" write 3 "/test/path" "$TEST_MISC"
# Corrupt primary block (first 16 bytes)
printf 'CORRUPTED_DATA!!' | dd of="$TEST_MISC" bs=1 count=16 conv=notrunc 2>/dev/null
if result=$("$BIN" read "$TEST_MISC"); then
    read version flags path copy <<< "$result"
    if [ "$copy" = "1" ] && [ "$flags" = "3" ]; then
        pass "Backup fallback"
    else
        fail "Backup fallback: copy=$copy flags=$flags"
    fi
else
    fail "Backup fallback: read failed"
fi

# Test 3: Both blocks corrupted
echo "Test 3: Both blocks corrupted"
dd if=/dev/zero of="$TEST_MISC" bs=1M count=1 2>/dev/null
"$BIN" write 1 "/test" "$TEST_MISC"
printf 'CORRUPTED_DATA!!' | dd of="$TEST_MISC" bs=1 count=16 conv=notrunc 2>/dev/null
printf 'CORRUPTED_DATA!!' | dd of="$TEST_MISC" bs=1 seek=524288 count=16 conv=notrunc 2>/dev/null
if ! "$BIN" read "$TEST_MISC" 2>/dev/null; then
    pass "Both corrupted detection"
else
    fail "Both corrupted detection"
fi

# Test 4: Clear
echo "Test 4: Clear"
dd if=/dev/zero of="$TEST_MISC" bs=1M count=1 2>/dev/null
"$BIN" write 1 "/test" "$TEST_MISC"
"$BIN" clear "$TEST_MISC"
if ! "$BIN" read "$TEST_MISC" 2>/dev/null; then
    pass "Clear operation"
else
    fail "Clear operation"
fi

# Test 5: Long path (max 53 chars)
echo "Test 5: Long path"
dd if=/dev/zero of="$TEST_MISC" bs=1M count=1 2>/dev/null
long_path="/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-link"  # 53 chars
"$BIN" write 0 "$long_path" "$TEST_MISC"
if result=$("$BIN" read "$TEST_MISC"); then
    read version flags path copy <<< "$result"
    if [ "$path" = "$long_path" ]; then
        pass "Long path"
    else
        fail "Long path: expected length ${#long_path}, got ${#path}"
    fi
else
    fail "Long path: read failed"
fi

# Cleanup
rm -f "$TEST_MISC"

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ] && exit 0 || exit 1
