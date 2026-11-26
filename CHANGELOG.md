# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Open an encounter's or a scenario's pawns in Pawn Shop, ready to print, from its context menu on the Mac
- Art pasted onto a bestiary creature prints as a pawn in Pawn Shop

### Fixed
- Hit points stay on one line on narrow strips, such as on an iPhone

## [2.3.0] - 2026-11-24

### Added
- Hold Society records back from older versions
- Warn before leaving Society play and tighten Society numbers
- Work out what leaving Society play hides
- Show Society features only in Society events
- Add a Society setting to campaigns and Society numbers to members

### Fixed
- Keep the party icon inside the row's highlight on the iPad
- Show one difficulty and keep the Event ID outside Society play
- Pin campaigns outside Society play to the base difficulty

### Changed
- Update tabletop-kit to 1.19.1
- Put a member's Society number under the name, small and faded
- Require tabletop-kit 1.19.0
- Require tabletop-kit 1.18.0
- Pin the App Store tools to tabletop-kit 1.17.0
- Require tabletop-kit 1.17.0
- Require tabletop-kit 1.16.0
- Update the Artwork submodule to 457740e

[2.3.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v2.3.0

## [2.2.0] - 2026-11-24

### Added
- Explain voice initiative before it first listens
- Replace hold-to-talk with the voice initiative screen
- Add the listening meter and voice initiative rows
- Measure frequency bands for a listening meter
- Keep the party's seating order for voice initiative
- Recognize natural rolls and spoken names
- Sync the library through iCloud in the app
- Add the iCloud sync handler for campaigns
- Merge synced records against their last version

### Fixed
- Keep the voice screen listening through interruptions
- Ignore table talk on the voice initiative screen
- Save changes from iCloud before recording them
- Name imported characters instead of keeping Player 1
- Stop number fields repeating their row's title
- Delete what arrives inside a deleted campaign
- Warn only about PDFs a creature needs
- Stop Creature Art's buttons filling the sheet
- Keep deleted records deleted
- Warn only about PDFs whose art can't be shown

### Changed
- Describe the always-listening voice screen in privacy texts
- Remove the hold-to-talk initiative target
- Specify the voice initiative screen
- Add the shared App Store pipeline
- Require tabletop-kit 1.15.0
- Name the CloudKit environment in iPad builds
- Sign builds for iCloud
- Name the table transport for what it is
- Drop the nearby sync Bonjour service
- Remove Sync with Nearby Device
- Specify syncing the library through iCloud

[2.2.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v2.2.0

## [2.1.0] - 2026-11-21

### Added
- Rename a strip from its menu on the board
- Mark a strip dead or revive it from the board
- Count dead enemies as down, and gray them out on the player screen
- Skip dead strips in the initiative order
- Add creatures as allies, and switch a strip's side
- Add a creature to a fight from the board
- Share the player screen with the players' devices
- Run on the iPhone

### Fixed
- Show the About screen from the iPad's menu bar
- Knock allies out with the swipe instead of killing them
- Close the gap around a creature's starting conditions on the iPhone
- Paste creature art on iOS 27

### Changed
- Require tabletop-kit 1.12.0
- Update tabletop-kit to 1.11.4
- Time out CI jobs instead of waiting 6 hours
- Require tabletop-kit 1.11.3
- Require tabletop-kit 1.11.2
- Pin the GitHub actions to commit hashes
- Run the tests on the self-hosted Mac mini
- Require tabletop-kit 1.11.1
- Require tabletop-kit 1.11.0
- Require tabletop-kit 1.10.0
- Require tabletop-kit 1.9.0
- Require tabletop-kit 1.8.1
- Require tabletop-kit 1.8.0
- Require tabletop-kit 1.7.0
- Require tabletop-kit 1.6.0
- Require tabletop-kit 1.5.0
- Require tabletop-kit 1.4.1
- Require tabletop-kit 1.4.0
- Drop the AI disclosure rule from CONTRIBUTING
- Keep the release checkout to one with block
- Number every build by the commits on main
- Number every build by the commits on main
- Specify About in the iPad's menu bar
- Specify that a swipe knocks allies out
- Specify renaming a strip on the board
- Specify the Dead status for strips
- Send any protocol's messages over a channel
- Scroll to the creatures before opening a card in the screenshot tour
- Tap the glossary popover's own link

[2.1.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v2.1.0

## [2.0.1] - 2026-11-13

### Fixed
- Match the Challenge Points presets to the organized play brackets
- Stop the iPad app crashing at launch on a Mac

[2.0.1]: https://github.com/scooper4711/turnkeeper/releases/tag/v2.0.1

## [2.0.0] - 2026-11-13

### Added
- Read Scrollkeeper's App Group folder on iPad
- Build Turnkeeper for the Mac App Store

### Fixed
- Drop the alpha channel from the iOS App Store icon
- Open Device Hub after starting the iPad simulator
- Declare file attributes in the privacy manifest as Pawn Shop does

### Changed
- Set the category to role-playing games
- use the exact Community Use notice wording
- Say what deleting the app leaves on a Mac
- Rewrap the review notes line

[2.0.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v2.0.0

## [1.4.1] - 2026-10-25

### Fixed
- Stop conflict copies of records only one device edited

[1.4.1]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.4.1

## [1.4.0] - 2026-10-25

### Added
- Add Table Buddies (iconic pregens) to parties

[1.4.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.4.0

## [1.3.0] - 2026-10-24

### Added
- Sync party members one at a time
- Offer to open a blank Demiplane sheet on Demiplane
- Show that a nearby sync is in progress

### Fixed
- Name the At Table / Away toggle on party members
- Keep Demiplane sheets when an export is blank or a sync conflicts
- Stamp the iPad build with the release version

[1.3.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.3.0

## [1.2.4] - 2026-10-23

### Fixed
- Paste images copied from a PDF viewer as rich text

[1.2.4]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.4

## [1.2.3] - 2026-10-23

### Added
- Paste PDF pages as handouts and creature art
- Reopen the campaign that was open last

### Fixed
- Give Starts on bench its own line on the iPad

[1.2.3]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.3

## [1.2.2] - 2026-10-23

### Fixed
- Let the iPad choose a device to sync with

[1.2.2]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.2

## [1.2.1] - 2026-10-23

### Fixed
- Show party members' names again, one row per character

### Changed
- Describe the v1.2.0 changes in the CHANGELOG

[1.2.1]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.1

## [1.2.0] - 2026-10-23

### Added
- Party members have a player's name and notes
- "Show Player Names" in the board's Fight menu shows "Character (Player)" on PC tiles (GM view only)

### Changed
- Knocking out a strip now applies unconscious and prone alongside dying
- Swiping right to left (or the context menu) on a dying strip stabilizes it: dying ends, unconscious stays, and wounded goes up by 1
- Stabilized and unconscious enemies show as down on the players' screen

[1.2.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.2.0

## [1.1.1] - 2026-10-20

### Added
- Import shared Demiplane characters without signing in
- Run Turnkeeper in the App Sandbox

### Fixed
- Let the whole party member row answer a right-click
- Swipe battle strips with two fingers on a Mac trackpad
- Lay out a creature's row for the Mac, with a trash button
- Bundle the universal binary from where SwiftPM built it

### Changed
- Specify importing shared characters without signing in
- Run the weekly pf2e update off the hour
- Take Tabletop Kit 0.15.1
- Specify running in the App Sandbox
- Watch every pf2e file the import reads
- Gate releases on the coverage check, as CI does

[1.1.1]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.1.1

## [1.1.0] - 2026-10-15

### Added
- List the bundled licenses on the About screen
- Bundle the license texts the app's content requires
- Show and use the picked difficulty for either scheme
- Pick Starfinder's Easier, Base or Harder from the party's points

### Fixed
- Resolve SonarCloud medium and high findings
- Decide sign-in navigation with a completion handler
- Limit the Demiplane sign-in to its own sites
- Write converted fonts only inside the repository
- Keep the Demiplane sign-in on secure pages

### Changed
- Add CI, SonarCloud, release and platform badges
- Exclude asset catalogs from SonarCloud analysis
- Share read-only bindings and alert cancel buttons
- Grant write access per job in the pf2e update
- Add CI with SonarCloud analysis
- Say the toolkit is Mac apps, two also on the iPad
- Credit the Roboto fonts
- Specify the license texts on Turnkeeper's About screen
- Tap the card where no link is, and find a PC card by its trait
- Rename the suite the Tableside Toolkit
- Specify Starfinder's Easier, Base and Harder by party points
- Sell the linked battle cards, live conditions and reusable encounters

[1.1.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.1.0

## [1.0.0] - 2026-10-14

### Added
- Initial release

[1.0.0]: https://github.com/scooper4711/turnkeeper/releases/tag/v1.0.0
