# app_targhe

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running tests on Windows with OneDrive

If your project is stored on OneDrive you may see test cleanup errors because
the default temporary directory points to a synced folder. To avoid this,
set `TEMP` and `TMP` to a local temp folder before running tests:

```powershell
mkdir -Force "C:\Users\$env:USERNAME\AppData\Local\Temp\flutter_test_temp"
$env:TEMP='C:\Users\$env:USERNAME\AppData\Local\Temp\flutter_test_temp'
$env:TMP='C:\Users\$env:USERNAME\AppData\Local\Temp\flutter_test_temp'
flutter test -r expanded
```

Optionally remove the temporary folder afterwards:

```powershell
Remove-Item -Recurse -Force "C:\Users\$env:USERNAME\AppData\Local\Temp\flutter_test_temp"
```

## Excel output and Dipendenti behaviour

- The generated Excel file is now saved to the system's **Downloads** folder (on Android the app will try to use the Downloads external directory; on desktop it uses the user Downloads folder).
- The Excel file contains **two columns**: `Nome Cognome` and `Targa` (one row per selected employee).
- The rows are exported in **alphabetical order** by `Nome Cognome`.

## Gestione Dipendenti changes

- Each `Dipendente` can have two optional fixed plates: **Targa Fissa Furgone** and **Targa Fissa Motorino**.
- When generating assignments, the app uses the `motorino` toggle for each selected employee to decide whether to assign a motorino or a furgone; if a fixed plate for that type is present it will be used (and it will be excluded from random selection if marked out of service).

## Syncing changes between devices (optional)

If you need automatic synchronization between multiple users/devices, a recommended approach is to use a remote backend such as **Firebase Cloud Firestore**. Implementation steps include:

1. Add and configure `firebase_core` and `cloud_firestore` packages.
2. Create a Firebase project and download platform configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS).
3. Initialize Firebase in `main()` with `Firebase.initializeApp()` and write code to mirror local data (dipendenti/mezzi/assegnazioni) to Firestore collections, and listen for remote changes to merge them locally.

A full `SyncManager` implementation is available in `lib/sync_manager.dart`. It integrates with Cloud Firestore and supports:

- Enabling/disabling sync from the Home page AppBar.
- Bidirectional sync: uploads local collections to Firestore and listens to remote updates.
- Minimal conflict resolution using `updatedAt` timestamps (last write wins).

To enable real sync:

1. Create a Firebase project and register your app(s).
2. Download and add `google-services.json` (Android) and/or `GoogleService-Info.plist` (iOS) into the platform-specific directories (see detailed instructions below).
3. Follow the FlutterFire docs to configure platforms: https://firebase.flutter.dev/docs/overview
4. Run the app and toggle the Sync button in the Home AppBar (it will perform an initial push and then listen for remote changes).

Firebase local config files (how to add them safely)

- Android: place the file you download from Firebase at `android/app/google-services.json`.
- iOS: place the downloaded `GoogleService-Info.plist` at `ios/Runner/GoogleService-Info.plist`.

Important security notes:
- Do **not** commit these files to a public repository if they contain credentials for production projects. We added `.gitignore` entries so by default they are ignored.
- Alternative approaches: store the files in a private repository, use environment-specific CI secrets, or use Firebase config via CI secrets/secure storage and inject at build time.

If you want, you can share the downloaded files with me (via a secure channel) and I will add them to the project in a feature branch and configure the app. DO NOT commit `google-services.json` or `GoogleService-Info.plist` to a public repository.

Recommended secure approach (CI injection via GitHub Secrets):

1. In the GitHub repository, go to **Settings → Secrets → Actions → New repository secret**.
2. Add a secret with the name `FIREBASE_ANDROID_JSON` and paste the full contents of `google-services.json` (including newlines). Save it.
3. Add a secret with the name `FIREBASE_IOS_PLIST` and paste the full contents of `GoogleService-Info.plist`.

The CI workflow will automatically write these secrets to `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` at runtime if they are present, so no credentials need to be stored in the repo.

If you prefer to add the files locally instead, place them in the following paths and do not push them to the repo:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Notes:
- The sync implementation is safe-by-default and will no-op if Firebase is not configured.
- Firestore collections used: `dipendenti`, `mezzi`, `meta/assegnazioni`.

## Git / Remote

I initialized a local Git repository and created a commit. To push to a remote GitHub repo:

```bash
# replace <remote-url> with your repository URL
git remote add origin <remote-url>
git branch -M main
git push -u origin main
```

If you want, I can add the remote and push for you if you provide the repository URL and confirm.

---

## Changes made in this update

- Excel export now writes two columns (`Nome Cognome`, `Targa`) and is saved to the **Downloads** folder.
- Export rows are sorted alphabetically by `Nome Cognome`.
- `Dipendente` now supports separate fixed plates for **furgone** and **motorino**. The dialog in `Gestione Dipendenti` allows setting both.
- The assignment logic uses the motorino toggle during export to decide whether to assign a motorino or a furgone; if a fixed plate for the chosen type exists it will be used.
- README updated with notes about tests and syncing options.

## Quick test steps

Run these commands in the project root:

```powershell
flutter pub get
flutter analyze
# Run tests (if project is on OneDrive follow the "Running tests on Windows with OneDrive" section above first)
flutter test -r expanded
```

To verify Excel export manually:
1. Open the app, add some `Dipendenti` and `Mezzi` (mark some `mezzi` as motorino or furgone).
2. Select employees on the Home page and toggle the motorino icon per person if you want them to receive a motorino.
3. Tap `Genera Excel`. The file will be saved to your Downloads folder and a SnackBar will show the path.

---

