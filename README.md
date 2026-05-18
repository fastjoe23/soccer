# Garmin Connect IQ Soccer Tracker

A standalone Garmin Wearable Application ("Device App") designed specifically for recording soccer matches. It allows players and referees to track match scores dynamically via physical hardware buttons while simultaneously recording performance metrics (heart rate, distance, and activity duration) directly into a native Garmin FIT activity session.

---

## Features

* **Ergonomic Score Tracking:** Log goals for Team A and Team B instantly using hardware buttons, backed by smart input-filtering to correct accidental presses.
* **High Intensity Tracking (HIT):** Dynamically tracks and accumulates the exact training duration spent within the red heart rate zone (Zone 4).
* **Native FIT File Injection:** Automatically writes final scores (Goals A/B) and HIT minutes as custom Developer Fields into the `.FIT` activity file for seamless syncing with Garmin Connect.
* **Indoor & Outdoor Modes:** Switch between GPS-enabled outdoor match tracking and power-saving indoor tracking for indoor or futsal arenas.
* **Multi-Page Sports Interface:** Smoothly cycle through the Scoreboard, Fitness Metrics, and the Current Time using native swipe or button gestures during live gameplay.

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
