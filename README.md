# Nöbet Alarmı (Android)

## Kurulum (geliştirici ya da Claude Code için)
1. Flutter kur, `flutter create .` ile android klasörünü oluştur (lib/, pubspec.yaml, assets/ korunur).
2. `flutter pub get`
3. android/app/build.gradle: `minSdkVersion 23` (alarm paketi için).
4. AndroidManifest.xml içine izinler (alarm paketi çoğunu ekler, eksikse ekle):
   - POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED,
     VIBRATE, WAKE_LOCK, USE_FULL_SCREEN_INTENT
5. `flutter run` ile telefonda dene, `flutter build apk` ile APK üret.

## Test listesi
- 2 dakika sonrasına bir vardiya saati koy, ekran kilitliyken çalıyor mu?
- Telefonu yeniden başlat, alarm hâlâ çalıyor mu?
- Pil optimizasyonundan uygulamayı muaf tut (Xiaomi/Huawei/Oppo şart).

## Eklenenler (2. sürüm)
- Alarm çalınca "Durdur" tam ekranı (Alarm.ringStream).
- İlk açılışta pil optimizasyonu muafiyeti isteği ve marka uyarısı.
- Günlük tek seferlik değişiklik (takas): listede güne dokun.
- Uygulama her açılışta 30 günü yeniden kurar.
- Not: alarm paketi sürümü ^4.1.1. Yeni sürümde ringStream/NotificationSettings adları değişmiş olabilir.
- Yenileme güvenli: alarm numaraları tarihe bağlı (gün*10+sıra), toptan silme yok; çalan alarma dokunulmaz.

## 3. sürüm
- Çalan alarm: "Durdur" sesi/titreşimi keser, geri tuşu alarmı kapatmaz, 5 dk sonra emniyet olarak kendiliğinden susar.
- İzin / Duraklat anahtarı: dönüş tarihi seçilebilir (o gün otomatik devam) ya da süresiz; devam ederken "takvime göre" ya da "bugün 1. gün" seçilir. Duraklatmada ekstra alarmlar çalmaya devam eder.
- Güne özel ekstra alarm: 30 günlük listede güne dokun > "Ekstra alarm ekle".
- Alarm numarası: gün*100 + sıra (0-49 döngü, 50-99 ekstra).
