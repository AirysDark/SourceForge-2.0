# SourceForge 2.0 — DietPi OS Image Builder

Builds a **DietPi-based** custom image that boots into SourceForge 2.0 using a first-boot **OS Pack**.
The workflow downloads the official DietPi Raspberry Pi 64-bit image, injects our OS Pack into the **boot** partition, and re-compresses it to `.img.xz`.

## What you get
- DietPi 64-bit base (fast/lean)
- First boot provisions Docker/Compose, firewall, log2ram, etc.
- Auto-installs your infra bundle if you place `sourceforge20-infra.zip` in `/boot/sf20/`

## Quick start (GitHub Actions)
- Go to Actions → **Build DietPi Image** → Run workflow
  - You can override the DietPi image URL if needed (defaults to Raspberry Pi arm64 Bookworm).

## Local build (Linux host)
```bash
sudo apt-get update && sudo apt-get install -y xz-utils kpartx qemu-utils dosfstools parted unzip curl git
chmod +x scripts/build-dietpi-image.sh
DIETPI_IMAGE_URL='<official dietpi img.xz>' ./scripts/build-dietpi-image.sh dist
```

## Flashing
- Download the artifact `.img.xz`, decompress, and flash to SD/SSD (Raspberry Pi Imager or `xz -d` + `dd`).
- On first boot it will provision and bring the platform online.
