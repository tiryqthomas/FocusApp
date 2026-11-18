# SleepKey

Lock distracting iPhone apps with a tap of an NFC card. Choose a mode (Work, Sleep and so on), hold a paired card to the phone, and the mode's apps are blocked until a paired card is tapped again. You also get a few emergency unlocks each week.

Design canvas: https://claude.ai/artifact/8ckgxnZXjFVwLiA4F1UpeJ. Decisions are listed in [DESIGN.md](DESIGN.md).

## What you need

- A Mac with Xcode 26 or later
- An iPhone on iOS 26 or later. The simulator can't do NFC or Screen Time.
- A paid Apple Developer account
- NFC cards or stickers. NTAG213, NTAG215 or NTAG216 work best.

## Run it on your iPhone

1. Open `FocusCard.xcodeproj` in Xcode.
2. Click the **FocusCard** project at the top of the navigator. Under **Build Settings** for the project (not a target), set `BUNDLE_ID_PREFIX` to something unique to you, such as `com.yourname`. Every bundle ID and the App Group (`group.<prefix>.focuscard`) come from this setting.
3. For each of the four targets (FocusCard, ShieldConfig, ActivityMonitor, ActivityReport), open **Signing & Capabilities**, tick **Automatically manage signing** and choose your **Team**.
4. Connect your iPhone, select it as the run destination, and press **Run** (⌘R).
5. If the iPhone asks, turn on **Developer Mode** (Settings, then Privacy & Security), and trust your developer certificate (Settings, then General, then VPN & Device Management).

If signing complains about the App Group or Family Controls, open **Signing & Capabilities** on the target that fails. Click **+ Capability** and add **App Groups** (tick `group.<prefix>.focuscard`) or **Family Controls**, then build again.

Development builds can use Family Controls straight away. Releasing on the App Store would need Apple's Family Controls distribution approval.

## How it's built

| Folder | Target | What it does |
| --- | --- | --- |
| `FocusCard/` | App | SwiftUI screens, NFC scanning (Core NFC) and the app state |
| `Shared/` | App, ShieldConfig, ActivityMonitor | Models, App Group storage, and locking and unlocking (ManagedSettings) |
| `ShieldConfig/` | Shield configuration extension | The black screen shown when you open a blocked app |
| `ActivityMonitor/` | Device activity monitor extension | Starts scheduled modes (for example, Sleep at 11 PM) |
| `ActivityReport/` | Device activity report extension | Draws the Screen Time stats (screen time, pickups, top apps) |
| `Config/` | None | Info.plist additions and entitlements for each target |

The project uses Xcode's synchronised folders, so new files added to a folder join its target automatically.

Apple keeps Screen Time numbers inside the report extension. The app can show the stats views, but it can't read the numbers.

## Minimal Home Screen

The Minimal Home Screen guide and the "Is Focus Card Locked?" action were removed in the bedtime version.

## Status

First version, written without a compiler. It hasn't been built or run yet, so expect a few compile fixes on the first build.
