# SourceForge 2.0 — OS Image (GitHub Actions)

This repo builds a **flashable Raspberry Pi OS image** (`.img.xz`) using **pi-gen (Docker)** in GitHub Actions.

## Usage (locally)
```bash
sudo apt-get update && sudo apt-get install -y qemu-user-static kpartx xz-utils dosfstools git
./scripts/build-pigen.sh --model pi4 --variant lite --outdir dist
ls dist/
```

## GitHub Actions
- See `.github/workflows/build-image.yml`.
- Trigger via **workflow_dispatch** inputs (model/variant) or on **tag**.
