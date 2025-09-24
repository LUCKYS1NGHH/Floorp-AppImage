#!/bin/bash
set -eux

ARCH="x86_64"
export APPIMAGE_EXTRACT_AND_RUN=1

# Paths
APPDIR="$(realpath ./AppDir)"
mkdir -p "$APPDIR"

# Download appimagetool
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
wget --retry-connrefused --tries=30 -O ./appimagetool "$APPIMAGETOOL_URL"
chmod +x ./appimagetool

# Get latest Floorp release version
FLOORP_API="https://api.github.com/repos/Floorp-Projects/Floorp/releases/latest"
VERSION=$(curl -s "$FLOORP_API" | grep -Po '"tag_name": "\K.*?(?=")')
FLOORP_URL="https://github.com/Floorp-Projects/Floorp/releases/download/$VERSION/floorp-linux-amd64.tar.xz"

# Download Floorp
wget --retry-connrefused --tries=30 -O floorp.tar.xz "$FLOORP_URL"

# Extract Floorp into AppDir
rm -rf tmp_extract
mkdir tmp_extract
tar -xf floorp.tar.xz -C tmp_extract
mv tmp_extract/*/* "$APPDIR"/ || mv tmp_extract/* "$APPDIR"/
rm -rf tmp_extract floorp.tar.xz

# Generate AppRun if not exists
if [ ! -f "$APPDIR/AppRun" ]; then
    cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "$HERE/floorp" "$@"
EOF
    chmod +x "$APPDIR/AppRun"
fi

# Generate .desktop file
DESKTOP_FILE="$APPDIR/floorp.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Floorp
Exec=floorp
Icon=floorp
Categories=Network;WebBrowser;
Terminal=false
EOF

# Ensure an icon exists
ICON_FILE="$APPDIR/floorp.png"
if [ ! -f "$ICON_FILE" ]; then
    # Create a simple placeholder icon
    convert -size 256x256 xc:blue "$ICON_FILE" || touch "$ICON_FILE"
fi

echo "AppDir ready at: $APPDIR"
ls -al "$APPDIR"

# Build AppImage
./appimagetool --comp zstd \
    --mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
    -n "$APPDIR" "floorp-${VERSION}-${ARCH}.AppImage"

# Move result to dist/
mkdir -p dist
mv *.AppImage dist/
