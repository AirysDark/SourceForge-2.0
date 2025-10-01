# SourceForge 2.0 Fork Toolkit

Use this to convert a DietPi-based build into a native SF20 build (owning tty1/shell; removing DietPi branding).

## Steps in CI
1. After rootfs is mounted at /mnt/imgroot and boot at /mnt/imgboot:
   ```bash
   rsync -a overlay/ /mnt/imgroot/
   ROOT=/mnt/imgroot BOOT=/mnt/imgboot ./tools/neutralize-dietpi.sh
   ```
2. Unmount, compress, and flash.

Ensure your `/usr/local/bin/sfsh` exists (compile/install your shell) or the terminal will fallback to `/bin/bash -l`.
