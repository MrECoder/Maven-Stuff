#!/usr/bin/env bash
set -euo pipefail

MVN_VER="${1:-3.9.16}"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
TARBALL_URL_PRIMARY="https://dlcdn.apache.org/maven/maven-3/${MVN_VER}/binaries/apache-maven-${MVN_VER}-bin.tar.gz"
TARBALL_URL_ARCHIVE="https://archive.apache.org/dist/maven/maven-3/${MVN_VER}/binaries/apache-maven-${MVN_VER}-bin.tar.gz"
TMP_ARCHIVE="/tmp/apache-maven-${MVN_VER}-bin.tar.gz"

echo "Removing RHEL dnf maven package if installed (preserving ~/.m2)..."
if rpm -q maven >/dev/null 2>&1; then
  sudo dnf remove -y maven
fi

echo "Ensuring curl and tar are available..."
sudo dnf install -y curl tar

echo "Downloading Apache Maven ${MVN_VER}..."
if ! curl -fL "${TARBALL_URL_PRIMARY}" -o "${TMP_ARCHIVE}"; then
  echo "Primary mirror unavailable for ${MVN_VER}, trying Apache archive..."
  curl -fL "${TARBALL_URL_ARCHIVE}" -o "${TMP_ARCHIVE}"
fi

echo "Extracting Apache Maven ${MVN_VER} to /opt..."
sudo tar -xzf "${TMP_ARCHIVE}" -C /opt
sudo ln -sfn "/opt/apache-maven-${MVN_VER}" /opt/maven
rm -f "${TMP_ARCHIVE}"

echo "Locating Java 21 JDK..."
JAVA21_HOME="$(ls -d /usr/lib/jvm/java-21-openjdk* 2>/dev/null | head -n 1 || true)"
if [[ -z "${JAVA21_HOME}" ]]; then
  echo "Java 21 not found under /usr/lib/jvm; installing java-21-openjdk-devel..."
  sudo dnf install -y java-21-openjdk-devel
  JAVA21_HOME="$(ls -d /usr/lib/jvm/java-21-openjdk* | head -n 1)"
fi

echo "Configuring /etc/profile.d/maven.sh..."
sudo tee /etc/profile.d/maven.sh >/dev/null <<EOF
export JAVA_HOME="${JAVA21_HOME}"
export M2_HOME="/opt/maven"
export PATH="\${M2_HOME}/bin:\${PATH}"
EOF
sudo chmod 0644 /etc/profile.d/maven.sh

# Ensure non-login interactive shells for the target user also pick up JAVA_HOME
BASHRC_FILE="${TARGET_HOME}/.bashrc"
MARKER="# Maven 3.9.x & Java 21 environment"
if ! grep -qF "${MARKER}" "${BASHRC_FILE}" 2>/dev/null; then
  {
    echo ""
    echo "${MARKER}"
    echo "export JAVA_HOME=\"${JAVA21_HOME}\""
    echo "export M2_HOME=\"/opt/maven\""
    echo "export PATH=\"\${M2_HOME}/bin:\${PATH}\""
  } >> "${BASHRC_FILE}"
  chown "${TARGET_USER}:${TARGET_USER}" "${BASHRC_FILE}"
fi

export JAVA_HOME="${JAVA21_HOME}"
export M2_HOME="/opt/maven"
export PATH="${M2_HOME}/bin:${PATH}"

echo "Verifying installation..."
mvn -v
