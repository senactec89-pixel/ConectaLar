# E-mail and FCM notifications

## Critical e-mail

The API keeps its in-app notification as the primary record. It sends an additional plain-text SMTP e-mail for important request lifecycle changes, completion and attendance incidents, rescheduling, quotes, professional document decisions, and report status updates. Chat messages and reviews are deliberately excluded to avoid noisy e-mail and unnecessary disclosure.

Only active accounts with a verified e-mail address receive these notices. The e-mail contains the existing short notification title and message, not a service address, uploaded document, report evidence, or chat content. SMTP uses the existing `SMTP_*` variables documented in `.env.example`. A sending failure does not roll back the underlying operation; the API records a generic log event without logging addresses, message bodies, or SMTP credentials.

This first version attempts SMTP delivery during notification creation and does not have a persistent outbox or automatic retry. For production-critical delivery, add a durable queue/outbox, retry limits, and delivery monitoring before promising guaranteed delivery.

## Firebase Cloud Messaging readiness

The API and Flutter app now contain the FCM delivery path. It is disabled by default and cannot deliver until Firebase and each target platform are configured. Do not enable `FCM_ENABLED` until the migration and real-device checks below are complete.

1. Create or select the ConectaLar Firebase project and register the Android app using the exact application ID from the Flutter Android Gradle configuration.
2. Add the Firebase Android app's public configuration to the APK build using the `FIREBASE_*` dart-defines below. These values are client configuration, not the Admin service-account key.
3. Apply migration `1760148000000-DispositivosPush` to the target database before restarting the API.
4. Create a Firebase service account with only the Firebase Cloud Messaging API Admin role. Put its project ID, email, and private key in the VPS deployment environment. Encode line breaks in `FCM_PRIVATE_KEY` as `\n`; protect the `.env` file and never commit, paste, or put this key in an APK.
5. Set `FCM_ENABLED=true` only after the other server values are present. The API registers/revokes device tokens for the authenticated user, prunes tokens rejected as invalid by FCM, and sends notifications best-effort. Push errors do not roll back a service operation. Delivery currently has no durable retry queue.
6. Build and install a debug APK with the same Firebase project, grant notification permission from the in-app notification center, then test foreground, background, and terminated states. Confirm logout removes the device token. Do not use a release build until its signing certificate is registered where required.
7. iOS additionally needs its Firebase app registration, APNs authentication key/capability, and a signed build tested on an Apple device. Web/PWA push is not wired in this implementation.

API variables are `FCM_ENABLED`, `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, and `FCM_PRIVATE_KEY`. Flutter Android build values are `CONECTALAR_FCM_ENABLED=true`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, and `FIREBASE_ANDROID_API_KEY`. For iOS use the corresponding `FIREBASE_IOS_*` values. The app requests permission only after the user taps "Ativar notificacoes push neste aparelho"; it does not send chat content, addresses, or credentials in push messages. Tapping a push opens the authenticated in-app notification center, which fetches protected details from the API.

Before production enablement, update the privacy data inventory and user-facing notice to disclose that the device token is stored for push delivery and shared with Firebase/Google for that purpose, how permission can be withdrawn, and how tokens are deleted on logout or account deletion. Agree on retention and have the notice reviewed as part of the privacy/legal checklist.

Keep the key types separate: the Firebase client API key belongs only to the Firebase app configuration; `GOOGLE_MAPS_ANDROID_API_KEY` renders the Android map; `GOOGLE_MAPS_SERVER_API_KEY` is server-side Geocoding and belongs only in the API environment.
