# Learnova AI

An AI-powered study assistant for students — notes, summaries, quizzes,
flashcards, study roadmaps, GPA tracking and reminders, in one Flutter app.

Final-year Computer Science project.

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase&logoColor=black">
  <img alt="Gemini" src="https://img.shields.io/badge/Gemini-2.5%20Flash-4285F4?logo=google&logoColor=white">
</p>

---

## What it does

Eleven modules around a single dashboard. Five of them are AI-backed; the rest
are ordinary app features that the AI modules build on.

| Module | What it does | Backed by |
|---|---|---|
| **Notes** | Create, edit and organise study notes | Firestore |
| **AI Chatbot** | Ask academic questions, with conversation history | Gemini |
| **AI Summarizer** | Condense long notes into revision-sized summaries | Gemini |
| **AI Quiz Generator** | Turn any topic or note into a practice quiz | Gemini |
| **AI Flashcards** | Generate cards and study them in a flip-card mode | Gemini |
| **AI Study Roadmap** | Plan a syllabus into ordered, dated study sessions | Gemini |
| **Progress** | Study analytics across modules | Firestore |
| **Reminders** | Scheduled local notifications for study sessions | flutter_local_notifications |
| **GPA Calculator** | Track grades and compute GPA | Local |
| **Study Materials** | Upload and summarise course files | Firebase Storage + Gemini |
| **Settings** | Profile, theme and notification preferences | Firestore |

Authentication covers registration, sign-in, OTP verification, and password
reset by email link — 28 screens and 15 services in total.

---

## Architecture

```
lib/
├── config/       API configuration (git-ignored - see Setup)
├── models/       Feature enum, notes, quizzes, flashcards, roadmaps, chat
├── services/     One per capability: auth, gemini, notes, flashcards,
│                 roadmap, reminders, notifications, GPA, materials, OTP,
│                 password reset, preferences, history, learning stats,
│                 deep links
├── screens/      28 screens, including a flip-card flashcard study mode
└── widgets/      Shared UI
```

Services own all I/O — Firebase calls and Gemini requests live there, never in
a screen. A screen decides what to show; a service decides how to get it. That
separation is what keeps the AI modules testable and makes swapping the model
a one-file change.

---

## Setup

### Prerequisites

- Flutter 3.x
- A Firebase project (Authentication, Firestore, Storage)
- A Gemini API key — free from [Google AI Studio](https://aistudio.google.com/apikey)

### 1. Install

```bash
git clone https://github.com/<your-username>/Learnova-AI.git
cd Learnova-AI
flutter pub get
```

### 2. Add your Gemini key

`lib/config/api_config.dart` is **git-ignored** because it holds a live,
billable API key. Copy the example and fill in your own:

```bash
cp lib/config/api_config.example.dart lib/config/api_config.dart
```

Then replace `PASTE_YOUR_GEMINI_API_KEY_HERE` with your key.

The app checks for this at startup — `ApiConfig.isKeyMissing` is true while the
placeholder is still in place, so AI features fail with a clear message rather
than an opaque HTTP error.

### 3. Connect your own Firebase project

`android/app/google-services.json` is also git-ignored. Create a Firebase
project, register an Android app, and download your own config file into that
path.

Google designs these client keys to ship inside an app, so this one is not a
secret in the way a server key is — the protection is Firebase Security Rules
and API key restrictions, not secrecy. It is excluded anyway, so that a fork
cannot silently write into this project's Firebase instance.

Enable in the Firebase console:

- **Authentication** — Email/Password
- **Firestore Database**
- **Storage** (for the Study Materials module)

### 4. Run

```bash
flutter run
```

---

## Notes on the AI integration

**One service, one model.** Every AI module goes through
`lib/services/gemini_service.dart`, which owns the request shape, the model
name and the error handling. Changing model — or provider — touches one file.

**The model returns JSON, and JSON from a model cannot be trusted.** Quizzes,
flashcards and roadmaps are parsed through explicit `fromJson` constructors on
each model class, so a malformed or unexpected response produces a handled
parse failure rather than a crash deep in a widget build.

**Gemini 2.5 Flash** is used throughout — fast enough that a student is not
waiting on a summary, and cheap enough to run on a free tier.

---

## Project status

Feature-complete for its scope. Known gaps, stated rather than left to be
discovered:

- No automated test suite; verification has been manual.
- Android is the tested platform. iOS and desktop targets are present in the
  project but have not been built or run.
- The app package name is still `com.example.ai_student_dev` — it would need a
  real identifier before any store release.
- No offline mode; every AI module requires a connection.

---

## Author

**Hari** — final-year Computer Science student.

- GitHub: [@hari20050803-beep](https://github.com/hari20050803-beep)
