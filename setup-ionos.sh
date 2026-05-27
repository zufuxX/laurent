#!/usr/bin/env bash
# Deploys the Laurent landing into the current directory on IONOS shared hosting.
# - Downloads the site (index.html + assets/) from the GitHub repo
# - Downloads the 21 release assets (11 videos + 10 posters) from the 'video' release
# - Rewrites GitHub release URLs to local paths so the site is self-contained
#
# Usage:
#   cd <your web root, e.g. ~/clickandbuilds/.../htdocs or the SFTP-visible root>
#   bash setup-ionos.sh

set -euo pipefail

REPO_OWNER="zufuxX"
REPO_NAME="laurent"
BRANCH="main"
RELEASE_TAG="video"

TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${BRANCH}"
RELEASE_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${RELEASE_TAG}"

ASSETS=(
  "Laurent-AD-2-MARCH-16x9-V2-3.0-1-1.mp4"
  "1121918109573617579.mp4"
  "6384095669297019611.mp4"
  "6558032911724197109.mp4"
  "8081570164809603681.mp4"
  "2361001382051135526.mp4"
  "6466513923254840847.mp4"
  "6739530346655125588.mp4"
  "7623927145088295110.mp4"
  "3933786284258965989.mp4"
  "9049707018635018892.mp4"
  "17.jpg" "18.jpg" "19.jpg" "20.jpg" "21.jpg"
  "22.jpg" "23.jpg" "24.jpg" "25.jpg" "EMILIE.jpg"
)

echo "==> Working dir: $(pwd)"

# 0) If a WordPress install is present, move it aside (do not delete)
if [ -f wp-config.php ] || [ -f wp-login.php ] || [ -d wp-admin ] || [ -d wp-includes ]; then
  BACKUP_DIR="_wp_backup_$(date +%Y%m%d_%H%M%S)"
  echo "==> WordPress detected. Moving existing files to ${BACKUP_DIR}/ ..."
  mkdir "$BACKUP_DIR"
  # Move every entry in cwd into the backup, except the script itself and the backup dir
  shopt -s dotglob nullglob
  for entry in *; do
    case "$entry" in
      "$BACKUP_DIR"|setup-ionos.sh|_wp_backup_*) continue ;;
    esac
    mv -- "$entry" "$BACKUP_DIR/"
  done
  shopt -u dotglob nullglob
  echo "    Backup created. Once the new site is verified, remove it with:"
  echo "    rm -rf ${BACKUP_DIR}"
fi

# 1) Download and extract the site tarball
echo "==> Downloading site from GitHub (${BRANCH})..."
curl -fL --retry 4 --retry-delay 2 -o /tmp/laurent-site.tgz "$TARBALL_URL"
tar -xzf /tmp/laurent-site.tgz -C /tmp
SRC_DIR="/tmp/${REPO_NAME}-${BRANCH}"

# Copy everything except .git, README and this script
echo "==> Installing files into $(pwd)..."
rsync -a --exclude='.git*' --exclude='README.md' --exclude='setup-ionos.sh' "${SRC_DIR}/" ./
rm -rf /tmp/laurent-site.tgz "${SRC_DIR}"

# 2) Download release assets into assets/media/
mkdir -p assets/media
echo "==> Downloading 21 release assets (~285 MB) into assets/media/..."
for f in "${ASSETS[@]}"; do
  if [ -s "assets/media/$f" ]; then
    echo "  - $f (already present, skipped)"
  else
    echo "  - $f"
    curl -fL --retry 4 --retry-delay 2 -o "assets/media/$f" "${RELEASE_BASE}/$f"
  fi
done

# 3) Rewrite GitHub release URLs to local paths
echo "==> Rewriting URLs in index.html..."
sed -i.bak "s|https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${RELEASE_TAG}/|assets/media/|g" index.html
rm -f index.html.bak

echo "==> Done. Visit your domain to verify."
