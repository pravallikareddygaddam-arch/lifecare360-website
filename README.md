# LifeCare 360 — Flutter starter app

LifeCare 360 is a mobile wellness journal starter project. It includes:
- Guided, one-question-at-a-time health profile
- Personal preferences and reported conditions
- Daily check-in for water, sleep, movement, mood, energy, digestion, symptoms and notes
- Menstrual cycle and symptom logging
- Simple food and movement suggestions based on preferences
- Local storage and a delete-all-data option
- Responsive Material 3 UI

## Important scope and safety notes

This is a **starter wellness app**, not a medical device and not a diagnostic or treatment tool. The plan is a basic preference-based example, not a clinically calculated diet. Do not rely on it for medication changes, diagnosis, emergencies, contraception, or condition-specific treatment.

This version stores data locally using `shared_preferences`. It does not have user accounts, encrypted cloud sync, clinician access, Health Connect integration, an AI API, or production security controls. Add and test those carefully before real-world release. Avoid entering sensitive data on shared devices.

## Requirements

1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
2. Install Android Studio and its Android SDK: https://developer.android.com/studio
3. Install Visual Studio Code: https://code.visualstudio.com/
4. In VS Code, install the **Flutter** extension (it also installs Dart support).
5. On Windows, enable Android developer tools and accept Android SDK licences.

## Open and run in VS Code (Windows)

1. Extract `lifecare_360.zip` to a folder such as `C:\projects\lifecare_360`.
2. Open that folder in VS Code: **File → Open Folder**.
3. Open **Terminal → New Terminal**.
4. Check Flutter setup:
   ```powershell
   flutter doctor
   ```
5. Generate the platform scaffolding in this project folder (this creates the `android/` and other platform folders):
   ```powershell
   flutter create --platforms=android .
   ```
   If Flutter asks to overwrite `pubspec.yaml` or `lib/main.dart`, do not overwrite your existing app files. If it cannot preserve them, run `flutter create --platforms=android C:\projects\lifecare_shell` in a separate folder and copy the generated `android/` folder into this project.
6. Install dependencies:
   ```powershell
   flutter pub get
   ```
7. Connect an Android phone with USB debugging enabled, or start an emulator from Android Studio.
8. Check devices and run:
   ```powershell
   flutter devices
   flutter run
   ```

If `flutter` is not recognized, close and reopen VS Code after adding the Flutter `bin` folder to PATH.

## Build an Android release bundle for Google Play

Google Play normally expects an Android App Bundle (`.aab`) for a new app.

1. Choose a unique application ID before publishing. The generated scaffold has a default ID; change it in the Android Gradle configuration to something you own, e.g. `com.yourbrand.lifecare360`. Do not use that example if it is not yours.
2. Set the app display name, icon, version and minimum SDK. Test the app on physical devices.
3. Create an upload key and keep it private:
   ```powershell
   keytool -genkey -v -keystore "$env:USERPROFILE\lifecare-upload-key.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Follow Flutter's official signing guide to configure `android/key.properties` and Gradle signing. Never commit the keystore or passwords to GitHub.
4. Build the bundle:
   ```powershell
   flutter build appbundle --release
   ```
5. The bundle should be at:
   `build\app\outputs\bundle\release\app-release.aab`
6. Create a Google Play Console developer account, create your app listing, complete the required privacy/data-safety and content declarations, upload the `.aab` to an internal testing track, test it, and then follow the console's production release requirements.

Official references:
- Flutter Android deployment: https://docs.flutter.dev/deployment/android
- Google Play Console: https://play.google.com/console/about/
- Google Play app testing requirements: https://support.google.com/googleplay/android-developer/answer/14151465
- Health apps policy: https://support.google.com/googleplay/android-developer/answer/14738291

## Before publishing

- Add a real privacy policy and an in-app privacy notice.
- Complete Google Play's health-app declaration and data safety form truthfully.
- Request only necessary permissions. This starter currently does not request sensor permissions.
- Test backup, data deletion, app lifecycle, accessibility, and small/large screens.
- Review the health-related app policies and avoid unsupported diagnostic claims.
- Add automated tests and clinical review for any future medical or AI features.
- Consider a secure backend and proper encryption if you later add accounts or cloud sync.

## Project layout

```text
lifecare_360/
  lib/
    main.dart
  assets/
  pubspec.yaml
  README.md
```


## Advanced wellness features in this starter

The **My plan** tab now opens:
- **Nutrition & macros:** approximate energy/protein guide from profile details, an Indian-food starter database, daily calories/protein/carbohydrate/fat totals, and a daily food log.
- **Food availability:** mark ingredients currently available and get simple meal ideas based on selected ingredients. This is a manual pantry checker, not live grocery inventory.
- **Exercise library:** filter by home/gym, level and equipment; read basic movement cues; open YouTube search results for demonstrations.
- **Weekly routine:** a flexible 7-day starter plan with locally saved completion checkboxes.

### Important boundaries
This remains a local prototype. Nutrition values are estimates, and the calorie/protein calculations are simplified general guides, not medical recommendations. Video buttons open YouTube search results rather than playing curated videos inside the app. Live grocery availability/prices, barcode scanning, wearables, AI camera form feedback, personalized AI chat, secure cloud accounts, clinician review and Play Store release preparation need additional development and testing. Do not rely on the app to diagnose or treat a condition.

### Run in VS Code
1. Install Flutter SDK and Android Studio (Android SDK).
2. Extract this ZIP and open the `lifecare_360` folder in VS Code.
3. In the terminal, run `flutter create --platforms=android .` if the Android platform folder is missing.
4. Run `flutter pub get`.
5. Run `flutter run` with an Android emulator or USB-debugging-enabled phone.
6. For Play Store output, run `flutter build appbundle --release` after setting a unique application ID, app icon, signing key, privacy policy, and store listing.

The source has not been compiled or tested on a physical device in this environment. Test all screens and data handling before using or publishing it.
