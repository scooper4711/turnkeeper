.PHONY: build test lint coverage bestiary update-pf2e dmg appstore cards icon app run install \
	ipad-simulator ipad-install ipad-uitest iphone-simulator iphone-install iphone-uitest screenshots clean

build:
	swift build

test:
	swift test

lint:
	swiftlint --strict --quiet

# Runs the tests and fails when TurnkeeperKit's and CharacterImport's coverage is below 80%.
coverage:
	scripts/coverage.sh

# Re-imports creatures, conditions and the glossary from the pf2e release in pf2e.release (see
# scripts/import-bestiary.sh for the sources and their overrides).
bestiary:
	scripts/import-bestiary.sh

# Switches pf2e.release to pf2e's newest release and re-imports. GitHub does this weekly too.
update-pf2e:
	scripts/latest-pf2e-release.sh > pf2e.release
	scripts/import-bestiary.sh

# Packages the built app into build/Turnkeeper-<VERSION>.dmg.
dmg: app
	scripts/make-dmg.sh

app:
	scripts/build-app.sh

run: app
	open "build/Turnkeeper.app"

# Moves the built app into /Applications, replacing an earlier copy. The build copy is unregistered and
# removed so Finder and Spotlight launch the installed one.
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
install: app
	rm -rf "/Applications/Turnkeeper.app"
	ditto "build/Turnkeeper.app" "/Applications/Turnkeeper.app"
	-$(LSREGISTER) -u "build/Turnkeeper.app" 2>/dev/null  # Fails when it was never registered, which is fine.
	rm -rf "build/Turnkeeper.app"

# Builds the iPad app and starts it in a simulator. IPAD_SIMULATOR names the simulator.
ipad-simulator:
	scripts/run-ipad-simulator.sh

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
# A free developer team's signature lasts 7 days, so run this again each week.
ipad-install:
	scripts/install-ipad.sh

# The same for the iPhone. IPAD_SIMULATOR and IPAD name the simulator and the iPhone.
iphone-simulator:
	DEVICE_KIND=iPhone scripts/run-ipad-simulator.sh

iphone-install:
	DEVICE_KIND=iPhone scripts/install-ipad.sh

# Redraws the Mac and iPad icons and the icon of a .turnkeeper file, from scripts/icon.
icon:
	mkdir -p tmp
	swiftc -o tmp/make-icon scripts/icon/*.swift
	tmp/make-icon
	rm tmp/make-icon

# Runs the iPad UI tests in a simulator, against the demo fight. ONLY="DelayUITests ..." runs just those.
ipad-uitest:
	scripts/run-ipad-uitests.sh

# The same tests on an iPhone, where the board shows the ladder alone and cards open in a sheet.
iphone-uitest:
	DEVICE_KIND=iPhone scripts/run-ipad-uitests.sh

# Saves a picture of every screen of the demo library to tmp/screenshots, to check a device's layout by eye.
# SIMULATOR names the simulator (default: an iPhone).
screenshots:
	scripts/screenshot-tour.sh

# Renders battle cards to tmp/cards for comparing with the printed decks: make cards KEYS="key[:elite] ..."
cards:
	swift run CardSnapshots tmp/cards $(KEYS)

# Archives the app for the App Store and exports build/ipad/export/*.ipa, versioned from git. Upload it with
# `make testflight`.
.PHONY: ipad-archive testflight
ipad-archive:
	.build/checkouts/tabletop-kit/scripts/archive-ios.sh ios/Turnkeeper.xcodeproj Turnkeeper-iPad build/ipad

# Uploads the newest build (the .ipa from ipad-archive or the .pkg from appstore) to TestFlight, with this release's
# notes from the tableside-store checkout next to this repository (TABLESIDE_STORE).
TABLESIDE_STORE ?= ../tableside-store
TESTFLIGHT_NOTES = $(TABLESIDE_STORE)/turnkeeper/testflight/what-to-test.txt
TESTFLIGHT_BUILD ?= $(shell ls -t build/ipad/export/*.ipa build/appstore/*.pkg 2>/dev/null | head -n 1)
testflight:
	@test -f "$(TESTFLIGHT_NOTES)" || { echo "testflight failed: $(TESTFLIGHT_NOTES) not found; set TABLESIDE_STORE"; exit 1; }
	@test -n "$(TESTFLIGHT_BUILD)" || { echo "testflight failed: no build; run make ipad-archive or make appstore"; exit 1; }
	.build/checkouts/tabletop-kit/scripts/testflight.sh io.github.scooper4711.Turnkeeper "$(TESTFLIGHT_BUILD)" "$(TESTFLIGHT_NOTES)"

clean:
	rm -rf .build build ios/build

# Builds the Mac App Store package, build/appstore/Turnkeeper.pkg (see scripts/build-app.sh for the variables).
appstore:
	swift package resolve
	CHANNEL=appstore scripts/build-app.sh
