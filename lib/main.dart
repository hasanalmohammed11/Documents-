// main.dart - v2 (fixed pw.Row textDirection)
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kNavy = Color(0xFF1B2A8A);
const kBg = Color(0xFFF8F5EE);

// ───────────────────────── النماذج (Models) ─────────────────────────

class Fld {
  final String label;
  final bool multi;
  final bool phone;
  final bool biz;
  const Fld(this.label, {this.multi = false, this.phone = false, this.biz = false});
}

class Tpl {
  final String id, name, title, desc, tag, itemLabel;
  final IconData icon;
  final int c;
  final List<Fld> fields;
  final bool table, notes, free, sign;
  const Tpl({
    required this.id,
    required this.name,
    required this.title,
    required this.desc,
    required this.tag,
    required this.icon,
    required this.c,
    required this.fields,
    this.table = false,
    this.notes = true,
    this.free = false,
    this.sign = false,
    this.itemLabel = 'البيان',
  });
  Color get color => Color(c);
}

const kTpls = <Tpl>[
  Tpl(
    id: 'invoice',
    name: 'فاتورة',
    title: 'فاتورة مبيعات',
    desc: 'فواتير المبيعات والمشتريات',
    tag: 'فاتورة',
    icon: Icons.description_outlined,
    c: 0xFF1565C0,
    table: true,
    fields: [
      Fld('اسم المحل', biz: true),
      Fld('اسم الزبون'),
      Fld('رقم الهاتف', phone: true),
      Fld('رقم الفاتورة'),
    ],
  ),
  Tpl(
    id: 'pharmacy',
    name: 'فاتورة صيدلية',
    title: 'فاتورة صيدلية',
    desc: 'للصيدليات والمستلزمات الطبية',
    tag: 'صيدلية',
    icon: Icons.medication_outlined,
    c: 0xFFC62828,
    table: true,
    itemLabel: 'الدواء / المادة',
    fields: [
      Fld('اسم الصيدلية', biz: true),
      Fld('اسم المريض'),
      Fld('اسم الطبيب'),
      Fld('رقم الفاتورة'),
    ],
  ),
  Tpl(
    id: 'restaurant',
    name: 'طلب مطعم',
    title: 'طلب مطعم',
    desc: 'المطاعم والمقاهي',
    tag: 'طلب',
    icon: Icons.restaurant,
    c: 0xFFEF6C00,
    table: true,
    itemLabel: 'الصنف',
    fields: [
      Fld('اسم المطعم', biz: true),
      Fld('اسم الزبون'),
      Fld('رقم الطاولة'),
      Fld('عنوان التوصيل', multi: true),
    ],
  ),
  Tpl(
    id: 'quote',
    name: 'عرض سعر',
    title: 'عرض سعر',
    desc: 'العروض والطلبات',
    tag: 'عرض سعر',
    icon: Icons.sell_outlined,
    c: 0xFF2E7D32,
    table: true,
    fields: [
      Fld('الجهة المقدمة للعرض', biz: true),
      Fld('السادة / العميل'),
      Fld('مدة صلاحية العرض'),
      Fld('رقم العرض'),
    ],
  ),
  Tpl(
    id: 'maintenance',
    name: 'طلب صيانة',
    title: 'طلب صيانة',
    desc: 'الورش والخدمات الفنية',
    tag: 'صيانة',
    icon: Icons.build_outlined,
    c: 0xFF6A1B9A,
    sign: true,
    fields: [
      Fld('اسم الورشة', biz: true),
      Fld('اسم العميل'),
      Fld('رقم الهاتف', phone: true),
      Fld('نوع الجهاز'),
      Fld('وصف العطل', multi: true),
      Fld('التكلفة المتوقعة'),
    ],
  ),
  Tpl(
    id: 'receipt',
    name: 'إيصال استلام',
    title: 'إيصال استلام',
    desc: 'لسداد المستحقات',
    tag: 'إيصال',
    icon: Icons.account_balance_wallet_outlined,
    c: 0xFF00796B,
    sign: true,
    fields: [
      Fld('استلمت من السيد'),
      Fld('مبلغ وقدره'),
      Fld('وذلك عن', multi: true),
      Fld('طريقة الدفع'),
      Fld('اسم المستلم'),
    ],
  ),
  Tpl(
    id: 'free',
    name: 'قالب حر',
    title: 'مستند',
    desc: 'اكتب ما تشاء بدون قالب محدد',
    tag: 'حر',
    icon: Icons.edit_note,
    c: 0xFF455A64,
    free: true,
    notes: false,
    fields: [
      Fld('العنوان'),
      Fld('النص', multi: true),
    ],
  ),
];

Tpl tplById(String id) => kTpls.firstWhere((t) => t.id == id, orElse: () => kTpls.last);

class Item {
  String name;
  double qty, price;
  Item(this.name, this.qty, this.price);
  double get total => qty * price;
  Map<String, dynamic> toJson() => {'n': name, 'q': qty, 'p': price};
}

class DocData {
  String id, tpl, notes;
  Map<String, String> values;
  List<Item> items;
  bool table;
  int ts;
  DocData({
    required this.id,
    required this.tpl,
    required this.values,
    required this.items,
    required this.notes,
    required this.table,
    required this.ts,
  });
  double get total => items.fold<double>(0, (s, i) => s + i.total);

  Map<String, dynamic> toJson() => {
        'id': id,
        'tpl': tpl,
        'v': values,
        'i': items.map((e) => e.toJson()).toList(),
        'n': notes,
        't': table,
        'ts': ts,
      };

  factory DocData.fromJson(Map<String, dynamic> j) => DocData(
        id: j['id'],
        tpl: j['tpl'],
        values: Map<String, String>.from(j['v'] ?? {}),
        items: ((j['i'] ?? []) as List)
            .map((e) => Item(e['n'], (e['q'] as num).toDouble(), (e['p'] as num).toDouble()))
            .toList(),
        notes: j['n'] ?? '',
        table: j['t'] ?? false,
        ts: j['ts'],
      );

  String get displayTitle {
    final t = tplById(tpl);
    if (t.free) {
      final x = (values['العنوان'] ?? '').trim();
      return x.isEmpty ? t.title : x;
    }
    return t.title;
  }
}

// ───────────────────────── التخزين ─────────────────────────

class Store {
  static late SharedPreferences p;
  static Future<void> init() async => p = await SharedPreferences.getInstance();
  static String get biz => p.getString('biz') ?? '';
  static String get cur => p.getString('cur') ?? 'ل.س';

  static List<DocData> recent() {
    final l = p.getStringList('recent') ?? [];
    final out = <DocData>[];
    for (final s in l) {
      try {
        out.add(DocData.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> _put(List<DocData> l) =>
      p.setStringList('recent', l.map((e) => jsonEncode(e.toJson())).toList());

  static Future<void> save(DocData d) async {
    final l = recent()..removeWhere((e) => e.id == d.id);
    l.insert(0, d);
    await _put(l.take(30).toList());
  }

  static Future<void> remove(String id) async {
    await _put(recent()..removeWhere((e) => e.id == id));
  }
}

// ───────────────────────── أدوات مساعدة ─────────────────────────

double numOf(String s) {
  const a = '٠١٢٣٤٥٦٧٨٩';
  var r = s;
  for (var i = 0; i < 10; i++) {
    r = r.replaceAll(a[i], '$i');
  }
  r = r.replaceAll('٫', '.').replaceAll('٬', '').replaceAll(',', '').trim();
  return double.tryParse(r) ?? 0;
}

String money(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  parts[0] = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return parts.join('.');
}

String when(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final n = DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final t = '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'ص' : 'م'}';
  if (days <= 0) return 'اليوم • $t';
  if (days == 1) return 'أمس • $t';
  return 'منذ $days أيام • $t';
}

// ───────────────────────── PDF ─────────────────────────

pw.Font? _f, _fb;

Future<Uint8List> buildPdf(Tpl t, DocData d) async {
  _f ??= await PdfGoogleFonts.cairoRegular();
  _fb ??= await PdfGoogleFonts.cairoBold();
  final accent = PdfColor.fromInt(t.c);
  final cur = Store.cur;
  const rtl = pw.TextDirection.rtl;
  final dt = DateTime.fromMillisecondsSinceEpoch(d.ts);
  final date =
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  final showTable = d.table && d.items.isNotEmpty;

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: _f!, bold: _fb!));
  final w = <pw.Widget>[];

  w.add(pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(d.displayTitle,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: accent)),
      pw.Text(date, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
    ],
  ));
  w.add(pw.SizedBox(height: 6));
  w.add(pw.Divider(color: accent, thickness: 1.5));
  w.add(pw.SizedBox(height: 8));

  if (t.free) {
    final body = (d.values['النص'] ?? '').trim();
    if (body.isNotEmpty) w.add(pw.Text(body, style: pw.TextStyle(fontSize: 13, lineSpacing: 4)));
  } else {
    for (final f in t.fields) {
      final v = (d.values[f.label] ?? '').trim();
      if (v.isEmpty) continue;
      w.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${f.label}: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 12))),
          ],
        ),
      ));
    }
  }

  if (showTable) {
    w.add(pw.SizedBox(height: 12));
    const flexes = [1, 5, 2, 3, 3];
    pw.Widget row(List<String> c, {bool head = false, bool zebra = false}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: pw.BoxDecoration(
            color: head ? accent : (zebra ? PdfColors.grey100 : null),
            border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          ),
          child: pw.Row(
            children: [
              for (var i = 0; i < c.length; i++)
                pw.Expanded(
                  flex: flexes[i],
                  child: pw.Text(
                    c[i],
                    textAlign: i == 1 ? pw.TextAlign.right : pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: head ? PdfColors.white : PdfColors.black,
                    ),
                  ),
                ),
            ],
          ),
        );

    w.add(row(['#', t.itemLabel, 'الكمية', 'السعر', 'الإجمالي'], head: true));
    for (var i = 0; i < d.items.length; i++) {
      final it = d.items[i];
      w.add(row(
        ['${i + 1}', it.name, money(it.qty), money(it.price), money(it.total)],
        zebra: i.isOdd,
      ));
    }
    w.add(pw.SizedBox(height: 10));
    w.add(pw.Container(
      alignment: pw.Alignment.centerLeft,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border.all(color: accent, width: 1),
        ),
        child: pw.Text('الإجمالي: ${money(d.total)} $cur',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ),
    ));
  }

  if (d.notes.isNotEmpty) {
    w.add(pw.SizedBox(height: 14));
    w.add(pw.Text('ملاحظات:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)));
    w.add(pw.SizedBox(height: 3));
    w.add(pw.Text(d.notes, style: const pw.TextStyle(fontSize: 12)));
  }

  if (t.sign) {
    w.add(pw.SizedBox(height: 50));
    pw.Widget sig(String s) => pw.Column(children: [
          pw.Container(width: 120, height: 1, color: PdfColors.grey700),
          pw.SizedBox(height: 4),
          pw.Text(s, style: const pw.TextStyle(fontSize: 11)),
        ]);
    w.add(pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [sig('التوقيع'), sig('الختم')],
    ));
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: rtl,
    margin: const pw.EdgeInsets.all(32),
    footer: (c) => pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text('${c.pageNumber} / ${c.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ),
    build: (c) => w,
  ));
  return doc.save();
}

// ───────────────────────── التطبيق ─────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'القوالب الجاهزة',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: kNavy,
          scaffoldBackgroundColor: kBg,
        ),
        builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const HomePage(),
      );
}

// ───────────────────────── الرئيسية ─────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final q = TextEditingController();

  Future<void> open(Tpl t, [DocData? d]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditorPage(t, d)));
    if (mounted) setState(() {});
  }

  void settings() {
    final b = TextEditingController(text: Store.biz);
    final c = TextEditingController(text: Store.cur);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإعدادات'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: b,
            decoration: const InputDecoration(labelText: 'اسم المحل / النشاط (يُعبّأ تلقائياً)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: c, decoration: const InputDecoration(labelText: 'العملة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              await Store.p.setString('biz', b.text.trim());
              await Store.p.setString('cur', c.text.trim().isEmpty ? 'ل.س' : c.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(IconData i, String s) => Row(children: [
        Icon(i, size: 22),
        const SizedBox(width: 8),
        Text(s, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]);

  Widget banner() {
    final t = kTpls.first;
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF111B5E), Color(0xFF2B3FA8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1AA3E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('الأكثر استخداماً',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 8),
            const Text('فاتورة مبيعات',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('للمحلات التجارية وجميع الأنشطة',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
            const Spacer(),
            SizedBox(
              height: 34,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1432B8)),
                onPressed: () => open(t),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('استخدام القالب'),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: 0.12,
          child: Container(
            width: 92,
            height: 118,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.storefront, color: kNavy, size: 22),
              const SizedBox(height: 6),
              for (var i = 0; i < 5; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  height: 6,
                  width: i.isEven ? 70 : 48,
                  color: i == 0 ? kNavy : Colors.black12,
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget catCard(Tpl t) => Material(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => open(t),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: t.color.withAlpha(32),
                child: Icon(t.icon, color: t.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(t.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, size: 18, color: Colors.black38),
            ]),
          ),
        ),
      );

  Widget recentRow(DocData d) {
    final t = tplById(d.tpl);
    return InkWell(
      onTap: () => open(t, d),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 48,
            decoration: BoxDecoration(
              color: t.color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(t.icon, color: t.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(when(d.ts), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: t.color, borderRadius: BorderRadius.circular(20)),
            child: Text(t.tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              await Store.remove(d.id);
              if (mounted) setState(() {});
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('حذف'))],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = q.text.trim();
    final list = kTpls
        .where((t) =>
            !t.free &&
            (query.isEmpty || t.name.contains(query) || t.desc.contains(query) || t.title.contains(query)))
        .toList();
    final free = kTpls.last;
    final showFree = query.isEmpty || free.name.contains(query) || free.desc.contains(query);
    final recent = Store.recent();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        tooltip: 'قالب حر',
        onPressed: () => open(free),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          children: [
            Row(children: [
              const Icon(Icons.description_outlined, size: 26),
              const SizedBox(width: 8),
              const Text('القوالب الجاهزة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: settings, icon: const Icon(Icons.settings_outlined)),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: q,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن قالب...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF4E6585),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (query.isEmpty) ...[banner(), const SizedBox(height: 18)],
            sectionTitle(Icons.grid_view_rounded, 'تصنيفات القوالب'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [for (final t in list) catCard(t)],
            ),
            if (showFree) ...[
              const SizedBox(height: 12),
              SizedBox(height: 70, child: catCard(free)),
            ],
            if (recent.isNotEmpty && query.isEmpty) ...[
              const SizedBox(height: 20),
              sectionTitle(Icons.history, 'آخر القوالب'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                    recentRow(recent[i]),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── المحرر ─────────────────────────

class _Row {
  final n = TextEditingController();
  final q = TextEditingController(text: '1');
  final p = TextEditingController();
  _Row([Item? i]) {
    if (i != null) {
      n.text = i.name;
      q.text = money(i.qty).replaceAll(',', '');
      p.text = money(i.price).replaceAll(',', '');
    }
  }
  double get total => numOf(q.text) * numOf(p.text);
  void dispose() {
    n.dispose();
    q.dispose();
    p.dispose();
  }
}

class EditorPage extends StatefulWidget {
  final Tpl t;
  final DocData? doc;
  const EditorPage(this.t, this.doc, {super.key});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final Map<String, TextEditingController> ctl;
  late final TextEditingController notes;
  final rows = <_Row>[];
  bool table = false;
  bool busy = false;
  late String id;

  Tpl get t => widget.t;
  bool get showTable => t.table || (t.free && table);

  @override
  void initState() {
    super.initState();
    final d = widget.doc;
    id = d?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    ctl = {
      for (final f in t.fields)
        f.label: TextEditingController(text: d?.values[f.label] ?? (f.biz ? Store.biz : '')),
    };
    notes = TextEditingController(text: d?.notes ?? '');
    table = d?.table ?? false;
    if (d != null) rows.addAll(d.items.map((e) => _Row(e)));
    if (t.table && rows.isEmpty) rows.add(_Row());
  }

  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    notes.dispose();
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  DocData collect() => DocData(
        id: id,
        tpl: t.id,
        values: {for (final f in t.fields) f.label: ctl[f.label]!.text.trim()},
        items: [
          for (final r in rows)
            if (r.n.text.trim().isNotEmpty || numOf(r.p.text) > 0)
              Item(r.n.text.trim(), numOf(r.q.text), numOf(r.p.text)),
        ],
        notes: notes.text.trim(),
        table: showTable,
        ts: DateTime.now().millisecondsSinceEpoch,
      );

  void snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _save() async {
    await Store.save(collect());
    if (mounted) snack('تم الحفظ');
  }

  Future<void> _preview() async {
    final d = collect();
    await Store.save(d);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewPage(t, d)));
  }

  Future<void> _share() async {
    final d = collect();
    await Store.save(d);
    setState(() => busy = true);
    try {
      final bytes = await buildPdf(t, d);
      await Printing.sharePdf(bytes: bytes, filename: '${t.id}_${d.ts}.pdf');
    } catch (e) {
      if (mounted) snack('تعذر إنشاء الملف. تأكد من الاتصال بالإنترنت (لتحميل الخط أول مرة).');
    }
    if (mounted) setState(() => busy = false);
  }

  InputDecoration deco(String l) => InputDecoration(
        labelText: l,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget itemCard(int i) {
    final r = rows[i];
    const numKb = TextInputType.numberWithOptions(decimal: true);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: r.n,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: '${t.itemLabel} ${i + 1}', isDense: true),
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              rows.removeAt(i).dispose();
            }),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: r.q,
              keyboardType: numKb,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'الكمية', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: r.p,
              keyboardType: numKb,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'السعر', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(money(r.total),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: t.color)),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, r) => s + r.total);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.title),
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final f in t.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: ctl[f.label],
                keyboardType: f.phone
                    ? TextInputType.phone
                    : (f.multi ? TextInputType.multiline : TextInputType.text),
                minLines: f.multi ? (t.free ? 8 : 3) : 1,
                maxLines: f.multi ? null : 1,
                decoration: deco(f.label),
              ),
            ),
          if (t.free)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إضافة جدول (أصناف / أسعار)'),
              value: table,
              onChanged: (v) => setState(() {
                table = v;
                if (v && rows.isEmpty) rows.add(_Row());
              }),
            ),
          if (showTable) ...[
            const SizedBox(height: 4),
            const Text('الأصناف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++) itemCard(i),
            OutlinedButton.icon(
              onPressed: () => setState(() => rows.add(_Row())),
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.color.withAlpha(28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Text('الإجمالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${money(total)} ${Store.cur}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.color)),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          if (t.notes)
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: null,
              decoration: deco('ملاحظات'),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('معاينة'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : _share,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.share),
                label: const Text('PDF'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── المعاينة ─────────────────────────

class PreviewPage extends StatelessWidget {
  final Tpl t;
  final DocData d;
  const PreviewPage(this.t, this.d, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('معاينة PDF')),
        body: PdfPreview(
          build: (_) => buildPdf(t, d),
          pdfFileName: '${t.id}_${d.ts}.pdf',
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          onError: (ctx, e) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'تعذر إنشاء الملف.\nتأكد من الاتصال بالإنترنت (لتحميل الخط أول مرة).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
