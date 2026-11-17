# Focus Card design spec

Working name: Focus Card. "Brick" is avoided because an app with that name already exists.
Canvas: https://claude.ai/artifact/8ckgxnZXjFVwLiA4F1UpeJ

## Brief

- **Purpose:** cut phone distraction. You choose apps, tap a physical card to lock them, and can only unlock them by tapping a paired card again.
- **Setting:** home, desk and bedtime. It isn't a parental-control app.
- **Platform:** iPhone, portrait, iOS 26, SwiftUI in Apple's own look (see Decision 20). Light and dark follow the system, with an override in Settings.
- **Key data:** modes (name, app selection, schedule), paired card IDs, lock state, session history, emergency allowance.
- **Monetisation:** free.

## Core flow

1. First launch: welcome, then Screen Time access, then pair a first card (with Skip). Without a card, Home shows a banner.
2. Set up modes: name each one and choose its apps in Apple's picker. A mode can have an optional daily start time.
3. Lock: choose a mode, tap Lock, then hold a paired card to the phone.
4. While locked, the app is black, with a timer and the number of emergency unlocks left. Blocked apps show the shield screen.
5. Unlock: tap Unlock with card, then hold any paired card. The session is saved to the history.
6. No card nearby: emergency unlock, which is a 5-second hold, then "Are you sure?", which shows how many unlocks would be left.

## Decision log (all 2026-11-16)

| # | Decision | Choice |
| --- | --- | --- |
| 1 | Who it's for | Just Ti, installed from Xcode. No App Store yet. |
| 2 | Block lists | Several modes (Work, Sleep), each with its own app list |
| 3 | No card nearby | Card unlock, plus limited emergency unlocks |
| 4 | Cards | Several cards can be paired. Any of them works. |
| 5 | Emergency allowance | 5 a week by default, editable in Settings |
| 6 | Mode start | Card tap or a schedule. A card is always needed to unlock. |
| 7 | Concurrent modes | One mode at a time |
| 8 | Cards and modes | Any paired card locks or unlocks any mode |
| 9 | Locked look | Whole app black, with a timer (canvas screen 4) |
| 10 | Refill timing | Emergency unlocks refill every Monday |
| 11 | Emergency confirm | 5-second press and hold, then "Are you sure?" with the number of unlocks left |
| 12 | Where stats go | Stats card at the top of Home, which opens a full Stats screen |
| 13 | Stats range | Day, Week and Month switch, starting on Week |
| 14 | Stats shown | Screen time, pickups, top apps, and Focus Card stats (time locked, streak, emergency unlocks used), each with a trend against the average |
| 15 | Dumb phone mode | Minimal Home Screen through an iOS Focus and a Shortcuts automation, with a setup guide in Settings |
| 16 | Look | Y2K BlackBerry-style skin over Apple behaviours. Locked screens are black with pale-blue monospaced text and scanlines. |
| 17 | Dark mode | Follows the system. Settings can force Light or Dark. |
| 18 | Lost card | "I lost my card" on the locked screen. Two ways in, neither uses an emergency unlock: a recovery code made at setup (FC-XXXX-XXXX), or a 24-hour wait that unlocks by itself. |
| 19 | Haptics | On by default, with a switch in Settings |
| 20 | Look (replaces 16) | Apple light and dark, SF Pro, system colors. Blue marks the selection, green only the locked state. Prototype: https://claude.ai/artifact/AibhcWQBWLQ7mFYhdJxLQV (2026-11-17) |
| 21 | Home | One screen, no scrolling: screen time chart, mode capsule, label and value rows, black Lock capsule. Settings in the top bar. |
| 22 | Chart | Stacked bars by category (Social, Entertainment, Productivity, Other), Day/Week/Month. Tapping it, or its chevron, opens Stats. |
| 23 | Locked look (replaces 9) | Follows light or dark. Only the mode badge, a thin count-up timer in a ring, and the ways out. |
| 24 | Lock length | No countdowns. A lock runs until a card tap, an emergency unlock, or the recovery password. |
| 25 | Lost card (replaces 18) | Recovery password only (FC-XXXX-XXXX, made on first launch). No 24-hour wait, no "generate new" option. |
| 26 | Saving the password | A "Save Recovery Password?" prompt on launch until saved, plus "Save to Passwords" in Settings. |
| 27 | Stats screen | Range switch, category chips, smooth trend line, usage heatmap, top apps, Focus Card stats from the app's own lock history. |

## Platform limits to remember

- iPhone only reads NFC while the app shows the scan sheet, so you open the app to lock or unlock.
- Screen Time numbers are only available inside the report extension, and only for this device.
- Apps can't change the Home Screen, which is why Decision 15 uses an iOS Focus.
- Apple draws the shield screen and the NFC sheet. We only control their text, icon and colors.

## Open items

- Real app name and icon (logo and icon skill)
- Choosing schedule days (v1 runs every day)
- Coherence pass across all screens once the app runs on a device
