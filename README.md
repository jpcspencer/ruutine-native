# Ruutine — AI Workout Tracker

<img width="1320" height="2868" alt="home" src="https://github.com/user-attachments/assets/5935d9e7-150d-4d83-8d19-f2cb3103cea0" />

 
A native SwiftUI iOS app for serious lifters, live on the App Store. Track workouts, follow AI-generated training programs, and get coaching from **Ruu**, an AI coach that learns your training over time.
 
**[Download on the App Store →](https://apps.apple.com/app/ruutine-ai-workout-tracker/id6767207604)**
 
<!-- TODO: Add a screenshot or App Store badge here. A single screenshot of the home dashboard or an active workout has the highest impact. Example:
![Ruutine](docs/screenshot.png)
-->
 
---
 
## What it does
 
- **Workout logging** — log sets, reps, and weight with previous-session values pre-filled, a built-in rest timer, and full session editing.
- **Ruu, the AI coach** — generates personalized training programs from your goals, experience, and available equipment, then adapts as you train. Chat with Ruu for in-context coaching tied to your real history.
- **Live Activity** — an ongoing-workout Live Activity on the Lock Screen and Dynamic Island, with a synced rest timer.
- **Progress at a glance** — training streak, weekly volume, a muscles-trained heatmap, and full session history.
- **Unit-aware** — full metric/imperial support for both weight and distance, stored canonically and converted at the display layer.
## Architecture
 
Ruutine is built as two repositories sharing one backend:
 
- **`ruutine-native`** (this repo) — the native SwiftUI iOS client.
- **[`ruutine`](https://github.com/jpcspencer/ruutine)** — the backend and web app: database access, authentication, and the AI coaching routes, plus the marketing site. Deployed on Vercel.
This split keeps the iOS app focused on the experience while centralizing data, secrets, and AI logic server-side.
 
## Stack
 
- **SwiftUI** — native iOS front-end (iOS 16.6+), including a Live Activity widget extension via ActivityKit.
- **Supabase** — authentication, Postgres database, and storage, with row-level security.
- **Claude** — powers Ruu's program generation and coaching, with the system prompt and persona managed server-side.
## Engineering notes
 
A few things this codebase reflects:
 
- **Data integrity first** — workouts persist locally through the app lifecycle (backgrounding, relaunch) so an in-progress session is never lost, and all weights/distances are stored in canonical units with conversion handled in a single shared layer.
- **Secure auth** — email/password with confirmation, password reset, and enumeration-safe error handling, built on Supabase Auth with an implicit flow tuned for browser-completed resets.
- **Native polish** — haptics, sound design, a branded confirm-dialog system, and gendered muscle maps.
## Development
 
Built with an AI-assisted workflow (Cursor + Claude) directing the implementation, with all architecture, data-model, and product decisions made and reviewed by hand. The commit history reflects iterative, tested changes shipped as real App Store updates.
 
---
 
*Built by [Jordan Spencer](https://jpcspencer.com) · [github.com/jpcspencer](https://github.com/jpcspencer)*
 
