# Releasing TempoKey on GitHub (downloadable DMG for any Mac)

This is the end-to-end setup to publish TempoKey as a `.dmg` on GitHub Releases that opens
cleanly on **any** Mac — no scary "damaged" / "unidentified developer" warnings.

## The one non-negotiable: signing + notarization

A DMG downloaded from the internet gets a *quarantine* flag. macOS Gatekeeper will only open
it without warnings if the app inside is:

1. **Signed** with an **Apple "Developer ID Application"** certificate, and
2. **Notarized** by Apple (uploaded, scanned, ticket **stapled**).

There is no way around this for general distribution — it requires the **Apple Developer
Program ($99/year)**. (Without it, the only option is telling each user to right-click → Open
or run `xattr -dr com.apple.quarantine`, which is not "loads on any Mac".)

### Compatibility of what we ship
- **Universal** binary: Apple Silicon **and** Intel Macs.
- **Requires macOS 14 (Sonoma) or newer.** Older macOS won't run it. (Lowering this needs code
  changes — the UI uses macOS 14 SwiftUI/Charts APIs.)

---

## One-time setup

### 1. Apple Developer account + certificate
1. Enroll at https://developer.apple.com/programs/ ($99/yr).
2. In **Xcode ▸ Settings ▸ Accounts**, add your Apple ID → **Manage Certificates… ▸ + ▸
   Developer ID Application**. This creates the signing identity.
3. Confirm it exists and note the exact name + Team ID:
   ```bash
   security find-identity -v -p codesigning
   # → "Developer ID Application: Your Name (TEAMID)"
   ```

### 2. Notarization credentials (App Store Connect API key — best for CI)
1. https://appstoreconnect.apple.com ▸ **Users and Access ▸ Integrations ▸ App Store Connect
   API ▸ +**. Role: **Developer**. Download the `AuthKey_XXXX.p8` (you can only download once).
2. Note the **Key ID** and the **Issuer ID** shown on that page.
3. Save it locally for the manual flow:
   ```bash
   xcrun notarytool store-credentials TempoKeyNotary \
     --key /path/to/AuthKey_XXXX.p8 --key-id <KEY_ID> --issuer <ISSUER_ID>
   ```

### 3. Set the app version
Edit `project.yml` → `MARKETING_VERSION` (e.g. `1.0.0`) and bump `CURRENT_PROJECT_VERSION`,
then `xcodegen generate`. The DMG is named from `MARKETING_VERSION`; keep it equal to your tag.

---

## Option A — Release from your Mac (simplest to start)

```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="TempoKeyNotary"

# builds → signs → notarizes → staples → makes dist/TempoKey-<version>.dmg
./scripts/package-dmg.sh

# sanity check (should say: accepted, source=Notarized Developer ID)
spctl -a -vvv -t open --context context:primary-signature dist/TempoKey-*.dmg

# publish to GitHub (needs the `gh` CLI: brew install gh && gh auth login)
git tag v1.0.0 && git push origin v1.0.0
gh release create v1.0.0 dist/TempoKey-*.dmg \
  --title "TempoKey 1.0.0" --generate-notes
```

That's a real, downloadable, "opens on any Mac" release.

---

## Option B — Automated release on tag push (GitHub Actions)

The workflow at [`.github/workflows/release.yml`](../.github/workflows/release.yml) builds,
signs, notarizes, and publishes a DMG whenever you push a `v*` tag. Set these up once:

### Convert your secrets to base64
```bash
# Developer ID cert: export from Keychain Access → "Certificate Assistant" is not needed;
# right-click the "Developer ID Application" cert ▸ Export… ▸ .p12 (set a password), then:
base64 -i DeveloperID.p12 | pbcopy        # → DEVELOPER_ID_CERT_P12_BASE64
base64 -i AuthKey_XXXX.p8 | pbcopy        # → NOTARY_KEY_P8_BASE64
```

### Add repository secrets
GitHub repo ▸ **Settings ▸ Secrets and variables ▸ Actions ▸ New repository secret**:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERT_P12_BASE64` | base64 of your exported `.p12` |
| `DEVELOPER_ID_CERT_PASSWORD` | the password you set when exporting the `.p12` |
| `DEVELOPER_ID_NAME` | `Developer ID Application: Your Name (TEAMID)` |
| `KEYCHAIN_PASSWORD` | any random string (temp CI keychain) |
| `NOTARY_KEY_P8_BASE64` | base64 of `AuthKey_XXXX.p8` |
| `NOTARY_KEY_ID` | App Store Connect API **Key ID** |
| `NOTARY_ISSUER_ID` | App Store Connect API **Issuer ID** |

### Cut a release
```bash
# bump MARKETING_VERSION in project.yml to match, commit, then:
git tag v1.0.0
git push origin v1.0.0
```
Actions builds + notarizes and attaches `TempoKey-1.0.0.dmg` to a new GitHub Release.
(You can also trigger it manually from the Actions tab via *workflow_dispatch*.)

---

## Verify on a clean machine (recommended once)

On another Mac (or a fresh user account), download the DMG from the Release page, open it,
drag to Applications, launch. It should open with no warning. To prove the quarantine path:
```bash
xattr -p com.apple.quarantine /Applications/TempoKey.app   # quarantine attr present
spctl -a -vvv /Applications/TempoKey.app                   # → accepted (Notarized Developer ID)
```

---

## Troubleshooting

- **"TempoKey is damaged and can't be opened"** → the build was ad-hoc/unsigned, or not
  notarized/stapled. Re-run with `DEVELOPER_ID` + `NOTARY_PROFILE` set.
- **`notarytool` returns `Invalid`** → run `xcrun notarytool log <submission-id>
  --keychain-profile TempoKeyNotary` to see which file/entitlement failed. Common causes:
  missing hardened runtime, or `get-task-allow` present (our `package-dmg.sh` re-signs with
  `TempoKeyApp/TempoKey.entitlements`, which omits it).
- **CI can't find the signing identity** → the keychain import step failed; check
  `DEVELOPER_ID_CERT_PASSWORD` and that the `.p12` actually contains the Developer ID cert + key.
- **App opens but can't read dropped files** → expected only if entitlements are wrong; Release
  ships the sandbox + `user-selected.read-only` entitlement, which `package-dmg.sh` applies.

See [`docs/RELEASING.md`](RELEASING.md) for the underlying signing/notarization concepts.
