# Focus Card (simplified)

Scan an NFC card to block your chosen apps. Scan the same card again to unblock them. Plain Apple styling.

This branch is the core loop only, for testing. The full version (modes, schedules, emergency unlocks, lost-card recovery, stats, Y2K theme) is on `claude/first-version`, and its files are kept here under `Parked/`, which isn't part of any build target.

## Run it on your iPhone

1. Open `FocusCard.xcodeproj` in Xcode.
2. In the project's **Build Settings**, set `BUNDLE_ID_PREFIX` to something unique, such as `com.yourname`.
3. For the two targets (FocusCard, ShieldConfig), open **Signing & Capabilities** and choose your **Team**.
4. Pick your iPhone and press **Run** (⌘R). The simulator can't do NFC or Screen Time.

## Using it

1. Tap **Allow Screen Time**.
2. Tap **Pair card** and hold the card to the top of the iPhone. A blank card gets a link written to it automatically; a card that already has data is used as it is (NTAG213/215 stickers work).
3. Tap **Blocked apps** and choose apps.
4. Tap **Scan card to lock**. Tap **Scan card to unlock** and scan again to unlock.

## Bypass test list

| Try this while locked | Expected |
| --- | --- |
| Restart the phone, force-quit the app, go Home | Apps stay blocked |
| Delete Focus Card (or any app) | Not allowed while locked |
| Change the date or time | Automatic time can't be turned off while locked |
| Scan a different card | Rejected |
| Settings, Screen Time, turn off Focus Card's access | Unblocks. No code can stop this; it's your safety exit |
| Write the same text onto another sticker | Unlocks (card is identified by its text, not its chip) |

## Folders

| Folder | Target | What it does |
| --- | --- | --- |
| `FocusCard/` | App | Screens, NFC scanning and app state |
| `Shared/` | App, ShieldConfig | Models, App Group storage, lock and unlock |
| `ShieldConfig/` | Shield extension | The screen shown when you open a blocked app |
| `Config/` | None | Info.plists and entitlements |
| `Parked/` | None | Full-version code, not built |
