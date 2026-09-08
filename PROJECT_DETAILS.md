# Learnova AI — Full Project Details

**AI-Powered Student Academic Assistant** · Flutter final-year project (Android & iOS)
Repo folder: `ai_student_dev` · Version `1.0.0+1` · App display name **Learnova AI**

Last consolidated: 2026-07-26

---

## 1. What the app is

A single mobile app that a student uses for their whole academic workflow: keeping notes and
materials, generating AI study aids (summaries, quizzes, flashcards, roadmaps), asking an AI
academic chatbot, tracking GPA and progress, and getting local study reminders. Every student's
data is private to their own Firebase account.

- **Frontend:** Flutter (Dart SDK `^3.12.1`), Material 3, built-in widgets only (no external
  animation packages — deliberate constraint so the code stays student-readable).
- **Auth + database:** Firebase Auth (Email/Password) + Cloud Firestore.
- **AI:** Google Gemini `gemini-2.5-flash` over plain REST (`http` package, no SDK).
- **Notifications:** `flutter_local_notifications` v22 (local only — no APNs / FCM push).
- **Total app code:** ~13,300 lines across 60 Dart files.

---

## 2. Tech stack / dependencies

| Package | Version | Used for |
|---|---|---|
| `firebase_core` | ^4.10.0 | Firebase init |
| `firebase_auth` | ^6.5.2 | register / login / reset / signOut |
| `cloud_firestore` | ^6.5.0 | all user data |
| `firebase_storage` | ^13.4.2 | material file upload + avatar (**gated, see §9**) |
| `http` | ^1.6.0 | Gemini REST calls |
| `flutter_local_notifications` | ^22.0.0 | study reminders |
| `timezone` / `flutter_timezone` | ^0.11.0 / ^5.1.0 | correct local scheduling |
| `image_picker` | ^1.2.2 | avatar + image pick |
| `file_selector` | ^1.1.0 | document pick (**not** `file_picker` — see §11) |
| `url_launcher` | ^6.3.2 | open study-material links |
| `shared_preferences` | ^2.3.0 | persist theme + notification toggle |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

Dev/build-time only: `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.1`,
`flutter_native_splash ^2.4.3`.

---

## 3. Project structure (`lib/`)

```
lib/
├── main.dart                    # Firebase init, saved prefs → themeNotifier, MaterialApp
├── config/api_config.dart       # Gemini API key + model name (gemini-2.5-flash)
├── theme/
│   ├── app_colors.dart          # brand palette + per-theme helpers
│   └── app_theme.dart           # light/dark ThemeData + themeNotifier (ValueNotifier)
├── models/                      # 12 plain data classes (fromDoc / toMap / copyWith)
│   ├── feature.dart             # FeatureType enum + the 11 dashboard cards
│   ├── user_profile.dart  chat_message.dart  chat_session.dart
│   ├── note.dart  study_material.dart  study_reminder.dart
│   ├── quiz_question.dart  quiz_result.dart  summary_entry.dart
│   ├── flashcard.dart  study_roadmap.dart  gpa_record.dart
│   └── dashboard_stats.dart
├── services/                    # 11 singletons, each with its own friendly *Exception
│   ├── auth_service.dart        gemini_service.dart      history_service.dart
│   ├── note_service.dart        material_service.dart    reminder_service.dart
│   ├── notification_service.dart gpa_service.dart        flashcard_service.dart
│   ├── roadmap_service.dart     preferences_service.dart
├── screens/                     # 22 screens
│   ├── splash_screen.dart  login_screen.dart  register_screen.dart
│   ├── forgot_password_screen.dart  dashboard_screen.dart  feature_screen.dart
│   ├── notes_screen.dart  note_editor_screen.dart
│   ├── summarizer_screen.dart  quiz_screen.dart  chatbot_screen.dart
│   ├── flashcards_screen.dart  flashcard_study_screen.dart
│   ├── roadmap_screen.dart  roadmap_detail_screen.dart
│   ├── materials_screen.dart  material_form_screen.dart
│   ├── reminders_screen.dart  reminder_form_screen.dart
│   ├── gpa_screen.dart  progress_screen.dart
│   └── settings_screen.dart  edit_profile_screen.dart
├── widgets/                     # gradient_button, gradient_header, dashboard_card,
│                                # logo_box, profile_avatar, empty_state, press_scale,
│                                # animations
└── utils/                       # smooth_route.dart (page transition), format_date.dart
```

Design rule followed throughout: **model → service → screen**, one service per feature, all
Firestore paths scoped under `users/{uid}/…`.

---

## 4. Branding & theming

- **Logo:** only `assets/images/learnova_logo.png` is ever used (hard constraint — never
  generate or fetch another). It is a **wide 1600×520 wordmark** (book/star symbol + "Learnova AI"
  text, transparent background).
- **Derived icon:** `assets/images/learnova_icon.png` — 1024×1024 transparent square crop of just
  the symbol (produced via PowerShell `System.Drawing`, srcRect 45,0,520,520 → dest 182,182,660,660),
  because the wordmark is too wide for a square launcher icon.
- **Brand gradient:** blue `#3D5AF1` → indigo `#4F46E5` → purple `#7C3AED`
  (`AppColors.mainGradient` = blue→purple, topLeft→bottomRight).
- **Light theme:** bg `#F8F9FE`, card white, text `#1E1B4B`, subtext `#6B7280`.
- **Dark theme:** bg `#0B1023` (dark navy, not black), card `#161C36`, text `#EDEDFB`,
  subtext `#9CA3C0`; cards get a 6%-white border + heavier shadow so they stay visible.
- **Launcher icon:** adaptive — white `#FFFFFF` background + symbol foreground; legacy uses the
  same symbol. Generated for Android (`mipmap-*`, `mipmap-anydpi-v26/ic_launcher.xml`) and iOS
  (`AppIcon.appiconset`).
- **Native splash:** light `#FFFFFF` + full logo; dark `#0B1023` + symbol (the wordmark is dark
  navy, so it would be invisible on the dark background — that's why dark and Android 12 use the
  symbol). `main.dart` / `splash_screen.dart` were **not** touched — the native splash auto-removes
  on first frame and the existing animated splash runs unchanged.
- **App display name:** `android:label` (main manifest only) + iOS `CFBundleDisplayName` and
  `CFBundleName` = "Learnova AI". Package/bundle IDs unchanged (`com.example.ai_student_dev`).

Regeneration commands:

```bash
flutter pub get && dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

---

## 5. Authentication flow

Firebase project **`learnova-ai-41acf`**, Android package `com.example.ai_student_dev`,
Email/Password provider enabled.

| Screen | Behaviour |
|---|---|
| **Splash** | 3 s animation, then checks `AuthService.instance.currentUser` → Dashboard if signed in, else Login (auto-login). |
| **Register** | `FirebaseAuth.createUser…` + writes `users/{uid}` doc `{uid, fullName, email, createdAt}`. |
| **Login** | `signIn()`; blank + wrong credentials blocked with friendly messages. |
| **Forgot Password** | real `AuthService.sendPasswordResetTo(email)` → `sendPasswordResetEmail`; client validation (non-empty + regex `^[^@\s]+@[^@\s]+\.[^@\s]+$`); green/red SnackBar; button spinner. |
| **Logout** (Dashboard + Settings) | `signOut()` + `pushAndRemoveUntil((route) => false)` so the nav stack is fully cleared. |

`auth_service.dart` (singleton, `AuthException` with friendly text) exposes:
`register()`, `signIn()`, `signOut()`, `loadProfile()`, `updateProfile()`, `uploadAvatar()`,
`sendPasswordResetEmail()` (logged-in user, used by Settings → Change Password),
`sendPasswordResetTo(email)` (Forgot Password, nobody logged in), plus an in-memory
`localAvatarBytes` fallback that is cleared on `signOut()`.

---

## 6. Gemini AI integration

`lib/config/api_config.dart` holds the key + model (`gemini-2.5-flash`); the user's real key
(new `AQ.`-style format) is applied and verified working. `gemini_service.dart` is a singleton with
`GeminiException` (friendly messages, missing key detected client-side) and one private
`_generate()` that all features share. System prompts explicitly ask for **plain text, no
markdown**, because the screens render plain text.

Public methods:

| Method | Returns | Used by |
|---|---|---|
| `askChatbot(List<ChatMessage> history)` | `String` | Chatbot (multi-turn) |
| `summarizeNotes(String notes)` | `String` | Summarizer, Note editor |
| `generateQuiz(String topic, int count)` | `List<QuizQuestion>` | Quiz Generator (JSON array parsed) |
| `generateFlashcards({content, count, subject})` | `List<Flashcard>` | Flashcards |
| `generateRoadmap({subject, examDate, studyHours, skillLevel})` | `String` | Study Roadmap |
| `summarizeFile({bytes, mimeType})` | `String` | Study Materials AI summary (**Blaze-gated**) |
| `extractReminderFromFile(...)` | `Map<String, dynamic>` | Reminders AI draft (inlineData base64 image/PDF → JSON) |

---

## 7. The 11 dashboard modules

Routing: each card carries a `FeatureType`; `dashboard_screen.dart` maps it to a screen in
`_screenFor`. **No placeholders remain — all 11 cards are real modules.**

### 1. Notes Management — `users/{uid}/notes`
Firestore only (no Storage, by request). Categories: General/Lecture/Assignment/Exam/Idea/Other.
`Note` has title/content/category/isFavorite/isPinned/createdAt/updatedAt.
`note_service.dart`: `loadNotes` orders by `updatedAt desc` then sorts pinned-first **client-side**
to avoid a composite index; `addNote/updateNote/setFavorite/setPinned/deleteNote`; `loadSummary`
uses `.count()` + `limit(1)` for the dashboard strip.
Screens: list with search + category ChoiceChips + pin/favorite per card; editor with title,
category dropdown, content, and ✨ Summarize-with-AI (needs ≥40 chars; dialog offers "Append to note").

### 2. AI Notes Summarizer
Paste/long text → `summarizeNotes` → plain-text bullets. History saved to `users/{uid}/summaries`.

### 3. AI Quiz Generator
Topic + count → Gemini returns a JSON array → parsed into `QuizQuestion` → interactive MCQ with
score. Results in `users/{uid}/quiz_history`.

### 4. AI Flashcards — `users/{uid}/flashcards`
Generate from a **topic** or **from a saved note** (picked via `NoteService.loadNotes`), 5/10/15 cards.
`Flashcard`: question/answer/subject/difficulty (Easy/Medium/Hard)/status (`new`/`known`/`revision`
lowercase keys + `statusLabel` getter)/isFavorite/createdAt; `fromJson` takes `subject` as a param
because the AI JSON only returns question/answer/difficulty.
`flashcard_service.dart`: `saveFlashcards` (WriteBatch), `loadFlashcards`, `updateStatus`,
`toggleFavorite`, `deleteFlashcard`.
Study screen: **3D flip** via `Transform` + `Matrix4.rotateY` with perspective (question = plain
card, answer = gradient face, un-mirrored), Next/Prev, `LinearProgressIndicator`,
Known / Need Revision buttons, favorite star.

### 5. AI Study Roadmap — `users/{uid}/study_roadmaps`
Form: subject + exam date (`showDatePicker`, `firstDate = today`) + skill chips
(Beginner/Intermediate/Advanced) + hours chips 1–6.
`generateRoadmap` computes days-left and requires six CAPS sections: **DAILY STUDY PLAN, WEEKLY
MILESTONES, REVISION DAYS, AI QUIZ DAYS, AI FLASHCARD REVISION DAYS, FINAL REVISION SCHEDULE** —
so the plan actually references the app's own Quiz and Flashcard features.
`StudyRoadmap` model has a `daysUntilExam` getter. Detail screen = gradient header
(subject / exam date / days left / skill / hours) + `SelectableText` plan.
"My Roadmaps" list supports open + delete (confirm dialog).

### 6. AI Academic Chatbot — `users/{uid}/chat_sessions/{sessionId}/messages`
ChatGPT-style sessions (session fields: title/createdAt/updatedAt/isPinned). `endDrawer` with
search, New Chat, pin (client-side sort, pinned first — avoids a composite index), and per-session
delete (batch). Multi-turn history is sent to Gemini. The old flat `chat_history` collection is
abandoned (orphan test data only).

### 7. GPA Calculator — `users/{uid}/gpa_records`
`GpaSubject` + `GpaRecord` + `kGradePoints` (A+ … F, 11 grades) + `gpaStatusMessage`.
Two tabs (Calculator / History). Live weighted GPA = Σ(credit × point) / Σcredit. Add/edit/delete
subject, Save Record, Clear All. Dashboard shows the latest GPA via `loadLatest`.

### 8. Study Reminders — `users/{uid}/study_reminders`
One `StudyReminder` model for four kinds: **timetable / assignment / exam / study**, with
repeat none/daily/weekly and `remindBefore` minutes (0 = "same day 8 AM" for assignments).
`notification_service.dart`: two notifications per reminder (`notifId`, `notifId + 1`),
`exactAllowWhileIdle` with an inexact fallback, stable IDs so rescheduling never duplicates,
`ValueNotifier<bool> notificationsEnabled`, `cancelAll()`, and `rescheduleAll(List<StudyReminder>)`
(skips completed and past one-time reminders, handles all repeat kinds). It stays decoupled from
`ReminderService` — the screen passes the list in.
`reminders_screen.dart`: 5 tabs + bottom Add / Upload buttons. `reminder_form_screen.dart`: one
form for all kinds, edit support, AI-draft confirm (via `extractReminderFromFile`).

### 9. Progress Dashboard
`progress_screen.dart` shows Firestore `count()` aggregates plus a merged recent-activity feed
across chats, quizzes and summaries.

### 10. Study Materials — `users/{uid}/study_materials`
`StudyMaterial` model (`kMaterialCategories`, plus `storagePath` / `summary`).
`material_service.dart`: Firestore CRUD + Storage upload/delete/`fetchBytes` +
`loadSummary` (count + most recent). Screens: search, category filter chips, favorite, open via
`url_launcher`, edit, delete, Summarize-with-AI; add/edit form supports both a **file** and a **link**.
File picking uses `file_selector` + `image_picker`. Android manifest has the `https` VIEW query for
`url_launcher`. **Link materials work fully; file upload + AI-summarize-file need Blaze (§9).**

### 11. Profile / Settings
`UserProfile` (uid/fullName/email/course/university/photoUrl/createdAt + `displayName`/`firstName`/
`initials` helpers). `settings_screen.dart` sections:
- **Profile header** — gradient-ring avatar + camera badge, name, email, `course • university`,
  "Joined D Mon YYYY" (falls back to `user.metadata.creationTime`).
- **Edit Profile** — avatar pick (gallery) + name / course / university, saved with `set(merge)`.
- **Your Activity** — 7 stat cards: chats / quizzes / summaries (`HistoryService.loadDashboardStats`),
  notes + materials (each `loadSummary`), reminders (`loadReminders().length`), latest GPA
  (`GpaService.loadLatest`).
- **Settings** — Dark Mode + Notifications toggles (both persisted).
- **About** — `showAboutDialog` with logo, Version 1.0.0.
- **Account** — Change Password (confirm → reset email), Logout (confirm dialog).

`widgets/profile_avatar.dart` picks: picked bytes > `photoUrl` > initials.
Dashboard AppBar shows the user's `ProfileAvatar` as `leading` (tap → Settings, then reloads) plus
a quick light/dark toggle, and greets `Welcome, <firstName>`.

---

## 8. Persistence & data layer

- **Firestore layout** — everything under the owner's UID:
  ```
  users/{uid}                                  profile doc
  users/{uid}/notes                            users/{uid}/study_materials
  users/{uid}/flashcards                       users/{uid}/study_roadmaps
  users/{uid}/gpa_records                      users/{uid}/study_reminders
  users/{uid}/quiz_history                     users/{uid}/summaries
  users/{uid}/chat_sessions/{sessionId}/messages
  users/{uid}/chat_history                     (legacy, abandoned)
  ```
- **Security rules** (`firestore.rules`, published to the console):
  ```
  match /users/{userId}/{document=**} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
  }
  ```
  The `{document=**}` wildcard covers every current and future subcollection. Everything else is
  denied by default.
- **Composite indexes avoided on purpose** — pinned-first ordering for notes and chat sessions is
  done client-side after a single-field `orderBy`.
- **Local prefs** — `preferences_service.dart` (singleton; keys `darkMode`, `notificationsEnabled`;
  defaults light + on). `main.dart` loads them into `themeNotifier` and
  `NotificationService.notificationsEnabled` **before** `runApp`, then attaches listeners that
  auto-save on any change — so both the Settings toggles and the dashboard quick-toggle persist
  without changes at their call sites. Verified across a cold restart.

---

## 9. Known limitation: Firebase Storage is off (Spark plan)

The Firebase project is on the **Spark** plan and the console Storage page says
*"To use Storage, upgrade your project's pricing plan."* Consequences:

| Works on Spark | Needs Blaze upgrade |
|---|---|
| Everything Firestore-based (notes, flashcards, roadmaps, GPA, reminders, chat, quizzes, summaries) | Study-material **file upload** |
| Study materials added as **links** | **AI-summarize-file** (`summarizeFile`) |
| Avatar via session-local bytes + initials fallback | Avatar **cloud sync** (`uploadAvatar`) |

The code paths are already written and fall back gracefully with friendly messages. After enabling
Storage, paste these rules:

```
match /users/{userId}/study_materials/{allPaths=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

Firestore rules already cover `study_materials` metadata via the existing wildcard.

---

## 10. Platform configuration

### Android (primary target, fully verified)
- `google-services.json` in place; Google Services Gradle plugin added manually to
  `settings.gradle.kts` + `app/build.gradle.kts`.
- Core-library **desugaring 2.1.5** enabled (required by `flutter_local_notifications`).
- Permissions + receivers: `POST_NOTIFICATIONS`, exact-alarm permission,
  `ScheduledNotificationReceiver`; `https` VIEW query for `url_launcher`.
- `android:label = "Learnova AI"` in the main manifest only (no debug/profile override).

### iOS (audited 2026-07 era, not yet built — needs a Mac)
All 13 packages support iOS. Safe additive fixes already applied (Android untouched, analyze clean):
1. `notification_service.dart` — `DarwinInitializationSettings` in init,
   `IOSFlutterLocalNotificationsPlugin.requestPermissions(alert/badge/sound)`,
   `DarwinNotificationDetails` in `_details`.
2. `ios/Runner/Info.plist` — `NSPhotoLibraryUsageDescription` (for `image_picker`).
3. `ios/Runner/AppDelegate.swift` — `UNUserNotificationCenter.current().delegate = …` for
   foreground notifications.

**Remaining iOS blockers (need a Mac and/or the Firebase console):**
- `ios/Runner/GoogleService-Info.plist` is **missing** — no iOS app is registered in
  `learnova-ai-41acf`, so Auth/Firestore/Storage will crash on iOS until it's added.
- No `firebase_options.dart` — the app relies on bare `Firebase.initializeApp()` + native config.
- Bundle ID is still the default `com.example.…`; needs a real reverse-domain ID matching the
  Firebase registration (display name is already correct).
- Firebase iOS SDK needs deployment target **≥ 13.0** (Podfile + Xcode).
- `Podfile` isn't present — generated by `pod install` on a Mac.
- Apple now requires `PrivacyInfo.xcprivacy` (2024 requirement).
- Local notifications only → **no APNs / push certificate needed.**
- Gemini works on iOS as-is (HTTPS, ATS default-OK).

---

## 11. Gotchas worth remembering

**Build / packages**
- `file_picker` is **incompatible** with this Flutter/AGP 9 setup (KGP plugins fail to compile) —
  use first-party `file_selector` (`FilePicker.pickFiles` → `openFile(acceptedTypeGroups:)`).
  `image_picker` is fine.
- `google-services.json` once arrived as `"google-services .json"` (stray space) and silently broke
  the build.
- `flutter_local_notifications` **v22 uses named parameters** for `initialize` / `cancel` /
  `zonedSchedule`; `flutter_timezone` 5 exposes `.identifier`.

**Flutter patterns**
- Bottom-sheet forms: don't use `StatefulBuilder` with parent-owned controllers — the GPA
  add-subject sheet crashed (`_dependents.isEmpty` assert + RenderFlex overflow) from parent
  `setState` during dismiss and dispose-after-await. Fix pattern: a dedicated `_SubjectSheet`
  `StatefulWidget` that owns its controllers, wrapped in `SingleChildScrollView`, returning the
  value via `Navigator.pop`; the parent calls `setState` only after the `await`.

**Emulator / adb (device `emulator-5554`; adb at `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`, not on PATH)**
- Services wedge with `Broken pipe (32)` on install → `adb emu kill` + relaunch. `adb reboot` may
  silently do nothing.
- `adb keyevent 4` doesn't pop Flutter routes (API 37 predictive back) — tap the AppBar back arrow
  at ≈(74, 208).
- Dashboard AppBar icons sit at physical **y ≈ 205** (y ≈ 60 is the status bar); body coordinates
  map as displayed × 2.
- Flashcard study screen needs `input motionevent DOWN/UP`, not `input tap`.
- Verifying scheduled alarms: `grep -c ScheduledNotificationReceiver` in `dumpsys alarm` also counts
  recently **cancelled** history (sticks around ~10) — the real signal is the
  `Pending alarms per uid: [... u0aNNN:N ...]` line. Measured OFF → 0, ON → 2, stable across cycles.

---

## 12. Housekeeping

- Two throwaway test accounts exist in Firebase Auth + Firestore from live verification
  (`notanemaiteststudent.learnova@gmail.com`, `eststudent.learnova@gmail.com`, password
  `test123456`) — safe to delete in the console.
- No Firebase CLI on the machine; console changes (rules) were made through Chrome.
- `README.md` is still the default Flutter template — this file is the real project documentation.
- `flutter analyze` is clean.

---

## 13. Verification status

Verified live on the Android emulator, end to end: register/login/forgot-password/auto-login/logout;
all three original AI features with real Gemini responses; notes create + AI summary + append + pin +
favorite; flashcards generate → save → flip → Known/Need-Revision → favorite (dark **and** light);
roadmap generate (all 6 sections) → save → reopen → delete (dark **and** light); GPA weighted
calculation 3.43 → save → history → dashboard strip → delete; reminders permission prompt, add via
form, exact alarm firing in `dumpsys`, complete → cancel, notification toggle OFF/ON rescheduling;
study materials add-link → list → favorite → open in Chrome; chat sessions search/pin/delete;
progress dashboard aggregates; settings profile header, edit profile saved to Firestore, all 7 stat
cards, dark-mode + notification prefs surviving a cold restart; launcher icon and native splash on
cold start; app drawer showing "Learnova AI".

Not verified (blocked, not broken): study-material **file upload** and **AI file summary**, avatar
**cloud sync** (all need Blaze), the reminder **AI file-upload** flow end-to-end (system picker
automation is unreliable — the Gemini call path is identical to the proven text calls), and the
entire **iOS** build (needs a Mac).
