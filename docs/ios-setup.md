# iOS setup

One-time steps to get Next Up onto your phone through TestFlight. Run them in order from the repo root. Nothing here is automated, because each step touches the Apple Developer account or GitHub secrets.

Prerequisites: `mise install` and `bundle install`, an Apple ID on team `8353VT99LA`, and an App Store Connect API key (Users and Access > Integrations > App Store Connect API) with the Admin role, or App Manager with access to Certificates, Identifiers & Profiles. `fastlane ios certificates` creates certificates and profiles through the API, which App Manager alone cannot do. Keep the downloaded `.p8` somewhere safe (1Password).

## 1. Add the repo secrets

The release and TestFlight workflows read these. The six secrets are already set on `andrewcfitz/next-up` for the Mac release (`gh secret list --repo andrewcfitz/next-up` shows them); nothing to add here.

## 2. Register the App IDs and App Groups

Creates the prod (`biz.fitz.NextUp`) and dev (`biz.fitz.NextUp.dev`) App IDs, their widget IDs, and the `group.biz.fitz.NextUp` and `group.biz.fitz.NextUp.dev` App Groups. This logs in with your Apple ID (as account holder), not the API key.

Run in a real Terminal:

```sh
cd ~/workspace/next-up/main
export FASTLANE_USER=apps@fitz.biz FASTLANE_PASSWORD="$(op read 'op://fitz-biz/c4fhiycjjv7gt23ux5l2smo4yu/password')"
bundle exec fastlane ios bootstrap
```

Export `FASTLANE_PASSWORD` because the lane's `sh` subprocesses have no terminal and the Keychain write can fail without it cached in the environment.

Bootstrap sets the App Group list on the shared `biz.fitz.NextUp` and `biz.fitz.NextUp.Widget` App IDs to the iOS group. The Mac app's team-prefixed group is checked against the signature, so this should be harmless. If Mac Debug signing complains afterwards, let Xcode re-register the group (automatic signing) and rebuild.

## 3. Create the App Store Connect record

TestFlight needs an app record for `biz.fitz.NextUp`. App names are unique across the App Store; "Next Up" is taken, so set `NEXTUP_ASC_NAME`. The name on the home screen comes from `Config/Prod.xcconfig`, not from this.

In the same shell (the exports from step 2 are still set):

```sh
NEXTUP_ASC_NAME="<unique name>" bundle exec fastlane ios appstore_record
```

## 4. Create the signing profiles

Creates or renews the iOS `development` and `appstore` profiles (named `match AppStore <bundle id>`) for every identifier and stores them in the match repo. Run it in a real Terminal, not inside tmux: match imports the certificate into the login keychain, and from tmux (a launchd daemon outside the GUI session) that fails with `User interaction is not allowed`. This needs:

- the App Store Connect key env vars: `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY` (base64 or raw PEM)
- `MATCH_PASSWORD`
- SSH access to `git@github.com:fitz-biz/earful-certificates.git` from this machine (override with `MATCH_GIT_URL`)

Export the key values from 1Password items `3dodbqqqyxdz5yzbjn75acd3qq` (KeyId, IssuerId, AuthKey) and `hjkuizflyvkx5kn5ho565234na` (credential), then:

```sh
export APP_STORE_CONNECT_API_KEY_ID="$(op read 'op://fitz-biz/3dodbqqqyxdz5yzbjn75acd3qq/KeyId')"
export APP_STORE_CONNECT_API_ISSUER_ID="$(op read 'op://fitz-biz/3dodbqqqyxdz5yzbjn75acd3qq/IssuerId')"
export APP_STORE_CONNECT_API_KEY="$(op read 'op://fitz-biz/3dodbqqqyxdz5yzbjn75acd3qq/AuthKey' | base64)"
export MATCH_PASSWORD="$(op read 'op://fitz-biz/hjkuizflyvkx5kn5ho565234na/credential')"
bundle exec fastlane ios certificates
```

`APPLE_TEAM_ID` is optional locally; the lanes fall back to the team in `project.yml`.

To install the same certificates and profiles on this Mac afterwards (read-only, needs `MATCH_PASSWORD` and repo access): `bundle exec fastlane ios setup`.

## 5. Run the TestFlight workflow

```sh
gh workflow run testflight.yml -R andrewcfitz/next-up
```

It builds the prod app, numbers the build one above the latest on TestFlight, and uploads without waiting for Apple's processing. Follow it with `gh run watch -R andrewcfitz/next-up`.

## 6. Set up internal testers

Add the tester's email to the internal TestFlight group. The API key exports from step 4 must be in the same shell (or repeat them):

```sh
TESTER_EMAIL=andrew@fitz.biz bundle exec fastlane ios internal_testers
```

## 7. Install on the phone

Once the build finishes processing in App Store Connect, install it from the TestFlight app on your iPhone.

## 8. Add your iCal feeds

Open Next Up on the phone and add your iCal feed subscriptions (tap Add Feed and enter the URL).

## 9. Add the widgets

On the phone, add a Home Screen widget and a Lock Screen widget (Next Up).

## Dev vs prod

Debug builds use `Config/Dev.xcconfig` (`biz.fitz.NextUp.dev`, "Next Up Dev") so a development build installs beside the TestFlight one. Release builds, including TestFlight, use `Config/Prod.xcconfig` (`biz.fitz.NextUp`, "Next Up"). Both are registered by step 2.

## Note: Mac and iOS apps use separate App Groups

The macOS app uses the App Group `$(TeamIdentifierPrefix)biz.fitz.NextUp` (team-prefixed, checked against the signature). The iOS app uses `group.biz.fitz.NextUp` (plain `group.` prefix). They are separate container paths on separate devices and do not share or sync feeds. Step 2 (bootstrap) sets the iOS App Group on the shared `biz.fitz.NextUp` App ID, which does not affect the Mac app's signature or provisioning.

## Apple Watch

The watch app and its complications ship inside the iPhone app, so TestFlight installs them together. They need two more App IDs per environment (`<bundle id>.watchkitapp` and `<bundle id>.watchkitapp.Widget`) in the same App Group, and profiles for them. Once, before the first TestFlight build that includes the watch, rerun with the same exports as above:

    bundle exec fastlane ios bootstrap
    bundle exec fastlane ios certificates

Both are safe to rerun; existing IDs and profiles are kept.

Feeds are managed on the iPhone only. After each refresh the iPhone app sends its feeds and stays to the watch; the complication also fetches on its own when its data is older than the refresh interval. Add a complication from the watch face editor (Next Stay: circular, corner, rectangular or inline) or the Smart Stack.
