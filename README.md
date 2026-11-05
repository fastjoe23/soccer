# Garmin Connect IQ Soccer Tracker

A standalone Garmin Wearable Application ("Device App") designed specifically for recording soccer matches. It allows players and referees to track match scores dynamically via physical hardware buttons while simultaneously recording performance metrics (heart rate, distance, and activity duration) directly into a native Garmin FIT activity session.

---

## Features

* **Ergonomic Score Tracking:** Log goals for Team A and Team B instantly using hardware buttons, backed by smart input-filtering to correct accidental presses.
* **High Intensity Tracking (HIT):** Dynamically tracks and accumulates the exact training duration spent within the red heart rate zone (Zone 4).
* **Native FIT File Injection:** Automatically writes final scores (Goals A/B) and HIT minutes as custom Developer Fields into the `.FIT` activity file for seamless syncing with Garmin Connect.
* **Indoor & Outdoor Modes:** Switch between GPS-enabled outdoor match tracking and power-saving indoor tracking for indoor or futsal arenas.
* **Multi-Page Sports Interface:** Smoothly cycle through the Scoreboard, Fitness Metrics, and the Current Time using native swipe or button gestures during live gameplay.
* **Goalkeeper Rotation:** Optional countdown on the scoreboard (default 5 min, configurable 0–60 min). When it expires, the watch vibrates and shows a "GK CHANGE!" alert on every page. Hold **DOWN** (~0.8 s) on the scoreboard to confirm a change manually and restart the countdown. The number of changes is written to the FIT file.
* **Match Recovery:** The score is persisted during the match. If the app is terminated unexpectedly, the running activity is saved and on the next launch the app offers to continue the previous match (within 3 hours).
* **GPS Status Before Kick-off:** In outdoor mode the GPS starts searching as soon as the app opens; the start page shows the fix quality (red / orange / yellow / green "GPS OK").
* **Extended Summary:** The result screen additionally shows HIT minutes, sprints (outdoor) and goalkeeper changes.
* **Phone Settings:** Indoor mode and the goalkeeper interval can also be changed in the Connect IQ app on the phone.

---
## Architecture (Model-View-Controller)

The application strictly implements the **MVC (Model-View-Controller)** pattern to decouple the core gameplay state, the rendering pipeline, and the physical hardware inputs:
````
[ SoccerApp ] (Application Entry Point)
        │
        ▼
 [ SoccerModel ] <───────┐ (Mutates State & Handles FIT Session)
        │                │
        ├──────────────┐ │
        ▼              ▼ │
 [ SoccerView ]   [ SoccerDelegate ] (Interceptors for Physical Keys)
 ````

### 1. The Model (`SoccerModel.mc`)
Acts as the single source of truth. It manages the runtime state (scores, active page, metrics), subscribes to system sensor streams, and manages the lifecycle of the `ActivityRecording.Session`.

### 2. The Views (`SoccerView.mc` & `SoccerSummaryView.mc`)
Responsible for layout rendering onto the Device Context (`dc`). It reads properties directly from the Model and handles lifecycle transitions, such as displaying a comprehensive statistical summary page after a match is saved.

### 3. The Controllers (`SoccerDelegate.mc` & Menu Delegates)
Hardware input interceptors. They capture physical button presses (Start, Back, Up-Longpress) and translate them into deterministic state transitions within the Model.

---

---
## Controls

| Button | Scoreboard page | Other pages |
|---|---|---|
| START (single press) | Goal Team A (during the match) | Start match / pause menu (resume, save, discard) |
| START (double press) | Undo goal Team A | – |
| BACK (single press) | Goal Team B | – |
| BACK (double press) | Undo goal Team B | – |
| DOWN (short press) | Next page | Next page |
| DOWN (hold ~0.8 s) | Confirm goalkeeper change | – |
| UP (hold) | Settings (before the match) | Settings (before the match) |

---
## Building

The project uses strict type checking and compiler optimizations (see `monkey.jungle`):

```
monkeyc -f monkey.jungle -d fenix7 -y developer_key.der -o bin/soccer.prg
monkeyc -f monkey.jungle -d fenix7 -y developer_key.der -o bin/test.prg -t   # unit tests
```

A GitHub Actions workflow (`.github/workflows/build.yml`) builds the app and runs the unit tests. It needs the repository secrets `GARMIN_USERNAME` / `GARMIN_PASSWORD` and the variable `GARMIN_AGREEMENT_HASH` (from `connect-iq-sdk-manager agreement view`) to download the SDK and device files.

