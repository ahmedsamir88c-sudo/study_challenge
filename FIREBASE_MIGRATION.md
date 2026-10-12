# Firebase migration setup

The Flutter app now uses Firebase Authentication for new student-ID/password
accounts (with a contact email stored in the Firestore profile) and
Firestore-backed user profiles. This repository intentionally
does not contain a Firebase project configuration or service-account key.
Create a Firebase project and configure it before running the app against live
services. Existing Django data is not imported; new Firebase accounts start
with empty profiles.

## Firebase project setup

1. Create a Firebase project in the Firebase Console.
2. Enable **Authentication → Email/Password**, **Cloud Firestore**, and
   **Cloud Storage**.
3. Install Firebase CLI and log in, then install Node.js 22 and npm.
4. From the `firebase` directory, deploy rules, indexes, and Cloud Functions:

   ```powershell
   cd firebase
   npm --prefix functions install
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project YOUR_FIREBASE_PROJECT_ID
   ```

   Configure the `GEMINI_API_KEY` Functions secret before using AI features:

   ```powershell
   firebase functions:secrets:set GEMINI_API_KEY --project YOUR_FIREBASE_PROJECT_ID
   ```

5. Add Android, iOS, and/or Web apps to the same Firebase project. For Android,
   download the matching `google-services.json` into `mobile/android/app/`;
   the app initializes from the native Google Services configuration. The
   Android package name in the file must match `applicationId` in
   `mobile/android/app/build.gradle.kts`. For iOS and Web, start the app with
   the public Firebase app configuration passed as Dart defines:

   ```powershell
   cd mobile
   flutter run -d emulator-5554 `
     --dart-define=FIREBASE_API_KEY=YOUR_WEB_API_KEY `
     --dart-define=FIREBASE_APP_ID=YOUR_ANDROID_APP_ID `
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID `
     --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID `
     --dart-define=FIREBASE_STORAGE_BUCKET=YOUR_FIREBASE_PROJECT_ID.firebasestorage.app
   ```

   Add `FIREBASE_AUTH_DOMAIN=YOUR_FIREBASE_PROJECT_ID.firebaseapp.com` for
   Web. Firebase client configuration is not a service-account credential;
   access control is enforced by Firestore and Storage rules.

6. Registration creates a Firebase Authentication account using a
   deterministic, syntactically valid internal email derived from the student
   ID and using this Firebase project's `firebaseapp.com` domain; users sign
   in with that ID and password. The supplied contact email is stored in the
   Firestore profile, but is not used as the login credential. Legacy
   accounts created with email credentials can still sign in using their
   email. Registration also uses one atomic Firestore batch that creates
   `users/{uid}` and reserves the unique
   username and university ID. It does not call a Cloud Function. Deploy the
   Firestore rules before testing registration; those rules allow only
   validated self-registration and do not allow clients to modify reservations.
7. To grant an owner account, set the Firebase Auth custom claim `owner: true`
   using a trusted Admin SDK script, and assign its profile `role: "owner"`.
   Never grant this role from an app client.

If registration reports `operation-not-allowed`, Email/Password sign-in is
disabled for the configured Firebase project. Enable it in **Firebase Console
→ Authentication → Sign-in method → Email/Password**. Firestore rule failures
are reported separately as Firestore errors and are not Firebase Auth
`operation-not-allowed` errors.

For Android Auth errors mentioning reCAPTCHA, app verification, or an
otherwise unexplained `unknown` error, add the signing certificate SHA-1 and
SHA-256 fingerprints to **Firebase Console → Project settings → Your apps →
Android app**. The debug fingerprints depend on the machine's debug keystore;
release builds require the release signing certificate fingerprints too.
Download the updated `google-services.json` after changing the app settings.

## Firestore connectivity check

`mobile/lib/services/firestore_health_check_service.dart` provides
`FirestoreHealthCheckService.verifyReadWrite()`. Call it after Firebase is
initialized and a user is signed in. Each invocation performs one write and
one server-backed read of the same `firestoreHealthChecks/{uid}` document. It
reuses that single document per user, creates no listeners, and does not use
Storage or paid database features. Deploy the Firestore rules before calling
the check. The `cloud_firestore` dependency is already declared in
`mobile/pubspec.yaml`.

## Firestore document layout

- `users/{uid}` — Auth-linked profile, role, academic year, XP, status, streak.
- `usernames/{lowercaseUsername}` and `universityIds/{universityId}` — private
  uniqueness reservations created atomically with the matching user profile;
  clients cannot read, update, or delete them.
- `academicYears/{yearId}`, `subjects/{subjectId}`, `lectures/{lectureId}` —
  published academic hierarchy.
- `materials/{materialId}` and `studyMaterials/{path}` in Storage — metadata
  and owner-uploaded material files.
- `lectureChunks/{chunkId}` — extracted source text for search and AI.
- `questionBank/{questionId}` — answer keys and explanations; never readable by
  Flutter directly.
- `quizAttempts/{attemptId}` — server-created attempt and trusted score.
- `users/{uid}/dailyChallenges/{yyyy-MM-dd}` and
  `users/{uid}/reviewItems/{itemId}` — challenge and review progress.
- `users/{uid}/studyPlans/{planId}`, `users/{uid}/notifications/{id}`, and
  `users/{uid}/preferences/settings` — user-owned study data.

Quiz generation, answer grading, XP awards, and AI calls run in trusted Cloud
Functions. Long-running document extraction still needs a Cloud Run worker or
another trusted processor before uploaded materials can supply quiz and AI
content. The Firestore and Storage rules deny direct client access to answer
keys and server-owned scoring fields.

## Current migration boundary

The Flutter API client still uses callable functions for some non-auth
features; these require a plan that supports Cloud Functions and are not part
of the Spark-only registration flow. Direct authentication, profile creation,
and the Firestore data protected by the deployed rules do not require Cloud
Functions. Other migration gaps remain, including file-content extraction and
some owner/study features. Do not treat the entire app as Spark-only until all
remaining callable-function dependencies have been removed or replaced.
