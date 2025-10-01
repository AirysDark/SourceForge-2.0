# SourceForge 2.0 drop-in for DietPi build tree

This folder (`sf20/`) is additive. It doesn't change existing DietPi files.
It provides:
- `overlay/` : files copied into the target **rootfs** (tty1 override, banner, sfsh launcher)
- `boot-side/sf20/` : files copied into the **boot** (e.g., `sf20.repourl`)
- `shell/` : minimal `sfsh.c` + Makefile (replace with your full shell)
- `scripts/sf20-apply-to-rootfs.sh` : apply overlay to a mounted image

## Typical usage

1. Build or mount your DietPi/OS image so ROOTFS and BOOT are mounted at:
   - `/mnt/root`
   - `/mnt/boot`

2. From the repo root:
   ```bash
   sudo ./sf20/scripts/sf20-apply-to-rootfs.sh /mnt/root /mnt/boot
   ```

3. Unmount, pack, and flash. On first console (tty1), the system will launch
   `/usr/local/bin/sourceforge-term` which starts your `sfsh`.

## Notes
- Replace `sf20/shell/sfsh.c` with your real implementation; then run:
  ```bash
  cd sf20/shell && make && make install
  ```
- Plymouth theme is included as minimal; feel free to replace assets/script.
