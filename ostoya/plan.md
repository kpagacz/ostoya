# Meditation & Exercise Timer - Development Plan

## 1. Overview
A cross-platform Flutter application designed as a highly configurable timer for meditation, exercise, or productivity. The app allows users to build complex timing plans with sequential timers, grouped looping, and custom sound alerts.

### Key Requirements
* **Precision**: Seconds-resolution timers (Hours, Minutes, Seconds).
* **Sequential Execution**: Timers run back-to-back automatically.
* **Auto-Advancement**: No user confirmation needed between timers; a sound plays and the next timer begins immediately.
* **Custom Audio**: Selectable sounds for individual timers.
* **Looping**: Individual timers or groups of timers can be looped *X* times.
* **Persistence**: Save and label individual timer groups and full plans.
* **Single Execution**: Only one plan runs at a given time.
* **Target Platforms**: Android (Primary/First phase), iOS (Secondary phase).

## 2. Architectural Design

The system will follow a clean architecture approach, heavily relying on an event-driven domain layer.

### 2.1 Domain Data Model
To support looping groups and single timers seamlessly, we can use a Composite pattern:
* `TimerNode` (Abstract): Base entity.
* `TimerItem` (Extends `TimerNode`): Contains `duration` (Duration) and `soundId` (String).
* `TimerGroup` (Extends `TimerNode`): Contains a `List<TimerNode>` and a `loopCount` (int). 
* `Plan`: The root entity containing a `TimerGroup` (or list of nodes), a `label` (String), and an `id`.

### 2.2 Pre-Scheduled, Wake-Up Driven Timer Engine
Instead of continuously ticking, the `TimerEngine` operates by scheduling events ahead of time and relying on external wake-ups. This is significantly more battery-efficient and reliable for mobile background execution.
* **Pre-calculation**: When a `Plan` is started, the engine flattens the nested structure (including loops) into a linear timeline of events (e.g., `PlaySound`, `StartNextTimer`, `FinishPlan`) with absolute timestamps.
* **Inputs/Commands from Platform**: 
    * `WakeUp(currentTimestamp)`: The platform wakes up the engine. The engine compares the timestamp against its timeline, consumes all events that are due (or overdue), and processes them in a batch.
    * `Start(Plan)`, `Pause`, `Resume`, `Stop`.
* **Outputs/Events to Platform**:
    * `ScheduleWakeUp(timestamp)`: The engine tells the platform layer exactly when it needs to be invoked next. The OS can sleep until this exact moment.
    * `PlaySound(soundId)`: Instructs the platform to play an audio file.
    * `UpdateUI(currentState)`: Emitted for the UI to passively observe. (Note: The UI can interpolate its own visual tick based on the start and end time of the current timer, rather than relying on the engine to emit events every second).

### 2.3 Platform / Infrastructure Layer
This layer handles device-specific APIs and data persistence via dependency injection (abstract interfaces implemented for each platform).
* **Audio Service**: Listens to `PlaySoundEvent`. Uses a package like `audioplayers` to play local asset sounds.
* **Optional Wake Lock (UX Feature)**: Architecturally, the app does not need the screen to stay on to function (thanks to the wake-up model). However, from a UX perspective, we should include a toggle (e.g., `wakelock_plus`) for users who want to glance at their progress during a workout or meditation without touching their phone.
* **Persistence Service**: Local database for saving Plans and Groups. Given the hierarchical data (Groups within Plans), a NoSQL database like `Isar` or `Hive` is highly recommended for Flutter, though `sqflite` can also work.
* **Background Execution & Scheduling**:
    * Because the engine uses a wake-up model, the platform layer acts as the scheduler.
    * **Android**: Can use `AlarmManager` (via `android_alarm_manager_plus` or similar) to schedule exact wake-ups for the engine. A Foreground Service might still be necessary to ensure the OS process isn't killed entirely during long meditations, keeping audio playing perfectly.
    * **iOS**: Can schedule exact local notifications to alert the user. If the app is active/backgrounded, AVAudioSession and background tasks handle the wake-up and play the custom sound.

## 3. Phased Implementation Plan

### Phase 1: Core Engine & Data Models (No UI/Platform code)
* [ ] Define domain models (`TimerItem`, `TimerGroup`, `Plan`).
* [ ] Implement the `TimerEngine` logic using Dart Streams.
* [ ] Implement recursive logic for unrolling or traversing looped `TimerGroup`s.
* [ ] Write comprehensive unit tests for the `TimerEngine` to ensure exact timing, correct sequence transitions, and proper event emission.

### Phase 2: Basic UI & Local Storage
* [ ] Setup state management (e.g., Riverpod or BLoC) to bridge the `TimerEngine` and Flutter Widgets.
* [ ] Build UI to create a simple Plan (add timers, set durations).
* [ ] Build the active timer screen (circular progress, current timer name, next timer preview).
* [ ] Integrate local database (Isar) to save and load Plans with labels.

### Phase 3: Audio & Wake Lock (Foreground App)
* [ ] Integrate audio player package.
* [ ] Map sound IDs to local asset files (e.g., gong, bell, beep).
* [ ] Connect the `PlaySoundEvent` from the engine to the audio player.
* [ ] Integrate Wake Lock to ensure the device doesn't sleep while a plan is running in the foreground.
* [ ] Add UI to configure sounds per timer and manage loops for groups.

### Phase 4: Android Background Execution (Android First)
* [ ] Implement an Android Foreground Service.
* [ ] Move the `TimerEngine` execution (or a synchronized shadow of it) into the foreground service so timers continue perfectly when the app is minimized.
* [ ] Add a persistent notification showing current timer progress with Play/Pause actions.

### Phase 5: iOS Porting & Polish
* [ ] Implement iOS background audio session capabilities to ensure timers and sounds work when the screen is locked or app is backgrounded.
* [ ] Conduct cross-platform UI/UX polish.
* [ ] Handle edge cases (phone calls interrupting audio, battery saving modes).
