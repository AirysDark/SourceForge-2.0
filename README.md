# SourceForge 2.0 — OS Image (GitHub Actions)

This repo builds a **flashable Raspberry Pi OS image** (`.img.xz`) using **pi-gen (Docker)** in GitHub Actions and **publishes it to GitHub Releases on tags**.

## Build locally
```bash
sudo apt-get update && sudo apt-get install -y qemu-user-static kpartx xz-utils dosfstools git
chmod +x scripts/build-pigen.sh
./scripts/build-pigen.sh --model pi4 --variant lite --outdir dist
ls dist/
```

## Build in GitHub
- Manual: Actions → **Build OS Image** → Run workflow (choose model/variant).
- Release: create a tag, e.g.
  ```bash
  git tag v0.1.0
  git push --tags
  ```
  The workflow will build and **attach** the `.img.xz` and `checksums.txt` to that Release automatically.
