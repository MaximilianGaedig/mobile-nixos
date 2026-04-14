/* NIXOS_BOOT_CFG - Mobile NixOS generation selection storage
 * Layout: 1MB misc partition divided into two 512KB blocks
 *   Block 0 (primary): offset 0
 *   Block 1 (backup): offset 524288
 * Format (75 bytes):
 *   0-13:   Magic "NIXOS_BOOT_CFG"
 *   14:     Null byte
 *   15:     Version (1)
 *   16:     Flags
 *   17-20:  Reserved
 *   21-74:  Path (null-terminated, max 53 chars)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#define MISC_PART_DEFAULT "/dev/disk/by-partlabel/misc"
#define BLOCK_SIZE 524288  /* 512KB */
#define CFG_SIZE 75
#define PATH_MAX 53

struct boot_config {
    uint8_t version;
    uint8_t flags;
    char path[PATH_MAX + 1];  /* +1 for null */
};

static const char MAGIC[] = "NIXOS_BOOT_CFG";

/* Read config from a specific block */
int read_block(int fd, int block_num, struct boot_config *cfg) {
    uint8_t buf[CFG_SIZE];
    off_t offset = (off_t)block_num * BLOCK_SIZE;
    
    if (lseek(fd, offset, SEEK_SET) != offset) {
        return -1;
    }
    
    ssize_t n = read(fd, buf, CFG_SIZE);
    if (n != CFG_SIZE) {
        return -1;
    }
    
    /* Check magic (bytes 0-14) */
    if (memcmp(buf, MAGIC, 14) != 0 || buf[14] != 0) {
        return -1;
    }
    
    /* Check version */
    if (buf[15] != 1) {
        return -1;
    }
    
    cfg->version = buf[15];
    cfg->flags = buf[16];
    
    /* Extract path (bytes 21-74) */
    memset(cfg->path, 0, sizeof(cfg->path));
    int path_len = 0;
    for (int i = 21; i < CFG_SIZE && path_len < PATH_MAX; i++) {
        if (buf[i] == 0) break;
        cfg->path[path_len++] = buf[i];
    }
    cfg->path[path_len] = '\0';
    
    return 0;
}

/* Read config, trying primary then backup */
int read_boot_cfg(const char *misc_path, struct boot_config *cfg, int *block_used) {
    int fd = open(misc_path, O_RDONLY);
    if (fd < 0) {
        return -1;
    }
    
    /* Try primary block (0) */
    if (read_block(fd, 0, cfg) == 0) {
        *block_used = 0;
        close(fd);
        return 0;
    }
    
    /* Try backup block (1) */
    if (read_block(fd, 1, cfg) == 0) {
        *block_used = 1;
        close(fd);
        return 0;
    }
    
    close(fd);
    return -1;
}

/* Write config to a block */
int write_block(int fd, int block_num, const struct boot_config *cfg) {
    uint8_t buf[CFG_SIZE];
    off_t offset = (off_t)block_num * BLOCK_SIZE;
    
    /* Clear buffer */
    memset(buf, 0, CFG_SIZE);
    
    /* Write magic */
    memcpy(buf, MAGIC, 14);
    buf[14] = 0;  /* null terminator */
    
    /* Write version and flags */
    buf[15] = cfg->version;
    buf[16] = cfg->flags;
    
    /* Reserved bytes 17-20 are already 0 */
    
    /* Write path (bytes 21-74) */
    int path_len = strlen(cfg->path);
    if (path_len > PATH_MAX) path_len = PATH_MAX;
    memcpy(buf + 21, cfg->path, path_len);
    
    if (lseek(fd, offset, SEEK_SET) != offset) {
        return -1;
    }
    
    ssize_t n = write(fd, buf, CFG_SIZE);
    if (n != CFG_SIZE) {
        return -1;
    }
    
    return 0;
}

/* Write config to both blocks */
int write_boot_cfg(const char *misc_path, const struct boot_config *cfg) {
    int fd = open(misc_path, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Error opening %s: %s\n", misc_path, strerror(errno));
        return -1;
    }
    
    /* Write to backup first (block 1) */
    if (write_block(fd, 1, cfg) != 0) {
        close(fd);
        fprintf(stderr, "Error writing backup block\n");
        return -1;
    }
    
    /* Then write to primary (block 0) */
    if (write_block(fd, 0, cfg) != 0) {
        close(fd);
        fprintf(stderr, "Error writing primary block\n");
        return -1;
    }
    
    close(fd);
    return 0;
}

/* Clear both blocks */
int clear_boot_cfg(const char *misc_path) {
    int fd = open(misc_path, O_RDWR);
    if (fd < 0) {
        return -1;
    }
    
    uint8_t zeros[CFG_SIZE];
    memset(zeros, 0, CFG_SIZE);
    
    /* Clear primary */
    lseek(fd, 0, SEEK_SET);
    write(fd, zeros, CFG_SIZE);
    
    /* Clear backup */
    lseek(fd, BLOCK_SIZE, SEEK_SET);
    write(fd, zeros, CFG_SIZE);
    
    close(fd);
    return 0;
}

void usage(const char *prog) {
    fprintf(stderr, "Usage: %s {read|write|clear} [args...]\n", prog);
    fprintf(stderr, "  read [misc_partition]\n");
    fprintf(stderr, "  write <flags> <path> [misc_partition]\n");
    fprintf(stderr, "  clear [misc_partition]\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        usage(argv[0]);
        return 1;
    }
    
    const char *cmd = argv[1];
    
    if (strcmp(cmd, "read") == 0) {
        const char *misc_path = (argc > 2) ? argv[2] : MISC_PART_DEFAULT;
        struct boot_config cfg;
        int block_used;
        
        if (read_boot_cfg(misc_path, &cfg, &block_used) != 0) {
            return 1;
        }
        
        printf("%d %d %s %d\n", cfg.version, cfg.flags, cfg.path, block_used);
        return 0;
    }
    else if (strcmp(cmd, "write") == 0) {
        if (argc < 4) {
            usage(argv[0]);
            return 1;
        }
        
        struct boot_config cfg;
        cfg.version = 1;
        cfg.flags = atoi(argv[2]);
        strncpy(cfg.path, argv[3], PATH_MAX);
        cfg.path[PATH_MAX] = '\0';
        
        const char *misc_path = (argc > 4) ? argv[4] : MISC_PART_DEFAULT;
        
        if (write_boot_cfg(misc_path, &cfg) != 0) {
            return 1;
        }
        return 0;
    }
    else if (strcmp(cmd, "clear") == 0) {
        const char *misc_path = (argc > 2) ? argv[2] : MISC_PART_DEFAULT;
        
        if (clear_boot_cfg(misc_path) != 0) {
            return 1;
        }
        return 0;
    }
    else {
        usage(argv[0]);
        return 1;
    }
}
