# Claude Code'a verilecek istem

Bu klasör bir Flutter (Android) projesinin kaynak dosyalarıdır: lib/main.dart, pubspec.yaml, assets/alarm.wav. Henüz derlenmedi ve test edilmedi.

Yapılacaklar:
1. Flutter ve Android SDK kurulu değilse kurulumu adım adım yaptır. Sonra bu klasörde `flutter create . --platforms=android` çalıştır (lib/, pubspec.yaml ve assets/ korunsun).
2. `flutter pub get` çalıştır. `alarm` paketi sürümü (^4.1.1) ile main.dart arasında uyumsuzluk çıkarsa (Alarm.ringStream, NotificationSettings, Alarm.getAlarms) hataları düzelt. Gerekirse paketin güncel sürümüne uyarla.
3. android/app/build.gradle içinde minSdkVersion 23 yap. AndroidManifest.xml'e şu izinleri ekle (alarm paketi eklemediyse): POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, VIBRATE, WAKE_LOCK, USE_FULL_SCREEN_INTENT, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
4. Arayüz zaten 3 sekmeli (Takvim, Döngü, İzin) ve nihai halde. Mantığı ve arayüzü değiştirme, sadece derleme hatalarını düzelt. tasarim_referans.html yalnızca görsel referans.
5. APK üretimi: `.github/workflows/build-apk.yml` hazır (android klasörünü, minSdk 23'ü ve izinleri kendisi ayarlar). Bulut ortamında Flutter/Android SDK indirilemiyorsa bu iş akışını kullan, gerekirse düzelt. Özeti: workflow_dispatch ve main'e push ile tetiklensin; actions/checkout, actions/setup-java (temurin 17), subosito/flutter-action (stable), `flutter pub get`, `flutter build apk --release` çalıştırsın ve build/app/outputs/flutter-apk/app-release.apk dosyasını actions/upload-artifact ile "nobet-alarm-apk" adıyla yüklesin. Bunu depoya push et ve APK'yı GitHub Actions > ilgili çalıştırma > Artifacts bölümünden nasıl indireceğimi anlat. (Kurulu araçlarla derleyebiliyorsan doğrudan `flutter build apk --release` de olur.)
6. Telefona kurulum ve test adımlarını bana kısa listeyle anlat.
