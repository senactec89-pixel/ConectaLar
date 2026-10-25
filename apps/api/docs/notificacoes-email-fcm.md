# E-mail and FCM notifications

## Critical e-mail

The API keeps its in-app notification as the primary record. It sends an additional plain-text SMTP e-mail for important request lifecycle changes, completion and attendance incidents, rescheduling, quotes, professional document decisions, and report status updates. Chat messages and reviews are deliberately excluded to avoid noisy e-mail and unnecessary disclosure.

Only active accounts with a verified e-mail address receive these notices. The e-mail contains the existing short notification title and message, not a service address, uploaded document, report evidence, or chat content. SMTP uses the existing `SMTP_*` variables documented in `.env.example`. A sending failure does not roll back the underlying operation; the API records a generic log event without logging addresses, message bodies, or SMTP credentials.

This first version attempts SMTP delivery during notification creation and does not have a persistent outbox or automatic retry. For production-critical delivery, add a durable queue/outbox, retry limits, and delivery monitoring before promising guaranteed delivery.

## Firebase Cloud Messaging readiness

FCM is not active. The `.env.example` contains disabled server-side configuration placeholders only. Do not set `FCM_ENABLED=true` yet: the project still needs all of the following:

1. Create or select the ConectaLar Firebase project and register the Android app using the exact application ID from the Flutter Android Gradle configuration.
2. Add the Firebase Android configuration to the Flutter project using FlutterFire, then confirm that no service-account private key or production secret is committed.
3. Add an authenticated API workflow for registering and revoking a device's FCM token, with ownership tied to the current user and support for token rotation.
4. Add the Firebase Admin SDK on the API and load a least-privilege service account from deployment secrets. Keep its private key out of `.env.example`, source control, client builds, and logs.
5. Implement delivery, invalid-token cleanup, and failure monitoring; test foreground/background behavior and notification permission on real Android devices.

The server-side variables reserved for that integration are `FCM_ENABLED`, `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, and `FCM_PRIVATE_KEY`. Do not place Firebase Admin credentials in the Flutter app. Push payloads should contain a notification identifier and a non-sensitive route hint only; fetch protected details from the API after the user opens the app.
