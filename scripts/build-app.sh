#!/bin/sh
# Builds "build/Turnkeeper.app" from the Swift package.
#
# VERSION    version written to the bundle (default 0.0.0)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
# TEAM_ID    the team that owns the App Group (default: read from the Developer ID certificate)
# SIGNING_IDENTITY  passed to scripts/sign-app.sh; "-" signs ad hoc, without the App Group
# BUILD_NUMBER  CFBundleVersion, which must increase with every App Store upload (default: VERSION)
# CHANNEL    "appstore" also builds the Mac App Store package, build/appstore/Turnkeeper.pkg, from the same sources,
#            compiled with -DAPP_STORE; needs TEAM_ID and the variables of tabletop-kit's
#            scripts/package-appstore.sh (PACKAGER names another copy; TRIAL=1 checks it without them)
set -eu

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0}"
APP="build/Turnkeeper.app"
EXECUTABLE="Turnkeeper"

SWIFT_FLAGS=""
[ "${CHANNEL:-}" = "appstore" ] && SWIFT_FLAGS="-Xswiftc -DAPP_STORE"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    # shellcheck disable=SC2086 # SWIFT_FLAGS is a list of words
    swift build -c release $SWIFT_FLAGS --arch arm64 --arch x86_64
    # Asked rather than assumed: newer SwiftPM moved universal builds out of .build/apple, and a copy left
    # there by an older toolchain would otherwise be bundled instead.
    BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$EXECUTABLE"
else
    # shellcheck disable=SC2086
    swift build -c release $SWIFT_FLAGS
    BINARY="$(swift build -c release --show-bin-path)/$EXECUTABLE"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/container-migration.plist "$APP/Contents/Resources/container-migration.plist"
# The imported bestiary and art (see "make bestiary"), bundled as a folder like on the iPad.
if [ -d Generated ]; then
    ditto Generated "$APP/Contents/Resources/Generated"
else
    echo "Warning: Generated/ is missing; run \"make bestiary\" to bundle the bestiary." >&2
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Turnkeeper</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.scooper4711.Turnkeeper</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Turnkeeper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER:-$VERSION}</string>
    <!-- Only HTTPS to Demiplane, which is exempt, so uploads don't ask about export compliance. -->
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.role-playing-games</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Turnkeeper listens while you hold Hold to Say Initiative, so you can say the initiative total.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Turnkeeper turns the initiative you say into a number, on this device when it can.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Turnkeeper syncs encounters with your other devices on this network.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_turnkeeper._tcp</string>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Turnkeeper Library</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>io.github.scooper4711.turnkeeper.library</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>io.github.scooper4711.turnkeeper.library</string>
            <key>UTTypeDescription</key>
            <string>Turnkeeper Library</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.json</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>turnkeeper</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>io.github.scooper4711.pluck.statblock</string>
            <key>UTTypeDescription</key>
            <string>Pathfinder Stat Block</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.json</string>
            </array>
        </dict>
    </array>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Stephen Cooper. MIT License.</string>
</dict>
</plist>
PLIST

# The privacy manifest the App Store requires, shared with the iPad app.
cp ios/App/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"

# The entitlements turn on the App Sandbox. A build signed with the team's Developer ID also joins the Tableside
# Toolkit's App Group, where Scrollkeeper keeps its downloads: the team's ID takes the place of TEAM_ID. The team ID
# is read from the signing certificate, or from TEAM_ID in the environment. An ad hoc
# signature can't join the group, so its build leaves the group out and asks for Scrollkeeper's folder instead.
ENTITLEMENTS="build/Turnkeeper.entitlements"
if [ "${SIGNING_IDENTITY:-}" != "-" ]; then
    TEAM_ID="${TEAM_ID:-$(security find-identity -v -p codesigning \
        | sed -n 's/.*"Developer ID Application: .*(\([A-Z0-9]*\))"$/\1/p' | head -n 1)}"
fi
if [ -n "${TEAM_ID:-}" ]; then
    sed "s/TEAM_ID/$TEAM_ID/" Resources/Turnkeeper.entitlements > "$ENTITLEMENTS"
else
    cp Resources/Turnkeeper.entitlements "$ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Delete :com.apple.security.application-groups" "$ENTITLEMENTS"
fi
scripts/sign-app.sh "$APP" "$ENTITLEMENTS"
# The bundle is rebuilt at the same path, so Finder and LaunchServices keep showing the icon they cached
# for it (none, from the first build). Touching it and re-registering makes them read the icon again.
touch "$APP"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP"
echo "Built $APP ($VERSION)"

if [ "${CHANNEL:-}" = "appstore" ]; then
    # Found beside the package after "swift package resolve", so the script follows the dependency pin.
    "${PACKAGER:-.build/checkouts/tabletop-kit/scripts/package-appstore.sh}" "$APP" "$ENTITLEMENTS" \
        io.github.scooper4711.Turnkeeper
fi
