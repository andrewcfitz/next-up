# Handoff: ship the first Next Up release through Homebrew

## Goal

Get `andrewcfitz/next-up` to the point where a tagged release produces a signed, notarized
`NextUp.app` that installs with:

```sh
brew tap andrewcfitz/next-up https://github.com/andrewcfitz/next-up
brew install --cask next-up
```

All the code is written and merged to `main` in
[andrewcfitz/next-up#1](https://github.com/andrewcfitz/next-up/pull/1). What's left is
account and secrets setup, then a first release, which needs access the previous session
didn't have: Apple Developer, 1Password, GitHub repo settings and a Mac.

## Background

- **Next Up** is a macOS menu bar app and widget (macOS 15+, Xcode 16+). It reads iCal feeds
  of campground reservations and counts down to the next check-in. The owner is going
  full-time in an RV.
- Apple team: **`8353VT99LA`**. Bundle IDs: `com.andrewcfitz.NextUp` (app) and
  `com.andrewcfitz.NextUp.Widget` (widget). App Group:
  `$(TeamIdentifierPrefix)com.andrewcfitz.NextUp`.
- The release pipeline copies the owner's other app, **`fitz-biz/earful`**: Fastlane with
  `match` (git storage) and an App Store Connect API key. Both apps sign as the same team, so
  next-up **reuses Earful's match repo, `fitz-biz/earful-certificates`**, for a shared
  Developer ID Application certificate.

## How the pipeline works (already in the repo)

| File | Purpose |
| --- | --- |
| `fastlane/Fastfile` | Lanes: `test`, `release`, `certificates` (one-time), `setup` (read-only install) |
| `fastlane/Matchfile` | `type developer_id`, `platform macos`, `skip_provisioning_profiles true`, git URL defaults to `earful-certificates` (override with `MATCH_GIT_URL`) |
| `fastlane/Appfile` | App ID `com.andrewcfitz.NextUp` |
| `Gemfile` / `Gemfile.lock` | fastlane 2.240.1; Ruby 3.3.6 via `mise.toml` |
| `.github/workflows/ci.yml` | `fastlane test` on `macos-15`, on pushes to `main` and on PRs, signed ad-hoc (no secrets) |
| `.github/workflows/release.yml` | On a `v*` tag or manual run with a `version` input: `fastlane release` → GitHub release with `NextUp-<version>.zip` → a second job commits `Casks/next-up.rb` to `main` |
| `Scripts/update-cask.sh` | Writes `Casks/next-up.rb` from a version and SHA-256 |

What the `release` lane does: `setup_ci` → `match(readonly)` installs the Developer ID
certificate → `build_app` archives the `NextUp` scheme with
`CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Developer ID Application'` and
`MARKETING_VERSION=<version>` / `CURRENT_PROJECT_VERSION=<run number>`, then exports with
`developer-id` → `notarize` (API key, staples) → `spctl --assess` → `ditto` zip to
`build/NextUp-<version>.zip`.

## Tasks

### 1. ~~Confirm CI is green on `main`~~ (done)

CI passed on the merge commit `fc2fd78`
([run](https://github.com/andrewcfitz/next-up/actions/runs/36339732073)): `fastlane test`
builds and passes on `macos-15`. If a later run fails, fix it on a branch off `main`. Don't
disable or skip tests.

### 2. Put a Developer ID Application certificate in match

First check whether `fitz-biz/earful-certificates` already has one under
`certs/developer_id_application/`. If so, skip this step. Otherwise, on a Mac with the repo
checked out:

```sh
mise install && bundle install
export MATCH_PASSWORD=...                      # the Earful match passphrase
export APP_STORE_CONNECT_API_KEY_ID="$(op read 'op://fitz-biz/App Store Connect/KeyId')"
export APP_STORE_CONNECT_API_ISSUER_ID="$(op read 'op://fitz-biz/App Store Connect/IssuerId')"
export APP_STORE_CONNECT_API_KEY="$(op read 'op://fitz-biz/App Store Connect/AuthKey')"
bundle exec fastlane certificates
```

Only the **Account Holder** can create Developer ID certificates, so the API may refuse. In
that case:

1. Create the certificate in Xcode: *Settings → Accounts → Manage Certificates → + →
   Developer ID Application*, signed in as the Account Holder.
2. Export it from Keychain Access as a `.p12`.
3. Import it:
   `bundle exec fastlane match import --type developer_id --platform macos --skip_provisioning_profiles`

### 3. Add repository secrets to `andrewcfitz/next-up`

| Secret | Where the value comes from |
| --- | --- |
| `MATCH_PASSWORD` | The Earful match passphrase. Earful's workflows use it as `secrets.MATCH_PASSWORD`, so find where it's stored (likely 1Password). |
| `MATCH_DEPLOY_KEY` | A private SSH key with **read** access to `fitz-biz/earful-certificates`. Rather than reuse Earful's key, generate a new one (`ssh-keygen -t ed25519 -C next-up-match -f next-up-match -N ''`), add the `.pub` as a **read-only deploy key** on `earful-certificates`, and store the private key here. |
| `APP_STORE_CONNECT_API_KEY_ID` | `op://fitz-biz/App Store Connect/KeyId` |
| `APP_STORE_CONNECT_API_ISSUER_ID` | `op://fitz-biz/App Store Connect/IssuerId` |
| `APP_STORE_CONNECT_API_KEY` | `op://fitz-biz/App Store Connect/AuthKey`. The lane accepts a raw PEM or base64. |
| `APPLE_TEAM_ID` | Optional: `8353VT99LA`. The lane otherwise reads it from the project. |

For example: `gh secret set APP_STORE_CONNECT_API_KEY_ID --repo andrewcfitz/next-up --body "$(op read ...)"`.

### 4. Make the repo public

Homebrew downloads the zip from the GitHub release anonymously. The owner has said the repo
will be public. Confirm with them before flipping the setting.

### 5. Cut the first release

```sh
git tag v1.0.0 && git push origin v1.0.0
```

Or run the **Release** workflow by hand with `version: 1.0.0`. Watch both jobs: **Build and
notarize** (macOS), then **Update Homebrew cask** (pushes `Casks/next-up.rb` to `main`).

### 6. Verify on a Mac

```sh
brew tap andrewcfitz/next-up https://github.com/andrewcfitz/next-up
brew install --cask next-up
spctl --assess --verbose=2 --type execute /Applications/NextUp.app   # expect: accepted, Notarized Developer ID
codesign -d --entitlements - /Applications/NextUp.app                # expect the 8353VT99LA.com.andrewcfitz.NextUp app group
```

Then open the app, add a feed, and confirm that:
- the settings window saves the feed and the menu bar dropdown shows upcoming stays;
- the **widget** (Edit Widgets → Next Up) shows the same next stay. This proves the widget can
  read the app's data through the App Group.

## Known risks, most likely first

1. **Signing without provisioning profiles.** The release signs the app and widget with
   Developer ID and no profiles. That relies on the App Group using the Team ID prefix,
   which macOS validates against the signature. If the notarized build can't share data
   between the app and widget, or the widget doesn't appear, look here first. The fix would
   be to register both App IDs with the App Groups capability, let match create
   `developer_id` profiles (drop `skip_provisioning_profiles`), and pass them in
   `export_options.provisioningProfiles` plus `PROVISIONING_PROFILE_SPECIFIER`.
2. **The `developer-id` export.** If `build_app` fails at export asking for profiles, same
   remedy as above. As a fallback, copy `NextUp.app` from the archive's
   `Products/Applications` (it's already Developer ID signed) and notarize that.
3. **Identity override.** The release relies on the command-line
   `CODE_SIGN_IDENTITY='Developer ID Application'`. The per-target
   `CODE_SIGN_IDENTITY[sdk=macosx*] = "Apple Development"` lines were deliberately removed from
   `project.pbxproj` so they can't shadow it. If Xcode adds them back after someone edits
   signing in the UI, remove them again.
4. **The cask push to `main`** uses `GITHUB_TOKEN`. If branch protection blocks it, allow the
   Actions bot to push, or change the job to open a PR instead.

## Rules for the project

- **Don't regenerate `NextUp.xcodeproj`.** It was hand-built, then saved by Xcode with the
  owner's signing settings. Edit it surgically. It uses Xcode 16 synchronized folders, so new
  files in `NextUp/`, `NextUpWidget/`, `Shared/` and `NextUpTests/` are picked up
  automatically.
- **Keep the App Group Team ID–prefixed** (`$(TeamIdentifierPrefix)…`), not `group.…`. A
  `group.` ID without a registered profile left the shared container `nil` and nothing saved.
  `SharedStore` reads the group from the process's entitlements at runtime.
- **Match Earful's conventions** for anything Fastlane or CI related (`fitz-biz/earful`:
  `fastlane/Fastfile`, `.github/workflows/release.yml`).
- The owner's feed is from Louie (`api.louie.camp/v1/public/calendar`). Parser tests use
  its shape with made-up data: timed stays, Windows `TZID`s, folded `URL` lines. Don't put
  the owner's real reservations or addresses in the repo.
