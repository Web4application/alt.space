#!/bin/bash

# 🚀 Ultimate Wayland RPM Build & Publish Script
# ----------------------------------------------
# Builds Wayland RPMs, validates checksum, generates SRPMs, tags version, and pushes to remote repo.

set -euo pipefail

# --- Configuration ---
MAIN_VER="1.18.0"
EGL_VER="18.1.0"
MESA_EPOCH="4"
RELEASE="alt1"
BUILD_DIR="$HOME/rpmbuild"
SPEC_FILE="wayland.spec"
SOURCE_URL="http://wayland.freedesktop.org/releases/wayland-$MAIN_VER.tar.xz"
SOURCE_SHA256="5b2a0f4e0b9dfb7f09a3f84c2f3eac7a14f9b3a1b84d48f99ad3c9cfcddbbf2c" # Replace with actual SHA256
REMOTE_REPO="/path/to/your/local-or-remote-repo"  # Example: /srv/repo or ssh://user@host/path
DOCKER_IMAGE="fedora:38"

log() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

# --- Setup directories ---
mkdir -p "$BUILD_DIR"/{SOURCES,SPECS,BUILD,RPMS,SRPMS,LOGS}

# --- Download source ---
cd "$BUILD_DIR/SOURCES"
if [ ! -f "wayland-$MAIN_VER.tar.xz" ]; then
    log "Downloading Wayland source..."
    curl -LO "$SOURCE_URL"
fi

# --- Checksum verification ---
log "Validating source checksum..."
echo "$SOURCE_SHA256  wayland-$MAIN_VER.tar.xz" | sha256sum -c - || err "Checksum verification failed!"

# --- Generate spec dynamically ---
cat > "$BUILD_DIR/SPECS/$SPEC_FILE" <<EOF
%define main_ver $MAIN_VER
%define egl_ver $EGL_VER
%define mesa_epoch $MESA_EPOCH
Name: wayland
Version: %main_ver
Release: $RELEASE
Summary: Wayland protocol libraries
Group: System/X11
License: MIT
Url: http://wayland.freedesktop.org/
Source: wayland-%{main_ver}.tar.xz

BuildRequires: doxygen libexpat-devel libffi-devel libxml2-devel xsltproc docbook-style-xsl
%description
Wayland is a protocol for compositors to talk to clients. Provides libraries for client/server communication.

%package devel
Summary: Wayland headers
Group: Development/C

%package -n libwayland-client
Summary: Wayland client library
Group: System/Libraries

%package -n libwayland-client-devel
Summary: Development files for Wayland client
Group: Development/C
Requires: libwayland-client = %EVR

%package -n libwayland-server
Summary: Wayland server library
Group: System/Libraries

%package -n libwayland-server-devel
Summary: Development files for Wayland server
Group: Development/C
Requires: libwayland-server = %EVR

%prep
%setup -q

%build
%autoreconf
%configure --disable-static
%make_build

%install
%makeinstall_std

%files devel
%{_includedir}/wayland*

%files -n libwayland-client
%{_libdir}/libwayland-client.so.*

%files -n libwayland-client-devel
%{_includedir}/wayland-client*.h
%{_libdir}/libwayland-client.so
%{_pkgconfigdir}/wayland-client.pc

%files -n libwayland-server
%{_libdir}/libwayland-server.so.*

%files -n libwayland-server-devel
%{_includedir}/wayland-server*.h
%{_libdir}/libwayland-server.so
%{_pkgconfigdir}/wayland-server.pc
EOF

# --- Build in Docker for reproducibility ---
log "Building RPMs in Docker container..."
docker run --rm -v "$BUILD_DIR":"$BUILD_DIR" -w "$BUILD_DIR" $DOCKER_IMAGE /bin/bash -c "
    dnf install -y rpm-build gcc-c++ make autoconf automake libtool pkgconfig libexpat-devel libffi-devel libxml2-devel xsltproc doxygen docbook-style-xsl &&
    rpmbuild --define '_topdir $BUILD_DIR' -ba SPECS/$SPEC_FILE
"

# --- Generate SRPMs for distribution ---
log "Generating source RPMs..."
rpmbuild --define "_topdir $BUILD_DIR" -bs SPECS/$SPEC_FILE

# --- Tag version in Git ---
if [ -d "$BUILD_DIR" ] && git rev-parse --git-dir > /dev/null 2>&1; then
    TAG="wayland-$MAIN_VER"
    log "Tagging current build in Git as $TAG..."
    git tag -f "$TAG"
    git push origin "$TAG" --force
fi

# --- Publish RPMs to repository ---
log "Publishing RPMs to $REMOTE_REPO..."
mkdir -p "$REMOTE_REPO"
cp -v "$BUILD_DIR/RPMS/"*.rpm "$REMOTE_REPO"
cp -v "$BUILD_DIR/SRPMS/"*.src.rpm "$REMOTE_REPO"

# Optional: create repository metadata (for yum/dnf)
if command -v createrepo >/dev/null 2>&1; then
    log "Updating repository metadata..."
    createrepo --update "$REMOTE_REPO"
fi

log "✅ Build, validation, and publishing complete!"
