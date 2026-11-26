# Maven-Stuff
Learning
#!/usr/bin/env bash
set -euo pipefail

# Fetches the latest official Linux x86_64 release via JetBrains' data service API
PRODUCT_CODE="IIU"
ARCH_TYPE="linux"
INSTALL_DIR="/opt/idea"
DESKTOP_FILE="/usr/share/applications/jetbrains-idea.desktop"
TMP_ARCHIVE="/tmp/intellij-idea.tar.gz"

echo "Ensuring required GUI and archive dependencies are installed..."
sudo dnf install -y curl tar jq libXi libXrender libXtst mesa-libGL fontconfig gtk3 dbus-x11

echo "Resolving latest IntelliJ IDEA Linux download URL..."
DOWNLOAD_URL="$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=${PRODUCT_CODE}&latest=true&type=release" \
  | jq -r ".${PRODUCT_CODE}[0].downloads.${ARCH_TYPE}.link")"

if [[ -z "${DOWNLOAD_URL}" || "${DOWNLOAD_URL}" == "null" ]]; then
  echo "Error: Could not resolve download URL from JetBrains API (check proxy/network settings)." >&2
  exit 1
fi

echo "Downloading IntelliJ IDEA from ${DOWNLOAD_URL}..."
curl -fL "${DOWNLOAD_URL}" -o "${TMP_ARCHIVE}"

echo "Extracting to ${INSTALL_DIR}..."
sudo rm -rf "${INSTALL_DIR}"
sudo mkdir -p "${INSTALL_DIR}"
sudo tar -xzf "${TMP_ARCHIVE}" -C "${INSTALL_DIR}" --strip-components=1
rm -f "${TMP_ARCHIVE}"

# Determine launcher path (newer builds use bin/idea, older builds use bin/idea.sh)
if [[ -x "${INSTALL_DIR}/bin/idea" ]]; then
  LAUNCHER_BIN="${INSTALL_DIR}/bin/idea"
else
  LAUNCHER_BIN="${INSTALL_DIR}/bin/idea.sh"
fi

echo "Creating CLI symlink at /usr/local/bin/idea..."
sudo ln -sfn "${LAUNCHER_BIN}" /usr/local/bin/idea

echo "Creating GNOME desktop entry at ${DESKTOP_FILE}..."
sudo tee "${DESKTOP_FILE}" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=IntelliJ IDEA
Icon=${INSTALL_DIR}/bin/idea.svg
Exec="${LAUNCHER_BIN}" %f
Comment=Capable and Ergonomic IDE for JVM
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-idea
EOF
sudo chmod 0644 "${DESKTOP_FILE}"

echo "Refreshing GNOME desktop database..."
sudo update-desktop-database /usr/share/applications || true

echo "Done! Launch from your GNOME menu ('IntelliJ IDEA') or run 'id
