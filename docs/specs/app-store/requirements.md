# Mac App Store build: requirements

Turnkeeper 2.0 is listed on the Mac App Store beside its notarized disk image and its iPad app (tabletop-kit#26). The
packaging steps are tabletop-kit's `scripts/package-appstore.sh` (its `appstore-build` spec).

## R1 The build
- R1.1 `CHANNEL=appstore scripts/build-app.sh` (or `make appstore`) builds `build/appstore/Turnkeeper.pkg` from the
  same sources as the disk image, compiled with `-DAPP_STORE`. Turnkeeper has no updater or payment link to leave
  out.
- R1.2 The build number (`BUILD_NUMBER`) is apart from the version, which is 2.0.0 on the Mac and the iPad; the
  bundle declares `ITSAppUsesNonExemptEncryption` as false and a copyright line on both.

## R2 Privacy
- R2.1 A privacy manifest ships in both bundles: no tracking, no data collected, user defaults (CA92.1) and file
  attributes (C617.1, 3B52.1), as in Pawn Shop, which reads file sizes through the same tabletop-kit code.
- R2.2 `PRIVACY.md` is the privacy policy, linked from the Help menu on the Mac.

## R3 Review
- R3.1 `APP-STORE-REVIEW.md` holds the review notes, with a use named for every entitlement: Demiplane import
  (network client), device sync (network server), voice initiative (microphone and speech), the camera on the iPad.
  The file is kept out of the repository (`.git/info/exclude`).
