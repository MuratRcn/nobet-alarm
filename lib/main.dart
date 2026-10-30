import 'dart:async';
import 'dart:convert';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final navKey = GlobalKey<NavigatorState>();
const gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _baslik = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  // Alarm çalınca tam ekran durdurma ekranını aç.
  Alarm.ringStream.stream.listen((s) {
    navKey.currentState?.push(MaterialPageRoute(builder: (_) => RingScreen(s)));
  });
  runApp(MaterialApp(
    navigatorKey: navKey,
    debugShowCheckedModeBanner: false,
    // Türkçe arayüz (tarih/saat seçici dahil)
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Koyu tema
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF2E8B7A),
      scaffoldBackgroundColor: const Color(0xFF121A19),
    ),
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: const Color(0xFF2E8B7A)),
    home: const Home(),
  ));
}

class RingScreen extends StatefulWidget {
  final AlarmSettings s;
  const RingScreen(this.s, {super.key});
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // Emniyet: kimse durdurmazsa 5 dakika sonra alarm kendiliğinden susar.
    _t = Timer(const Duration(minutes: 5), _durdur);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _durdur() async {
    _t?.cancel();
    await Alarm.stop(widget.s.id); // sesi ve titreşimi keser
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return PopScope(
      canPop: false, // geri tuşu alarmı açık bırakmasın: sadece Durdur ile kapanır
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(s.notificationSettings.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(s.notificationSettings.body, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 48),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(220, 72)),
                onPressed: _durdur,
                child: const Text('Durdur', style: TextStyle(fontSize: 22)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> types = [
    {'id': 1, 'name': 'Sabah', 'times': ['07:15', '07:20', '07:30']},
    {'id': 2, 'name': 'Akşam', 'times': ['19:15', '19:20', '19:30']},
    {'id': 3, 'name': 'Dinlenme', 'times': <String>[]},
  ];
  List<Map<String, dynamic>> cycle = [
    {'t': 1, 'd': 2}, {'t': 2, 'd': 2}, {'t': 3, 'd': 2},
  ];
  Map<String, int> overrides = {}; // tek günlük elle değişiklikler
  Map<String, List<String>> extras = {}; // güne özel ekstra alarmlar
  bool paused = false; // izin / duraklatma
  int tab = 0; // 0 Takvim, 1 Döngü, 2 İzin
  DateTime? sonKurulum; // alarmların en son ne zaman kurulduğu
  DateTime? pausedUntil; // dönüş tarihi (boşsa süresiz)
  DateTime start = DateTime.now();
  String status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _k(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('data');
    if (raw != null) {
      final m = jsonDecode(raw);
      types = (m['types'] as List)
          .map((e) => {'id': e['id'], 'name': e['name'], 'times': List<String>.from(e['times'])})
          .toList();
      cycle = (m['cycle'] as List).map((e) => {'t': e['t'], 'd': e['d']}).toList();
      start = DateTime.parse(m['start']);
      overrides = Map<String, int>.from(m['ov'] ?? {});
      paused = m['paused'] ?? false;
      pausedUntil = m['until'] != null ? DateTime.parse(m['until']) : null;
      extras = (m['extras'] as Map? ?? {}).map((k, v) => MapEntry(k as String, List<String>.from(v)));
      setState(() {});
      // Uygulama her açıldığında önümüzdeki 30 günü yeniden kurar.
      await _schedule(silent: true);
    }
    // İlk açılışta pil optimizasyonu muafiyeti iste (alarmın güvenilir çalması için).
    if (!(p.getBool('pil_soruldu') ?? false)) {
      await p.setBool('pil_soruldu', true);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Alarmın kaçmaması için'),
          content: const Text(
              'Telefon pil tasarrufu için uygulamayı kapatabilir. Bir sonraki ekranda '
              '"Pil optimizasyonu yok / Kısıtlama yok" seçeneğini onayla. '
              'Xiaomi, Huawei, Oppo gibi telefonlarda ayrıca Ayarlar > Uygulamalar > '
              'Nöbet Alarmı > "Otomatik başlat" izni de açılmalı.'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam'))],
        ),
      );
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('data',
        jsonEncode({'types': types, 'cycle': cycle, 'start': start.toIso8601String(), 'ov': overrides, 'paused': paused, 'until': pausedUntil?.toIso8601String(), 'extras': extras}));
  }

  int get total => cycle.fold<int>(0, (a, c) => a + (c['d'] as int));

  Map<String, dynamic>? typeFor(DateTime day) {
    final o = overrides[_k(day)];
    if (o != null) {
      final f = types.where((t) => t['id'] == o);
      if (f.isNotEmpty) return f.first;
    }
    if (total == 0) return null;
    final a = DateTime.utc(day.year, day.month, day.day);
    final b = DateTime.utc(start.year, start.month, start.day);
    var pos = a.difference(b).inDays % total;
    for (final c in cycle) {
      if (pos < (c['d'] as int)) {
        return types.firstWhere((t) => t['id'] == c['t'], orElse: () => {});
      }
      pos -= c['d'] as int;
    }
    return null;
  }

  bool isPaused(DateTime day) {
    if (!paused) return false;
    if (pausedUntil == null) return true;
    final u = DateTime(pausedUntil!.year, pausedUntil!.month, pausedUntil!.day);
    return day.isBefore(u);
  }

  List<String> extraFor(DateTime day) => List<String>.from(extras[_k(day)] ?? <String>[])..sort();

  Future<void> _schedule({bool silent = false}) async {
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    await _save();
    final now = DateTime.now();
    final wanted = <int>{};
    var kuruldu = 0;
    for (var i = 0; i < 30; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final t = typeFor(day);
      // Duraklatılmış günlerde döngü alarmları kurulmaz; ekstra alarmlar yine kurulur.
      final cyc = (isPaused(day) || t == null || t.isEmpty)
          ? <String>[]
          : (List<String>.from(t['times'])..sort());
      final ex = extraFor(day);
      final items = <(int, String, String)>[];
      for (var j = 0; j < cyc.length && j < 50; j++) {
        items.add((j, cyc[j], '${t!['name']} vardiyası'));
      }
      for (var j = 0; j < ex.length && j < 50; j++) {
        items.add((50 + j, ex[j], 'Ekstra alarm'));
      }
      for (final it in items) {
        final p = it.$2.split(':');
        final at = DateTime(day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1]));
        // Sabit numara: gün + sıra. Aynı alarm tekrar kurulursa üzerine yazılır, çoğalmaz.
        final aid = (day.year * 10000 + day.month * 100 + day.day) * 100 + it.$1;
        wanted.add(aid); // geçmiş/çalmakta olan alarm da "istenen" sayılır, dokunulmaz
        if (at.isBefore(now)) continue;
        await Alarm.set(
          alarmSettings: AlarmSettings(
            id: aid,
            dateTime: at,
            assetAudioPath: 'assets/alarm.wav',
            loopAudio: true,
            vibrate: true,
            volume: 1.0,
            androidFullScreenIntent: true,
            notificationSettings: NotificationSettings(
              title: it.$3,
              body: 'Alarm ${it.$2}',
              stopButton: 'Durdur',
            ),
          ),
        );
        kuruldu++;
      }
    }
    // Toptan silme yok: sadece artık gerekmeyen alarmları temizle.
    for (final a in await Alarm.getAlarms()) {
      if (!wanted.contains(a.id)) await Alarm.stop(a.id);
    }
    sonKurulum = now;
    if (!silent) {
      status = '$kuruldu alarm kuruldu (önümüzdeki 30 gün).';
      if (mounted) setState(() {});
    }
  }

  Future<void> _togglePause(bool v) async {
    if (v) {
      final c = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(title: const Text('Döngüyü duraklat'), children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'tarih'),
              child: const Text('Dönüş tarihi seç (o gün otomatik devam eder)')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'suresiz'),
              child: const Text('Süresiz duraklat (devamını ben açarım)')),
          SimpleDialogOption(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
        ]),
      );
      if (c == null) return;
      if (c == 'tarih') {
        final d = await showDatePicker(
          context: context,
          helpText: 'Dönüş tarihi',
          initialDate: DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );
        if (d == null) return;
        pausedUntil = d;
      } else {
        pausedUntil = null;
      }
      setState(() => paused = true);
    } else {
      final c = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(title: const Text('Döngü nasıl devam etsin?'), children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'takvim'),
              child: const Text('Takvime göre (döngü arada işlemiş gibi)')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'bugun'),
              child: const Text('Bugünü döngünün 1. günü yap')),
          SimpleDialogOption(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
        ]),
      );
      if (c == null) return;
      setState(() {
        paused = false;
        pausedUntil = null;
        if (c == 'bugun') start = DateTime.now();
      });
    }
    await _schedule();
  }

  Future<void> _pickTime(int ti, int? ei) async {
    final r = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 7, minute: 0));
    if (r == null) return;
    final s = '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
    setState(() {
      final list = types[ti]['times'] as List<String>;
      if (ei == null) {
        list.add(s);
      } else {
        list[ei] = s;
      }
      list.sort();
    });
  }

  Future<void> _pickDay(DateTime day) async {
    final ex = extraFor(day);
    final secim = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(title: Text('${day.day}.${day.month} günü', style: const TextStyle(fontWeight: FontWeight.bold))),
          const ListTile(dense: true, title: Text('Vardiyayı değiştir (sadece bu gün)')),
          for (final t in types) ListTile(title: Text(t['name']), onTap: () => Navigator.pop(c, 't:${t['id']}')),
          if (overrides.containsKey(_k(day)))
            ListTile(title: const Text('Döngüye göre (değişikliği kaldır)'), onTap: () => Navigator.pop(c, 'clear')),
          const Divider(),
          const ListTile(dense: true, title: Text('Ekstra alarmlar (sadece bu gün)')),
          for (final e in ex)
            ListTile(
              title: Text(e),
              trailing: const Icon(Icons.delete_outline),
              onTap: () => Navigator.pop(c, 'xdel:$e'),
            ),
          ListTile(
            leading: const Icon(Icons.add_alarm),
            title: const Text('Ekstra alarm ekle'),
            onTap: () => Navigator.pop(c, 'xadd'),
          ),
        ]),
      ),
    );
    if (secim == null) return;
    if (secim == 'xadd') {
      final r = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 7, minute: 0));
      if (r != null) {
        final s = '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
        setState(() {
          final l = extras.putIfAbsent(_k(day), () => <String>[]);
          if (!l.contains(s)) l.add(s);
        });
        await _schedule();
        if (mounted) await _pickDay(day);
      }
    } else if (secim.startsWith('xdel:')) {
      final s = secim.substring(5);
      setState(() {
        extras[_k(day)]?.remove(s);
        if (extras[_k(day)]?.isEmpty ?? false) extras.remove(_k(day));
      });
      await _schedule();
      if (mounted) await _pickDay(day);
    } else {
      setState(() {
        if (secim == 'clear') {
          overrides.remove(_k(day));
        } else {
          overrides[_k(day)] = int.parse(secim.substring(2));
        }
      });
      await _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final aktif = paused && isPaused(DateTime(now.year, now.month, now.day));
    const basliklar = ['Önümüzdeki 30 gün', 'Döngü', 'İzin'];
    final sayfalar = [_takvim(now, aktif), _dongu(), _izin(aktif)];
    return Scaffold(
      appBar: AppBar(title: Text(basliklar[tab])),
      body: sayfalar[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Takvim'),
          NavigationDestination(icon: Icon(Icons.autorenew), label: 'Döngü'),
          NavigationDestination(icon: Icon(Icons.beach_access), label: 'İzin'),
        ],
      ),
    );
  }

  Widget _takvim(DateTime now, bool aktif) {
    final son = (sonKurulum ?? now).add(const Duration(days: 29));
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (aktif)
        Card(
          child: ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: Text(pausedUntil == null
                ? 'Döngü süresiz duraklatıldı'
                : 'Döngü duraklatıldı, dönüş: ${pausedUntil!.day}.${pausedUntil!.month}.${pausedUntil!.year}'),
            subtitle: const Text('Ekstra alarmlar çalmaya devam eder.'),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Alarmlar ${son.day}.${son.month}.${son.year} tarihine kadar kurulu. Ondan önce uygulamayı bir kez aç.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      for (var i = 0; i < 30; i++)
        Builder(builder: (_) {
          final day = DateTime(now.year, now.month, now.day + i);
          final t = typeFor(day);
          final dur = isPaused(day);
          final degisti = overrides.containsKey(_k(day));
          final ex = extraFor(day);
          final cyc = (dur || t == null || t.isEmpty) ? <String>[] : (List<String>.from(t['times'])..sort());
          final hepsi = [...cyc, ...ex.map((e) => '$e (ekstra)')];
          final saatler = hepsi.isEmpty ? 'Alarm yok' : hepsi.join('  ');
          final etiket = i == 0 ? 'Bugün' : (i == 1 ? 'Yarın' : '');
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 72,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (etiket.isNotEmpty) Text(etiket, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${day.day}.${day.month} ${gunler[day.weekday - 1]}'),
              ]),
            ),
            title: Text(dur ? 'Duraklatıldı' : (t == null || t.isEmpty ? '-' : t['name']),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(saatler),
            trailing: (degisti || ex.isNotEmpty) ? const Icon(Icons.edit, size: 18) : null,
            onTap: () => _pickDay(day),
          );
        }),
    ]);
  }

  Widget _dongu() {
    final names = {for (final t in types) t['id']: t['name']};
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Vardiya tipleri', style: _baslik),
      for (var i = 0; i < types.length; i++)
        Card(
          key: ValueKey(types[i]['id']),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    initialValue: types[i]['name'],
                    onChanged: (v) => types[i]['name'] = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    final id = types[i]['id'];
                    types.removeAt(i);
                    cycle.removeWhere((c) => c['t'] == id);
                  }),
                ),
              ]),
              Wrap(spacing: 8, children: [
                for (var j = 0; j < (types[i]['times'] as List).length; j++)
                  InputChip(
                    label: Text(types[i]['times'][j]),
                    onPressed: () => _pickTime(i, j),
                    onDeleted: () => setState(() => (types[i]['times'] as List).removeAt(j)),
                  ),
                ActionChip(label: const Text('+ Alarm saati'), onPressed: () => _pickTime(i, null)),
              ]),
            ]),
          ),
        ),
      TextButton(
        onPressed: () => setState(() => types.add({
              'id': DateTime.now().millisecondsSinceEpoch,
              'name': 'Yeni vardiya',
              'times': <String>[],
            })),
        child: const Text('Vardiya tipi ekle'),
      ),
      const SizedBox(height: 12),
      const Text('Döngü', style: _baslik),
      for (var i = 0; i < cycle.length; i++)
        Row(children: [
          Expanded(
            child: DropdownButton<dynamic>(
              isExpanded: true,
              value: names.containsKey(cycle[i]['t']) ? cycle[i]['t'] : null,
              items: [for (final t in types) DropdownMenuItem(value: t['id'], child: Text(t['name']))],
              onChanged: (v) => setState(() => cycle[i]['t'] = v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => setState(() {
              if (cycle[i]['d'] > 1) cycle[i]['d'] = cycle[i]['d'] - 1;
            }),
          ),
          Text('${cycle[i]['d']} gün'),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => setState(() => cycle[i]['d'] = cycle[i]['d'] + 1),
          ),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => cycle.removeAt(i))),
        ]),
      TextButton(
        onPressed: () {
          if (types.isNotEmpty) setState(() => cycle.add({'t': types.first['id'], 'd': 1}));
        },
        child: Text('Parça ekle (döngü toplam $total gün)'),
      ),
      const SizedBox(height: 12),
      const Text('Başlangıç', style: _baslik),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Döngünün 1. günü: ${start.day}.${start.month}.${start.year}'),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: start,
            firstDate: DateTime(2024),
            lastDate: DateTime(2100),
          );
          if (d != null) setState(() => start = d);
        },
      ),
      const SizedBox(height: 8),
      FilledButton(onPressed: _schedule, child: const Text('Alarmları kur')),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Vardiya, saat ya da döngüyü değiştirdiysen "Alarmları kur"a bas.'),
      ),
      if (status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(status)),
    ]);
  }

  Widget _izin(bool aktif) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: SwitchListTile(
          title: const Text('İzin / Duraklat'),
          subtitle: Text(aktif
              ? (pausedUntil == null
                  ? 'Duraklatıldı: döngü alarmları kurulmuyor'
                  : 'Duraklatıldı, dönüş: ${pausedUntil!.day}.${pausedUntil!.month}.${pausedUntil!.year}')
              : 'Kapalı'),
          value: aktif,
          onChanged: _togglePause,
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Açınca döngü alarmları durur. Dönüş tarihi seçersen o gün döngü kendiliğinden devam eder. '
            'Ekstra alarmlar çalmaya devam eder.'),
      ),
    ]);
  }
}
