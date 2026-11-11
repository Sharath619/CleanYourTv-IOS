# CleanYourTV for iPhone & iPad (iOS 16+)

Native SwiftUI companion app for **CleanYourTV** with full feature parity alongside Android v2.2:

- **Obsidian Studio**: Live 16:9 TV wallpaper & Rest Mode preview with TV clock/pill/dock guide overlay, Rest Mode shortcuts (`Sharp Rest`, `Blur Rest`, `Custom Rest`), `Pure OLED Black`, `Preview Rest`, `Wake Home`, and on-phone Recent Creations history.
- **Interactive 16:9 Photo Cropper**: Pinch, drag, double-tap reset, `Fill 16:9` vs `Fit + Blur` sidebars, `1080p` / `4K UHD` export, Brightness / Contrast / Vignette tone sliders, 4 apply targets (`Home + Rest Sharp`, `Home + Blurred Rest`, `Home Only`, `Rest Mode Only`), adjustable Rest blur preview, and `Save to TV`.
- **Ambient Gradient Studio**: Real-time 8-preset ambient gradient & glow composer with corner glow toggle and vignette controls.
- **Themes & TV Library**: All curated themes + Favorites + live `Saved on TV` gallery management.
- **TV Look**: Wallpaper toggle, Dim slider & presets, App Ambient Glow, Background/Accent swatches, Columns (`4-7`), Extra Rows (`None-3`), Idle Clock timeout, and Safari Web Studio link.
- **Wi-Fi Discovery (`_cleanyourtv._tcp`)**: Apple `NWBrowser` Bonjour discovery + `/24` local Wi-Fi scan on port `8765` + manual IP entry.

---

## How to Build & Share on iPhone

Because Apple only permits compiling iOS `.ipa` binaries via Xcode on macOS:

### Option 1 — Build Free `.ipa` via GitHub Actions + Keep Active with SideStore (Recommended, No Mac)

1. **Build `CleanYourTV-iOS-unsigned.ipa` on GitHub:**
   - Push this repository to GitHub (including [`ios-app/`](.) and [`.github/workflows/build-ios-ipa.yml`](../.github/workflows/build-ios-ipa.yml)).
   - Open your repo **Actions** tab → **Build CleanYourTV iOS IPA** → **Run workflow** (or let it auto-run on push to `main`).
   - Download the **`cleanyourtv-ios-ipa`** zip artifact and unzip **`CleanYourTV-iOS-unsigned.ipa`**.

2. **One-time SideStore Setup on Windows + iPhone (Free Apple ID):**
   - Enable **Developer Mode** on iPhone (**Settings → Privacy & Security → Developer Mode**) and restart when prompted.
   - Connect your iPhone to Windows via USB and install **SideStore** onto the iPhone using **AltServer** or **iloader** with your Apple ID.
   - Generate the device pairing file on Windows with `jitterbugpair.exe`, rename the generated `.mobiledevicepairing` file extension to `.plist`, send it to your iPhone (Files/iCloud), and import it inside **SideStore**.
   - On iPhone: go to **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
   - Install **LocalDevVPN** (or **StosVPN**) from the iPhone App Store and turn its local tunnel **ON** whenever SideStore refreshes apps.

3. **Install CleanYourTV & Automate 7-Day Refresh (Never Touch PC Again):**
   - Transfer **`CleanYourTV-iOS-unsigned.ipa`** to your iPhone (**Files** app) and open/import it inside **SideStore**.
   - On first launch of **CleanYourTV**, tap **Allow** on iOS's **Local Network** permission prompt so it can discover and reach your TV on port `8765`.
   - In the iPhone **Shortcuts** app → **Automation** → create a weekly/time-of-day automation (every ~5–6 days):
     1. Turn on **LocalDevVPN** (or **StosVPN**)
     2. **Wait** 5–10 seconds (lets the local tunnel connect)
     3. SideStore → **Refresh All Apps**
   - Keep **CleanYourTV** installed (do not delete it) so refreshes renew the 7-day signature in place while preserving your TV IP, Favorites, and Recent Creations.

### Option 2 — Build & Run Directly in Xcode (on macOS)
1. Open [`CleanYourTV.xcodeproj`](CleanYourTV.xcodeproj) in Xcode 15 or newer.
2. Under **CleanYourTV target → Signing & Capabilities**, choose your Apple ID / Team and set a unique Bundle Identifier if needed.
3. Plug in an iPhone and press **Run**, or choose **Product → Archive** to distribute via TestFlight / Ad-Hoc `.ipa` ($99/yr Apple Developer account required for TestFlight / App Store).

