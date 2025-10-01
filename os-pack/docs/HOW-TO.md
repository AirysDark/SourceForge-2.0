# SourceForge 2.0 — OS Pack (All-in-One)

## Apply to mounted image
```bash
# ROOTFS mount at /mnt/imgroot, BOOT (FAT) at /mnt/imgboot

sudo rsync -a os-pack/all-in-one/etc/  /mnt/imgroot/etc/
sudo rsync -a os-pack/all-in-one/usr/  /mnt/imgroot/usr/
sudo rsync -a os-pack/all-in-one/logo/ /mnt/imgroot/usr/share/sourceforge-logo/  # optional

sudo rsync -a os-pack/boot-side/sf20/  /mnt/imgboot/sf20/
sudo systemctl enable sf20-firstboot.service --root=/mnt/imgroot
```

## First boot behavior
- Autoclones repo URL from `/boot/sf20/sf20.repourl`
- Installs Terminal to /opt/sf20-terminal; Shell to /usr/local/bin/chipsh
- Sets Plymouth splash with logo
- Generates ASCII MOTD from logo
- Auto-starts Terminal (spawns chipsh) for TTY/SSH logins

## Optional kiosk on tty1
```bash
sudo systemctl disable --now getty@tty1.service
sudo systemctl enable --now sf20-terminal-tty1.service
```
