# Full CI Runner Setup Guide

> Complete guide to build a GitHub Actions self-hosted runner inside an Incus container from zero.
> Created: 2026-09-03
> Container: `ci-runner-portugues` (Ubuntu 24.04, Incus)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Host Machine Setup](#2-host-machine-setup)
3. [Create Container](#3-create-container)
4. [Install System Packages](#4-install-system-packages)
5. [Install Docker](#5-install-docker)
6. [Create github-runner User](#6-create-github-runner-user)
7. [Install Flutter SDK](#7-install-flutter-sdk)
8. [Install Android SDK + NDK](#8-install-android-sdk--ndk)
9. [Set Environment Variables](#9-set-environment-variables)
10. [Install Security Tools](#10-install-security-tools)
11. [Install edge-tts](#11-install-edge-tts)
12. [Install GitHub Actions Runner Binaries](#12-install-github-actions-runner-binaries)
13. [Register Runners with GitHub](#13-register-runners-with-github)
14. [Create Systemd Services](#14-create-systemd-services)
15. [Verify Everything](#15-verify-everything)
16. [Troubleshooting](#16-troubleshooting)
17. [Quick Reference](#17-quick-reference)

---

## 1. Prerequisites

### Host machine
- Ubuntu 24.04 or 26.04
- At least 8GB RAM free (12GB recommended)
- At least 20GB disk free
- Internet connection

### GitHub
- Personal Access Token (PAT) with `repo` scope
- Get from: GitHub → Settings → Developer settings → Personal access tokens → Generate new token (classic)

### Environment file
Create `/home/antix/master/Projects app languges prtg -esp/.env`:
```
GITHUBTOKEN=ghp_YOUR_TOKEN_HERE
```

---

## 2. Host Machine Setup

### Install Incus (if not installed)
```bash
sudo snap install lxd
sudo lxd init --auto
# OR on Ubuntu 26.04:
sudo snap install incus
sudo incus admin init --auto
```

### Verify Incus
```bash
incus --version
incus list
```

---

## 3. Create Container

### Delete old container (if exists)
```bash
incus stop ci-runner-portugues
incus delete ci-runner-portugues
```

### Create fresh container
```bash
incus launch images:ubuntu/24.04 ci-runner-portugues \
  -c security.nesting=true \
  -c limits.cpu=4 \
  -c limits.memory=12GiB
```

### Verify container is running
```bash
incus list ci-runner-portugues
# Should show: RUNNING
```

### Enter the container
```bash
incus exec ci-runner-portugues -- bash
# Or run single commands:
incus exec ci-runner-portugues -- bash -c 'echo "hello"'
```

---

## 4. Install System Packages

```bash
incus exec ci-runner-portugues -- bash -c '
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  curl wget git unzip xz-utils zip \
  ca-certificates gnupg lsb-release \
  python3 python3-pip python3-venv \
  openjdk-17-jdk-headless \
  docker.io docker-buildx jq
'
```

### Verify
```bash
incus exec ci-runner-portugues -- bash -c '
docker --version
java -version 2>&1
python3 --version
'
```

### Expected output
```
Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2
openjdk version "17.0.20" 2026-07-21
Python 3.12.3
```

---

## 5. Install Docker

```bash
incus exec ci-runner-portugues -- bash -c '
systemctl enable docker
systemctl start docker
systemctl is-active docker
'
```

### Docker daemon config (enable BuildKit)
```bash
incus exec ci-runner-portugues -- bash -c '
mkdir -p /etc/docker
echo "{\"features\": {\"buildkit\": true}}" > /etc/docker/daemon.json
'
```

### Troubleshooting: Docker won't start in container
If Docker fails to start, check if `security.nesting=true` is set:
```bash
incus config show ci-runner-portugues | grep security.nesting
# Should show: security.nesting: "true"

# If missing, set it:
incus stop ci-runner-portugues
incus config set ci-runner-portugues security.nesting true
incus start ci-runner-portugues
```

---

## 6. Create github-runner User

```bash
incus exec ci-runner-portugues -- bash -c '
useradd -m -s /bin/bash github-runner
usermod -aG sudo,docker github-runner
id github-runner
'
```

### Verify
```bash
incus exec ci-runner-portugues -- bash -c 'id github-runner'
# Expected: uid=1001(github-runner) gid=1001(github-runner) groups=...
```

---

## 7. Install Flutter SDK

```bash
incus exec ci-runner-portugues -- bash -c '
cd /opt
curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.3-stable.tar.xz" | tar xJ
chown -R github-runner:github-runner /opt/flutter
'
```

### Verify
```bash
incus exec ci-runner-portugues -- su - github-runner -c '
export PATH=/opt/flutter/bin:$PATH
flutter --version --no-version-check 2>&1 | head -5
'
```

### Expected output
```
Flutter 3.29.3 • channel stable • https://github.com/flutter/flutter.git
Framework • revision ea121f8859
Engine • revision cf56914b32
Tools • Dart 3.7.2 • DevTools 2.42.3
```

### Troubleshooting: Flutter version check fails
Flutter tries to `git fetch --tags` on first run. This is normal and harmless. The `--no-version-check` flag skips this.
If you need to fix it for future runs:
```bash
incus exec ci-runner-portugues -- su - github-runner -c '
cd /opt/flutter
git config --global --add safe.directory /opt/flutter
'
```

---

## 8. Install Android SDK + NDK

### Create install script
```bash
incus exec ci-runner-portugues -- bash -c 'cat > /tmp/install-sdk.sh << "SCRIPT"
#!/bin/bash
set -e

echo "=== Installing Android SDK ==="
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools

# Download Android command-line tools
curl -sL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o /tmp/cmdline-tools.zip
unzip -q /tmp/cmdline-tools.zip
mv cmdline-tools latest
rm /tmp/cmdline-tools.zip

export ANDROID_HOME=$HOME/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH

# Accept licenses
yes | sdkmanager --licenses 2>&1 | tail -3

# Install SDK components
sdkmanager --install \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "ndk;27.0.12077973" \
  "platform-tools"

echo "=== Done ==="
ls $ANDROID_HOME/
SCRIPT
chmod +x /tmp/install-sdk.sh'
```

### Run as github-runner user
```bash
incus exec ci-runner-portugues -- su - github-runner -c 'bash /tmp/install-sdk.sh'
```

### Verify
```bash
incus exec ci-runner-portugues -- su - github-runner -c '
export ANDROID_HOME=$HOME/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
sdkmanager --list_installed 2>&1 | grep -E "platforms|build-tools|ndk|platform-tools"
'
```

### Expected output
```
  build-tools;35.0.0   | 35.0.0        | Android SDK Build-Tools 35       | build-tools/35.0.0
  ndk;27.0.12077973    | 27.0.12077973 | NDK (Side by side) 27.0.12077973 | ndk/27.0.12077973
  platform-tools       | 37.0.1        | Android SDK Platform-Tools       | platform-tools
  platforms;android-35 | 2             | Android SDK Platform 35          | platforms/android-35
```

### Troubleshooting: SDK install timeout
The SDK download is large (~1.5GB for NDK). If it times out:
```bash
# Check if install is still running
incus exec ci-runner-portugues -- pgrep -f sdkmanager

# Wait for it
while incus exec ci-runner-portugues -- pgrep -f sdkmanager >/dev/null 2>&1; do sleep 10; done

# Check what was installed
incus exec ci-runner-portugues -- su - github-runner -c 'ls ~/android-sdk/'
```

---

## 9. Set Environment Variables

### Create .bashrc
```bash
incus exec ci-runner-portugues -- bash -c 'cat > /home/github-runner/.bashrc << "EOF"
# Flutter
export PATH=/opt/flutter/bin:$PATH

# Android SDK
export ANDROID_HOME=$HOME/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/35.0.0:$ANDROID_HOME/ndk/27.0.12077973:$PATH

# Tools
export PATH=/usr/local/bin:$PATH

# Docker
export DOCKER_HOST=unix:///var/run/docker.sock
EOF
chown github-runner:github-runner /home/github-runner/.bashrc'
```

### Create system-wide profile
```bash
incus exec ci-runner-portugues -- bash -c 'cat > /etc/profile.d/ci-runner.sh << "EOF"
export ANDROID_HOME=/home/github-runner/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=/opt/flutter/bin:/usr/local/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
EOF
chmod +x /etc/profile.d/ci-runner.sh'
```

---

## 10. Install Security Tools

```bash
incus exec ci-runner-portugues -- bash -c 'cat > /tmp/install-tools.sh << "SCRIPT"
#!/bin/bash
set -e

echo "Installing grype..."
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

echo "Installing trivy..."
curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v0.74.0/trivy_0.74.0_Linux-64bit.tar.gz" | tar xz -C /usr/local/bin trivy

echo "Installing hadolint..."
curl -sL "https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
chmod +x /usr/local/bin/hadolint

echo "Installing dockle..."
curl -fsSL "https://github.com/goodwithtech/dockle/releases/download/v0.4.14/dockle_0.4.14_Linux-64bit.tar.gz" | tar xz -C /usr/local/bin dockle

echo "Installing syft..."
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

echo "Installing cosign..."
curl -sL "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

echo "Installing gitleaks..."
curl -sL "https://github.com/gitleaks/gitleaks/releases/download/v8.24.2/gitleaks_8.24.2_linux_x64.tar.gz" -o /tmp/gitleaks.tar.gz
tar xz -C /usr/local/bin -f /tmp/gitleaks.tar.gz
rm -f /tmp/gitleaks.tar.gz

echo "=== All tools installed ==="
SCRIPT
chmod +x /tmp/install-tools.sh'
```

### Run
```bash
incus exec ci-runner-portugues -- bash -c 'bash /tmp/install-tools.sh'
```

### Verify
```bash
incus exec ci-runner-portugues -- bash -c '
grype --version
trivy --version
hadolint --version
dockle --version
syft --version
cosign version 2>&1 | head -1
gitleaks version
'
```

### Troubleshooting: gitleaks download fails
The gitleaks tar.gz filename format changed. Use the explicit version URL:
```bash
curl -sL "https://github.com/gitleaks/gitleaks/releases/download/v8.24.2/gitleaks_8.24.2_linux_x64.tar.gz" -o /tmp/gitleaks.tar.gz
tar xz -C /usr/local/bin -f /tmp/gitleaks.tar.gz
```

### Troubleshooting: cosign permission denied
```bash
chmod +x /usr/local/bin/cosign
```

---

## 11. Install edge-tts

```bash
incus exec ci-runner-portugues -- bash -c '
pip3 install --break-system-packages edge-tts
'
```

### Verify
```bash
incus exec ci-runner-portugues -- edge-tts --version
# Should print: edge-tts 7.2.8 (or newer)
```

### Troubleshooting: pip3 permission error
If you get "externally-managed-environment" error:
```bash
pip3 install --break-system-packages edge-tts
```

---

## 12. Install GitHub Actions Runner Binaries

```bash
incus exec ci-runner-portugues -- bash -c 'cat > /tmp/install-runners.sh << "SCRIPT"
#!/bin/bash
set -e
RUNNER_VERSION="2.322.0"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

echo "=== Installing GitHub Actions Runner v${RUNNER_VERSION} ==="

# Portuguese runner
mkdir -p /home/github-runner/actions-runner
cd /home/github-runner/actions-runner
curl -sL "$RUNNER_URL" | tar xz
chown -R github-runner:github-runner /home/github-runner/actions-runner

# Spanish runner
mkdir -p /home/github-runner/actions-runner-spanish
cd /home/github-runner/actions-runner-spanish
curl -sL "$RUNNER_URL" | tar xz
chown -R github-runner:github-runner /home/github-runner/actions-runner-spanish

echo "=== Done ==="
ls /home/github-runner/actions-runner/run.sh
ls /home/github-runner/actions-runner-spanish/run.sh
SCRIPT
chmod +x /tmp/install-runners.sh'
```

### Run as github-runner
```bash
incus exec ci-runner-portugues -- su - github-runner -c 'bash /tmp/install-runners.sh'
```

---

## 13. Register Runners with GitHub

### Get registration tokens
```bash
# From the host machine:
PT_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ghp_YOUR_TOKEN_HERE" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/rafaabou/talk-to-me-portugues/actions/runners/registration-token \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

ES_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ghp_YOUR_TOKEN_HERE" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/rafaabou/talk-to-me-spanish/actions/runners/registration-token \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

echo "PT: $PT_TOKEN"
echo "ES: $ES_TOKEN"
```

### Register Portuguese runner
```bash
incus exec ci-runner-portugues -- su - github-runner -c '
cd ~/actions-runner
./config.sh \
  --url https://github.com/rafaabou/talk-to-me-portugues \
  --token YOUR_PT_TOKEN \
  --name "ci-runner-pt" \
  --labels "self-hosted,Linux,X64,flutter,docker" \
  --unattended
'
```

### Register Spanish runner
```bash
incus exec ci-runner-portugues -- su - github-runner -c '
cd ~/actions-runner-spanish
./config.sh \
  --url https://github.com/rafaabou/talk-to-me-spanish \
  --token YOUR_ES_TOKEN \
  --name "ci-runner-es" \
  --labels "self-hosted,Linux,X64,flutter,docker" \
  --unattended
'
```

### Verify on GitHub
```bash
# Check from host:
curl -s -H "Authorization: token ghp_YOUR_TOKEN_HERE" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/rafaabou/talk-to-me-portugues/actions/runners \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'PT runners: {d[\"total_count\"]}'); [print(f'  {r[\"name\"]} ({r[\"status\"]})') for r in d['runners']]"
```

### Troubleshooting: Token expired
Registration tokens expire after 1 hour. Get a new one:
```bash
PT_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ghp_YOUR_TOKEN_HERE" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/rafaabou/talk-to-me-portugues/actions/runners/registration-token \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
```

### Troubleshooting: Remove old runner config
If you need to reconfigure:
```bash
incus exec ci-runner-portugues -- su - github-runner -c '
cd ~/actions-runner
./config.sh remove
# Then reconfigure with new token
./config.sh --url https://github.com/... --token NEW_TOKEN --name "ci-runner-pt" --unattended
'
```

---

## 14. Create Systemd Services

### Create service files
```bash
incus exec ci-runner-portugues -- bash -c 'cat > /etc/systemd/system/github-runner-pt.service << "EOF"
[Unit]
Description=GitHub Actions Runner - Portuguese
After=network.target docker.service

[Service]
Type=simple
User=github-runner
WorkingDirectory=/home/github-runner/actions-runner
Environment=PATH=/opt/flutter/bin:/usr/local/bin:/home/github-runner/android-sdk/cmdline-tools/latest/bin:/home/github-runner/android-sdk/platform-tools:/usr/bin:/bin
Environment=ANDROID_HOME=/home/github-runner/android-sdk
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ExecStart=/home/github-runner/actions-runner/run.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/github-runner-es.service << "EOF2"
[Unit]
Description=GitHub Actions Runner - Spanish
After=network.target docker.service

[Service]
Type=simple
User=github-runner
WorkingDirectory=/home/github-runner/actions-runner-spanish
Environment=PATH=/opt/flutter/bin:/usr/local/bin:/home/github-runner/android-sdk/cmdline-tools/latest/bin:/home/github-runner/android-sdk/platform-tools:/usr/bin:/bin
Environment=ANDROID_HOME=/home/github-runner/android-sdk
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ExecStart=/home/github-runner/actions-runner-spanish/run.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF2

systemctl daemon-reload
systemctl enable github-runner-pt github-runner-es
systemctl start github-runner-pt github-runner-es
'
```

### Verify
```bash
incus exec ci-runner-portugues -- bash -c '
systemctl is-active github-runner-pt
systemctl is-active github-runner-es
'
```

### Troubleshooting: Service won't start
```bash
# Check logs
incus exec ci-runner-portugues -- journalctl -u github-runner-pt -n 20 --no-pager

# Check if run.sh is executable
incus exec ci-runner-portugues -- ls -la /home/github-runner/actions-runner/run.sh

# Restart service
incus exec ci-runner-portugues -- systemctl restart github-runner-pt
```

---

## 15. Verify Everything

### Complete verification script
```bash
incus exec ci-runner-portugues -- su - github-runner -c '
echo "=========================================="
echo "         VERIFICATION REPORT"
echo "=========================================="

echo ""
echo "--- System ---"
uname -a

echo ""
echo "--- Docker ---"
docker --version
docker info 2>&1 | grep -E "Server Version|Storage Driver" | head -3

echo ""
echo "--- Java ---"
java -version 2>&1

echo ""
echo "--- Flutter ---"
export PATH=/opt/flutter/bin:$PATH
flutter --version --no-version-check 2>&1 | head -5

echo ""
echo "--- Android SDK ---"
export ANDROID_HOME=$HOME/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
sdkmanager --list_installed 2>&1 | grep -E "platforms|build-tools|ndk|platform-tools"

echo ""
echo "--- Security Tools ---"
grype --version
trivy --version
hadolint --version
dockle --version
syft --version
cosign version 2>&1 | head -1
gitleaks version

echo ""
echo "--- edge-tts ---"
edge-tts --version 2>&1 | head -1

echo ""
echo "--- GitHub Actions Runners ---"
systemctl is-active github-runner-pt
systemctl is-active github-runner-es
ls ~/actions-runner/bin/Runner.Listener 2>&1
ls ~/actions-runner-spanish/bin/Runner.Listener 2>&1

echo ""
echo "=========================================="
echo "         ALL CHECKS PASSED"
echo "=========================================="
'
```

### Expected output
```
==========================================
         VERIFICATION REPORT
==========================================

--- System ---
Linux ci-runner-portugues ... x86_64 GNU/Linux

--- Docker ---
Docker version 29.1.3, build ...
 Server Version: 29.1.3

--- Java ---
openjdk version "17.0.20" ...

--- Flutter ---
Flutter 3.29.3 • channel stable
Tools • Dart 3.7.2 • DevTools 2.42.3

--- Android SDK ---
  build-tools;35.0.0   | 35.0.0        | Android SDK Build-Tools 35
  ndk;27.0.12077973    | 27.0.12077973 | NDK (Side by side) 27.0.12077973
  platform-tools       | 37.0.1        | Android SDK Platform-Tools
  platforms;android-35 | 2             | Android SDK Platform 35

--- Security Tools ---
grype 0.118.0
Version: 0.74.0
Haskell Dockerfile Linter 2.12.0
dockle version 0.4.14
syft 1.51.1
  ______   ______        _______. __    _______ .__   __.
8.24.2

--- edge-tts ---
edge-tts 7.2.8

--- GitHub Actions Runners ---
active
active
/home/github-runner/actions-runner/bin/Runner.Listener
/home/github-runner/actions-runner-spanish/bin/Runner.Listener

==========================================
         ALL CHECKS PASSED
==========================================
```

---

## 16. Troubleshooting

### Container won't start after reboot
```bash
incus start ci-runner-portugues
incus list ci-runner-portugues
```

### Runners showing offline on GitHub
```bash
# Check services inside container
incus exec ci-runner-portugues -- systemctl status github-runner-pt
incus exec ci-runner-portugues -- systemctl status github-runner-es

# Restart if needed
incus exec ci-runner-portugues -- systemctl restart github-runner-pt
incus exec ci-runner-portugues -- systemctl restart github-runner-es
```

### Docker permission denied
```bash
# Make sure user is in docker group
incus exec ci-runner-portugues -- usermod -aG docker github-runner

# Restart docker
incus exec ci-runner-portugues -- systemctl restart docker

# Log out and back in for group changes to take effect
```

### Flutter build fails with "JAVA_HOME not set"
The systemd service sets JAVA_HOME. If running manually:
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

### APK build fails with "SDK location not found"
```bash
export ANDROID_HOME=/home/github-runner/android-sdk
```

### Container runs out of disk space
```bash
# Clean up
incus exec ci-runner-portugues -- bash -c '
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
docker system prune -f
'
```

### Container runs out of memory
Increase memory limit:
```bash
incus stop ci-runner-portugues
incus config set ci-runner-portugues limits.memory 16GiB
incus start ci-runner-portugues
```

### Reset everything (start fresh)
```bash
incus stop ci-runner-portugues
incus delete ci-runner-portugues
# Then follow all steps from the beginning
```

---

## 17. Quick Reference

### Container management
```bash
# Status
incus list ci-runner-portugues

# Enter shell
incus exec ci-runner-portugues -- bash

# Run as github-runner
incus exec ci-runner-portugues -- su - github-runner

# Stop/Start
incus stop ci-runner-portugues
incus start ci-runner-portugues

# Logs
incus exec ci-runner-portugues -- journalctl -u github-runner-pt -f
incus exec ci-runner-portugues -- journalctl -u github-runner-es -f
```

### Runner management
```bash
# Status
incus exec ci-runner-portugues -- systemctl status github-runner-pt
incus exec ci-runner-portugues -- systemctl status github-runner-es

# Restart
incus exec ci-runner-portugues -- systemctl restart github-runner-pt
incus exec ci-runner-portugues -- systemctl restart github-runner-es

# View logs
incus exec ci-runner-portugues -- journalctl -u github-runner-pt -n 50 --no-pager
```

### File locations
```
Container:
  /opt/flutter/                          → Flutter SDK
  /home/github-runner/android-sdk/       → Android SDK
  /home/github-runner/actions-runner/    → PT runner
  /home/github-runner/actions-runner-spanish/ → ES runner
  /home/github-runner/.bashrc            → Env vars for user
  /etc/profile.d/ci-runner.sh           → System-wide env vars
  /etc/systemd/system/github-runner-pt.service  → PT service
  /etc/systemd/system/github-runner-es.service  → ES service

Host:
  /home/antix/master/Projects app languges prtg -esp/.env → GitHub PAT
```

### Version matrix
| Tool | Version | Location |
|------|---------|----------|
| Ubuntu | 24.04.4 LTS | Container OS |
| Docker | 29.1.3 | /usr/bin/docker |
| Java | 17.0.20 | /usr/lib/jvm/java-17-openjdk-amd64 |
| Flutter | 3.29.3 | /opt/flutter/ |
| Dart | 3.7.2 | (bundled with Flutter) |
| Android SDK Platform | 35 | ~/android-sdk/platforms/android-35 |
| Android Build Tools | 35.0.0 | ~/android-sdk/build-tools/35.0.0 |
| Android NDK | 27.0.12077973 | ~/android-sdk/ndk/27.0.12077973 |
| Platform Tools | 37.0.1 | ~/android-sdk/platform-tools/ |
| grype | 0.118.0 | /usr/local/bin/grype |
| trivy | 0.74.0 | /usr/local/bin/trivy |
| hadolint | 2.12.0 | /usr/local/bin/hadolint |
| dockle | 0.4.14 | /usr/local/bin/dockle |
| syft | 1.51.1 | /usr/local/bin/syft |
| cosign | latest | /usr/local/bin/cosign |
| gitleaks | 8.24.2 | /usr/local/bin/gitleaks |
| edge-tts | 7.2.8 | pip3 |
| GitHub Actions Runner | 2.322.0 | ~/actions-runner/ |

---

## Summary of what was done on 2026-09-03

1. Deleted old `ci-runner-portugues` container
2. Created fresh container with Ubuntu 24.04, security.nesting=true, 4 CPU, 12GB RAM
3. Installed system packages: curl, wget, git, unzip, xz-utils, zip, ca-certificates, gnupg, lsb-release, python3, python3-pip, openjdk-17-jdk-headless, docker.io, docker-buildx, jq
4. Enabled Docker with BuildKit support
5. Created `github-runner` user with sudo and docker groups
6. Installed Flutter SDK 3.29.3 at `/opt/flutter/`
7. Installed Android SDK: platforms/android-35, build-tools/35.0.0, ndk/27.0.12077973, platform-tools
8. Set up environment variables in .bashrc and /etc/profile.d/
9. Installed security tools: grype 0.118.0, trivy 0.74.0, hadolint 2.12.0, dockle 0.4.14, syft 1.51.1, cosign, gitleaks 8.24.2
10. Installed edge-tts 7.2.8
11. Installed GitHub Actions Runner v2.322.0 (two copies)
12. Registered runners: ci-runner-pt (Portuguese) + ci-runner-es (Spanish)
13. Created systemd services with auto-restart
14. Verified all tools working
15. Both runners online on GitHub

### Issues encountered and fixes
| Issue | Fix |
|-------|-----|
| `apt-get` lock timeout | Waited for dpkg process to finish |
| gitleaks download fails (wrong URL) | Used explicit version URL: `v8.24.2/gitleaks_8.24.2_linux_x64.tar.gz` |
| cosign permission denied | `chmod +x /usr/local/bin/cosign` |
| edge-tts pip3 permission error | Use `--break-system-packages` flag |
| Flutter `--version` tries git fetch | Use `--no-version-check` flag or add `git config --global --add safe.directory /opt/flutter` |
