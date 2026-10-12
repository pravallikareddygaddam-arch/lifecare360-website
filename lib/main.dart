import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifeCareApp());
}

const ink = Color(0xFF25243A);
const violet = Color(0xFF7667D9);
const lavender = Color(0xFFF0EDFF);
const mint = Color(0xFFE4F6EE);
const peach = Color(0xFFFFEEE5);
const rose = Color(0xFFFFE8EF);
const canvas = Color(0xFFF8F7FC);

class LifeCareApp extends StatelessWidget {
  const LifeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeCare 360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: violet, primary: violet),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF6F5FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class HealthData {
  Map<String, dynamic> profile = {};
  List<Map<String, dynamic>> dailyLogs = [];
  List<Map<String, dynamic>> periodLogs = [];

  Map<String, dynamic>? get todayLog {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final log in dailyLogs) {
      if (log['date'] == today) return log;
    }
    return null;
  }

  Map<String, dynamic>? get lastPeriod {
    if (periodLogs.isEmpty) return null;
    final sorted = [...periodLogs]
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return sorted.first;
  }

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'dailyLogs': dailyLogs,
        'periodLogs': periodLogs,
      };

  static HealthData fromJson(Map<String, dynamic> json) {
    final data = HealthData();
    data.profile = Map<String, dynamic>.from(json['profile'] ?? {});
    data.dailyLogs = (json['dailyLogs'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    data.periodLogs = (json['periodLogs'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return data;
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  HealthData data = HealthData();
  bool loading = true;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lifecare_data_v1');
    if (raw != null) {
      try {
        data = HealthData.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lifecare_data_v1', jsonEncode(data.toJson()));
    if (mounted) setState(() {});
  }

  Future<void> _onboarding() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => HealthAssessment(
              initial: Map<String, dynamic>.from(data.profile))),
    );
    if (result != null) {
      data.profile = result;
      await _save();
    }
  }

  Future<void> _dailyEntry() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => DailyCheckIn(existing: data.todayLog)),
    );
    if (result != null) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      data.dailyLogs.removeWhere((e) => e['date'] == today);
      data.dailyLogs.add(result);
      await _save();
    }
  }

  Future<void> _periodEntry() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => PeriodEntry()),
    );
    if (result != null) {
      data.periodLogs.add(result);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final hasProfile = data.profile.isNotEmpty;
    final pages = [
      HomePage(
          data: data,
          onAssess: _onboarding,
          onDaily: _dailyEntry,
          onPeriod: _periodEntry,
          onTab: (v) => setState(() => tab = v)),
      TrackerPage(data: data, onDaily: _dailyEntry),
      PeriodPage(data: data, onAdd: _periodEntry),
      PlanPage(data: data),
      ProfilePage(
          data: data,
          onEdit: _onboarding,
          onReset: () async {
            final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text('Clear all health data?'),
                      content: const Text(
                          'This permanently removes the profile and logs saved on this device.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear data')),
                      ],
                    ));
            if (ok == true) {
              data = HealthData();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('lifecare_data_v1');
              if (mounted) setState(() => tab = 0);
            }
          }),
    ];
    if (!hasProfile && tab == 0) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const BrandMark(),
                const SizedBox(height: 28),
                const Text('Your health, your whole story.',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        height: 1.1)),
                const SizedBox(height: 14),
                const Text(
                    'A calm space to understand your habits, track your cycle, and build a wellness routine that fits real life.',
                    style: TextStyle(
                        fontSize: 16, height: 1.5, color: Color(0xFF77758A))),
                const SizedBox(height: 24),
                const FeatureLine(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Food and movement plans'),
                const FeatureLine(
                    icon: Icons.calendar_month_rounded,
                    title: 'Period and symptom tracking'),
                const FeatureLine(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Daily wellness check-ins'),
                const Spacer(),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _onboarding,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: const Text('Start my health assessment'),
                    )),
                const SizedBox(height: 12),
                const Text(
                    'Your entries are stored locally on this device in this starter version.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF88869A))),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        backgroundColor: Colors.white,
        indicatorColor: lavender,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.checklist_rounded), label: 'Track'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_rounded), label: 'Period'),
          NavigationDestination(
              icon: Icon(Icons.spa_rounded), label: 'My plan'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: violet, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 27)),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LifeCare 360',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 20, color: ink)),
          Text('PERSONAL WELLNESS COMPANION',
              style: TextStyle(
                  fontSize: 9, letterSpacing: 1.1, color: Color(0xFF89869F))),
        ])
      ]);
}

class FeatureLine extends StatelessWidget {
  final IconData icon;
  final String title;
  const FeatureLine({super.key, required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: lavender, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: violet, size: 20)),
          const SizedBox(width: 12),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
        ]),
      );
}

class HomePage extends StatelessWidget {
  final HealthData data;
  final VoidCallback onAssess, onDaily, onPeriod;
  final ValueChanged<int> onTab;
  const HomePage(
      {super.key,
      required this.data,
      required this.onAssess,
      required this.onDaily,
      required this.onPeriod,
      required this.onTab});

  @override
  Widget build(BuildContext context) {
    final name = (data.profile['name'] ?? '').toString().trim();
    final today = data.todayLog;
    final water = (today?['water'] ?? 0) as int;
    final sleep = (today?['sleep'] ?? 0).toDouble();
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Hello${name.isNotEmpty ? ', $name' : ''} 👋',
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF77758A))),
                  const SizedBox(height: 4),
                  const Text('Let’s care for you.',
                      style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: ink)),
                ])),
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: lavender, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.favorite_rounded, color: violet)),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7667D9), Color(0xFF9B8DEB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('YOUR WELLNESS, ONE DAY AT A TIME',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text('Small steps count.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Check in with your body, not against it.',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 18),
              FilledButton.tonal(
                  onPressed: onDaily,
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: violet),
                  child: Text(today == null
                      ? 'Complete today’s check-in'
                      : 'Update today’s check-in')),
            ]),
          ),
          const SizedBox(height: 22),
          const SectionHeading('Today at a glance',
              subtitle: 'Your own logged wellness details'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: MetricCard(
                    icon: Icons.water_drop_rounded,
                    color: const Color(0xFFDBF0FF),
                    title: 'Water',
                    value: '$water glasses',
                    note: 'Logged today')),
            const SizedBox(width: 10),
            Expanded(
                child: MetricCard(
                    icon: Icons.bedtime_rounded,
                    color: const Color(0xFFECE7FF),
                    title: 'Sleep',
                    value:
                        '${sleep.toStringAsFixed(sleep % 1 == 0 ? 0 : 1)} hrs',
                    note: 'Logged today')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: MetricCard(
                    icon: Icons.mood_rounded,
                    color: const Color(0xFFFFE9EF),
                    title: 'Mood',
                    value: (today?['mood'] ?? '—').toString(),
                    note: 'Daily check-in')),
            const SizedBox(width: 10),
            Expanded(
                child: MetricCard(
                    icon: Icons.directions_walk_rounded,
                    color: const Color(0xFFE2F6EA),
                    title: 'Movement',
                    value: '${today?['activity'] ?? 0} min',
                    note: 'Logged today')),
          ]),
          const SizedBox(height: 22),
          const SectionHeading('Your care toolkit',
              subtitle: 'Quick access to your health routines'),
          const SizedBox(height: 12),
          QuickTile(
              icon: Icons.restaurant_menu_rounded,
              title: 'Nutrition & movement',
              subtitle: 'Your suggested daily routine',
              color: mint,
              onTap: () => onTab(3)),
          const SizedBox(height: 10),
          QuickTile(
              icon: Icons.calendar_month_rounded,
              title: 'Menstrual health',
              subtitle: 'Record a period start or symptoms',
              color: rose,
              onTap: onPeriod),
          const SizedBox(height: 10),
          QuickTile(
              icon: Icons.person_search_rounded,
              title: 'Health profile',
              subtitle: 'Update your health assessment',
              color: peach,
              onTap: onAssess),
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E5),
                  borderRadius: BorderRadius.circular(18)),
              child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF9C6C18)),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'LifeCare 360 supports wellness tracking; it does not diagnose conditions or replace a doctor. Seek urgent care for severe or rapidly worsening symptoms.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFF775A2C)))),
                  ])),
        ]);
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeading(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF858298)))
        ],
      ]);
}

class MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value, note;
  const MetricCard(
      {super.key,
      required this.icon,
      required this.color,
      required this.title,
      required this.value,
      required this.note});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 19, color: ink)),
        const SizedBox(height: 13),
        Text(title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF77758A))),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 3),
        Text(note,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9996AA))),
      ]));
}

class QuickTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const QuickTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: ink)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: ink)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF858298))),
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF9996AA)),
              ]))));
}

class HealthAssessment extends StatefulWidget {
  final Map<String, dynamic> initial;
  const HealthAssessment({super.key, required this.initial});
  @override
  State<HealthAssessment> createState() => _HealthAssessmentState();
}

class _HealthAssessmentState extends State<HealthAssessment> {
  int step = 0;
  late Map<String, dynamic> answers;
  final TextEditingController textController = TextEditingController();
  final List<AssessmentQuestion> questions = [
    AssessmentQuestion('What should we call you?', 'name', 'text',
        hint: 'Your first name or nickname', optional: true),
    AssessmentQuestion('What is your age?', 'age', 'number',
        hint: 'Age in years'),
    AssessmentQuestion('What is your main wellness goal?', 'goal', 'choice',
        options: [
          'Overall health',
          'Weight management',
          'More energy',
          'Better fitness',
          'Menstrual health',
          'Manage an existing condition'
        ]),
    AssessmentQuestion(
        'What is your height in centimetres?', 'height', 'number',
        hint: 'e.g. 155', optional: true),
    AssessmentQuestion(
        'What is your current weight in kilograms?', 'weight', 'number',
        hint: 'e.g. 60', optional: true),
    AssessmentQuestion(
        'Do you have any known health conditions?', 'conditions', 'multi',
        options: [
          'None known',
          'PCOS / hormonal concerns',
          'Thyroid condition',
          'Diabetes / blood sugar concerns',
          'Anaemia / low iron',
          'Digestive concerns',
          'Other'
        ]),
    AssessmentQuestion(
        'Do you have any allergies or food restrictions?', 'allergies', 'text',
        hint: 'e.g. peanuts, lactose, or none', optional: true),
    AssessmentQuestion('Which eating style suits you?', 'diet', 'choice',
        options: [
          'Vegetarian',
          'Eggetarian',
          'Non-vegetarian',
          'Vegan',
          'No preference'
        ]),
    AssessmentQuestion('Where do you usually eat?', 'foodAccess', 'choice',
        options: [
          'Hostel / mess',
          'Home-cooked meals',
          'Work / college cafeteria',
          'Mostly order food',
          'A mix'
        ]),
    AssessmentQuestion(
        'What movement feels realistic for you?', 'exercise', 'choice',
        options: [
          'Walking / gentle movement',
          'Home workouts',
          'Gym',
          'Yoga / stretching',
          'A mix',
          'I have limitations'
        ]),
    AssessmentQuestion(
        'How many hours do you usually sleep?', 'sleep', 'choice',
        options: ['Less than 5', '5–6', '7–8', 'More than 8', 'It varies']),
    AssessmentQuestion(
        'Do you want menstrual cycle tracking?', 'periodTracking', 'choice',
        options: ['Yes', 'No', 'Not applicable']),
    AssessmentQuestion(
        'Any symptoms you would like to keep track of?', 'symptoms', 'text',
        hint: 'e.g. fatigue, headaches, cramps; or none', optional: true),
    AssessmentQuestion(
        'Are you taking any medicines or supplements?', 'medicines', 'text',
        hint: 'Names, or none; do not stop prescribed medicines',
        optional: true),
  ];

  @override
  void initState() {
    super.initState();
    answers = Map<String, dynamic>.from(widget.initial);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  AssessmentQuestion get q => questions[step];

  @override
  Widget build(BuildContext context) {
    final saved = answers[q.key];
    if (textController.text.isEmpty && saved != null && q.type == 'text')
      textController.text = saved.toString();
    return Scaffold(
      appBar: AppBar(
          title: const Text('Health assessment'),
          leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context))),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('QUESTION ${step + 1} OF ${questions.length}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: violet)),
                          Text(
                              '${((step + 1) / questions.length * 100).round()}%',
                              style: const TextStyle(
                                  color: Color(0xFF858298), fontSize: 12)),
                        ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                            value: (step + 1) / questions.length,
                            minHeight: 6,
                            backgroundColor: lavender)),
                    const SizedBox(height: 28),
                    Text(q.title,
                        style: const TextStyle(
                            fontSize: 26,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                            color: ink)),
                    const SizedBox(height: 8),
                    Text(
                        q.optional
                            ? 'You can skip this if you prefer.'
                            : 'Choose the answer that fits you best.',
                        style: const TextStyle(color: Color(0xFF858298))),
                    const SizedBox(height: 22),
                    Expanded(
                        child: SingleChildScrollView(
                            child: _answerControl(saved))),
                    const SizedBox(height: 12),
                    Row(children: [
                      if (step > 0)
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => setState(() {
                                      step--;
                                      textController.clear();
                                    }),
                                style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15)),
                                child: const Text('Back'))),
                      if (step > 0) const SizedBox(width: 10),
                      Expanded(
                          flex: 2,
                          child: FilledButton(
                              onPressed: _next,
                              style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15)),
                              child: Text(step == questions.length - 1
                                  ? 'Save my profile'
                                  : 'Continue'))),
                    ]),
                  ]))),
    );
  }

  Widget _answerControl(dynamic saved) {
    if (q.type == 'text' || q.type == 'number') {
      return TextField(
        controller: textController,
        keyboardType: q.type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
            hintText: q.hint,
            suffixIcon:
                q.type == 'text' ? const Icon(Icons.edit_outlined) : null),
        onChanged: (v) => answers[q.key] = v,
      );
    }
    if (q.type == 'multi') {
      final selected = List<String>.from(saved is List ? saved : []);
      return StatefulBuilder(
          builder: (context, localSet) => Column(
                  children: q.options!.map((opt) {
                final isSelected = selected.contains(opt);
                return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: isSelected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(opt),
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      onChanged: (v) {
                        if (opt == 'None known' && v == true) {
                          selected
                            ..clear()
                            ..add(opt);
                        } else {
                          selected.remove('None known');
                          if (v == true) {
                            selected.add(opt);
                          } else {
                            selected.remove(opt);
                          }
                        }
                        answers[q.key] = List<String>.from(selected);
                        localSet(() {});
                      },
                    ));
              }).toList()));
    }
    final current = saved?.toString();
    return Column(
        children: q.options!.map((opt) {
      final selected = current == opt;
      return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: InkWell(
            onTap: () => setState(() => answers[q.key] = opt),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: selected ? lavender : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: selected ? violet : const Color(0xFFECEAF3),
                      width: selected ? 1.5 : 1)),
              child: Row(children: [
                Expanded(
                    child: Text(opt,
                        style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: ink))),
                Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? violet : const Color(0xFFB7B3C8)),
              ]),
            ),
          ));
    }).toList());
  }

  void _next() {
    final value = answers[q.key];
    if (!q.optional &&
        (value == null ||
            value.toString().trim().isEmpty ||
            (value is List && value.isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please answer this question or choose an option.')));
      return;
    }
    if (q.type == 'number' &&
        value != null &&
        value.toString().trim().isNotEmpty &&
        double.tryParse(value.toString()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number.')));
      return;
    }
    if (step < questions.length - 1) {
      setState(() {
        step++;
        textController.clear();
      });
    } else {
      answers['updatedAt'] = DateTime.now().toIso8601String();
      Navigator.pop(context, answers);
    }
  }
}

class AssessmentQuestion {
  final String title, key, type;
  final String? hint;
  final List<String>? options;
  final bool optional;
  AssessmentQuestion(this.title, this.key, this.type,
      {this.hint, this.options, this.optional = false});
}

class DailyCheckIn extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const DailyCheckIn({super.key, this.existing});
  @override
  State<DailyCheckIn> createState() => _DailyCheckInState();
}

class _DailyCheckInState extends State<DailyCheckIn> {
  int water = 0, activity = 0;
  double sleep = 7;
  String mood = 'Okay', energy = 'Moderate', digestion = 'Normal';
  final symptomsController = TextEditingController();
  final notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      water = e['water'] ?? 0;
      activity = e['activity'] ?? 0;
      sleep = (e['sleep'] ?? 7).toDouble();
      mood = e['mood'] ?? 'Okay';
      energy = e['energy'] ?? 'Moderate';
      digestion = e['digestion'] ?? 'Normal';
      symptomsController.text = e['symptoms'] ?? '';
      notesController.text = e['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    symptomsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Daily check-in')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('How are you feeling today?',
              style: TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 6),
          const Text(
              'There is no perfect score. This is simply a record of your day.',
              style: TextStyle(color: Color(0xFF858298))),
          const SizedBox(height: 22),
          _formCard(
              'Water',
              Icons.water_drop_rounded,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$water glasses logged',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                    value: water.toDouble(),
                    min: 0,
                    max: 16,
                    divisions: 16,
                    label: '$water',
                    onChanged: (v) => setState(() => water = v.round())),
                const Text(
                    'A glass is whatever size you normally use; this is not a prescribed target.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF858298))),
              ])),
          const SizedBox(height: 12),
          _formCard(
              'Sleep',
              Icons.bedtime_rounded,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${sleep.toStringAsFixed(1)} hours',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                    value: sleep,
                    min: 0,
                    max: 12,
                    divisions: 24,
                    onChanged: (v) => setState(() => sleep = v)),
              ])),
          const SizedBox(height: 12),
          _formCard(
              'Movement',
              Icons.directions_walk_rounded,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$activity minutes',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                    value: activity.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 36,
                    onChanged: (v) => setState(() => activity = v.round())),
              ])),
          const SizedBox(height: 12),
          _formCard(
              'Mood',
              Icons.mood_rounded,
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Great', 'Good', 'Okay', 'Low', 'Anxious']
                      .map((v) => ChoiceChip(
                          label: Text(v),
                          selected: mood == v,
                          onSelected: (_) => setState(() => mood = v)))
                      .toList())),
          const SizedBox(height: 12),
          _formCard(
              'Energy level',
              Icons.bolt_rounded,
              Wrap(
                  spacing: 8,
                  children: ['Low', 'Moderate', 'High']
                      .map((v) => ChoiceChip(
                          label: Text(v),
                          selected: energy == v,
                          onSelected: (_) => setState(() => energy = v)))
                      .toList())),
          const SizedBox(height: 12),
          _formCard(
              'Digestion',
              Icons.eco_rounded,
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Normal',
                    'Bloating',
                    'Constipation',
                    'Diarrhoea',
                    'Discomfort'
                  ]
                      .map((v) => ChoiceChip(
                          label: Text(v),
                          selected: digestion == v,
                          onSelected: (_) => setState(() => digestion = v)))
                      .toList())),
          const SizedBox(height: 12),
          _formCard(
              'Symptoms and notes',
              Icons.edit_note_rounded,
              Column(children: [
                TextField(
                    controller: symptomsController,
                    decoration: const InputDecoration(
                        hintText: 'Any symptoms today? (optional)'),
                    maxLines: 2),
                const SizedBox(height: 10),
                TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                        hintText: 'Anything else to remember? (optional)'),
                    maxLines: 2),
              ])),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () => Navigator.pop(context, {
                    'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    'water': water,
                    'sleep': sleep,
                    'activity': activity,
                    'mood': mood,
                    'energy': energy,
                    'digestion': digestion,
                    'symptoms': symptomsController.text.trim(),
                    'notes': notesController.text.trim(),
                  }),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Save today’s check-in')),
          const SizedBox(height: 10),
        ]),
      );

  Widget _formCard(String title, IconData icon, Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: violet),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: ink))
        ]),
        const SizedBox(height: 12),
        child,
      ]));
}

class TrackerPage extends StatelessWidget {
  final HealthData data;
  final VoidCallback onDaily;
  const TrackerPage({super.key, required this.data, required this.onDaily});
  @override
  Widget build(BuildContext context) {
    final logs = [...data.dailyLogs]
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Daily tracker',
          style:
              TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 5),
      const Text('Build a picture of your wellbeing over time.',
          style: TextStyle(color: Color(0xFF858298))),
      const SizedBox(height: 18),
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: onDaily,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log today'))),
      const SizedBox(height: 18),
      const SectionHeading('Recent check-ins'),
      const SizedBox(height: 12),
      if (logs.isEmpty)
        const EmptyState(
            icon: Icons.insights_rounded,
            title: 'Your story starts here',
            message:
                'Log sleep, water, movement, mood and symptoms to build your personal history.'),
      ...logs.take(30).map((log) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_friendlyDate(log['date']),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _tag(Icons.water_drop_rounded, '${log['water']} glasses'),
              _tag(Icons.bedtime_rounded, '${log['sleep']} h sleep'),
              _tag(Icons.directions_walk_rounded,
                  '${log['activity']} min movement'),
              _tag(Icons.mood_rounded, '${log['mood']} mood'),
            ]),
            if ((log['symptoms'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text('Symptoms: ${log['symptoms']}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF77758A)))
            ],
          ]))),
    ]);
  }
}

Widget _tag(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration:
        BoxDecoration(color: lavender, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: violet),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11, color: ink))
    ]));

String _friendlyDate(dynamic raw) {
  try {
    return DateFormat('EEE, d MMM yyyy').format(DateTime.parse(raw.toString()));
  } catch (_) {
    return raw?.toString() ?? '';
  }
}

class PeriodPage extends StatelessWidget {
  final HealthData data;
  final VoidCallback onAdd;
  const PeriodPage({super.key, required this.data, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final logs = [...data.periodLogs]
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    final last = data.lastPeriod;
    final lastDate =
        last == null ? null : DateTime.tryParse(last['date'].toString());
    final cycleLength =
        int.tryParse((data.profile['cycleLength'] ?? '28').toString()) ?? 28;
    final nextDate = lastDate?.add(Duration(days: cycleLength));
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Menstrual health',
          style:
              TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 5),
      const Text('A private place to record your cycle and symptoms.',
          style: TextStyle(color: Color(0xFF858298))),
      const SizedBox(height: 18),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFE8EF), Color(0xFFFFF3F6)]),
              borderRadius: BorderRadius.circular(22)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('LAST PERIOD START',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9A4D6A))),
            const SizedBox(height: 8),
            Text(
                lastDate == null
                    ? 'Not recorded yet'
                    : DateFormat('d MMM yyyy').format(lastDate),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 8),
            Text(
                nextDate == null
                    ? 'Record a period start to begin your cycle history.'
                    : 'Estimated next start: ${DateFormat('d MMM yyyy').format(nextDate)}',
                style: const TextStyle(color: Color(0xFF77596A), fontSize: 12)),
            const SizedBox(height: 5),
            const Text(
                'Estimates may be inaccurate, especially with irregular cycles; they are not contraception or a diagnosis.',
                style: TextStyle(color: Color(0xFF77596A), fontSize: 11)),
          ])),
      const SizedBox(height: 16),
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log period or symptoms'))),
      const SizedBox(height: 20),
      const SectionHeading('Cycle history'),
      const SizedBox(height: 12),
      if (logs.isEmpty)
        const EmptyState(
            icon: Icons.calendar_month_rounded,
            title: 'No cycle entries yet',
            message:
                'Add the first day of your period and optional flow or symptom details.'),
      ...logs.map((log) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_friendlyDate(log['date']),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 7),
            Wrap(spacing: 8, children: [
              _tag(Icons.water_drop_outlined, 'Flow: ${log['flow']}'),
              _tag(Icons.favorite_border_rounded, 'Pain: ${log['pain']}')
            ]),
            if ((log['symptoms'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${log['symptoms']}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF77758A)))
            ],
          ]))),
    ]);
  }
}

class PeriodEntry extends StatefulWidget {
  const PeriodEntry({super.key});
  @override
  State<PeriodEntry> createState() => _PeriodEntryState();
}

class _PeriodEntryState extends State<PeriodEntry> {
  DateTime date = DateTime.now();
  String flow = 'Medium', pain = 'None';
  bool periodStart = true;
  final notes = TextEditingController();
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Period & symptom log')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Record what you notice',
              style: TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 8),
          const Text(
              'Your notes can help you spot patterns and share clear information with a clinician.',
              style: TextStyle(color: Color(0xFF858298))),
          const SizedBox(height: 22),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now());
                          if (d != null) setState(() => date = d);
                        },
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(DateFormat('d MMM yyyy').format(date))),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('First day of a period'),
                        value: periodStart,
                        onChanged: (v) => setState(() => periodStart = v),
                        subtitle: const Text(
                            'Turn off to record spotting or symptoms only.',
                            style: TextStyle(fontSize: 11))),
                  ])),
          const SizedBox(height: 12),
          _selectionCard('Flow', ['Spotting', 'Light', 'Medium', 'Heavy'], flow,
              (v) => setState(() => flow = v)),
          const SizedBox(height: 12),
          _selectionCard(
              'Pain / cramps',
              ['None', 'Mild', 'Moderate', 'Severe'],
              pain,
              (v) => setState(() => pain = v)),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Symptoms, clots, mood or other notes',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: notes,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            hintText:
                                'Optional notes, e.g. headache, spotting, clots, mood…')),
                  ])),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: () => Navigator.pop(context, {
                    'date': DateFormat('yyyy-MM-dd').format(date),
                    'periodStart': periodStart,
                    'flow': flow,
                    'pain': pain,
                    'symptoms': notes.text.trim(),
                  }),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Save entry')),
          const SizedBox(height: 10),
          const Text(
              'Seek urgent medical advice for very heavy bleeding, fainting, severe pain, or possible pregnancy with bleeding. This tracker cannot assess the cause of symptoms.',
              style: TextStyle(
                  fontSize: 11, height: 1.4, color: Color(0xFF858298))),
        ]),
      );

  Widget _selectionCard(String title, List<String> values, String selected,
          ValueChanged<String> onChange) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: values
                    .map((v) => ChoiceChip(
                        label: Text(v),
                        selected: selected == v,
                        onSelected: (_) => onChange(v)))
                    .toList()),
          ]));
}

class PlanPage extends StatelessWidget {
  final HealthData data;
  const PlanPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    final diet = (p['diet'] ?? 'No preference').toString();
    final access = (p['foodAccess'] ?? 'A mix').toString();
    final goal = (p['goal'] ?? 'Overall health').toString();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Your wellness centre',
          style:
              TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 5),
      const Text(
          'Nutrition, food availability, workouts and practical daily plans.',
          style: TextStyle(color: Color(0xFF858298))),
      const SizedBox(height: 18),
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: lavender, borderRadius: BorderRadius.circular(22)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome_rounded, color: violet, size: 27),
            const SizedBox(height: 10),
            Text('Your focus: $goal',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 5),
            Text('Eating style: $diet · Food access: $access',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6F6A91))),
            const SizedBox(height: 8),
            const Text(
                'Recommendations are estimates for general wellness, not medical prescriptions. If you have a health condition, are pregnant, are under 18, or have a history of disordered eating, get individual advice from a qualified clinician or dietitian.',
                style: TextStyle(
                    fontSize: 11, height: 1.4, color: Color(0xFF6F6A91))),
          ])),
      const SizedBox(height: 18),
      _featureCard(
          context,
          'Nutrition & macros',
          'Estimate daily energy and protein targets, log food, and review calories, protein, carbs and fats.',
          Icons.monitor_heart_outlined,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => NutritionCentre(profile: p)))),
      const SizedBox(height: 10),
      _featureCard(
          context,
          'Food availability & pantry',
          'Mark what you have at home, hostel/mess or nearby; get meal ideas based on available ingredients.',
          Icons.kitchen_outlined,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FoodAvailabilityPage(profile: p)))),
      const SizedBox(height: 10),
      _featureCard(
          context,
          'Exercise library & video tutorials',
          'Filter home or gym movements by equipment and level, see instructions, and open video demonstrations.',
          Icons.fitness_center_rounded,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ExerciseCentre(profile: p)))),
      const SizedBox(height: 10),
      _featureCard(
          context,
          'Weekly routine builder',
          'Create a starter weekly movement schedule and check off sessions as you complete them.',
          Icons.calendar_month_rounded,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WeeklyRoutinePage(profile: p)))),
      const SizedBox(height: 18),
      const Text('Included in this version',
          style:
              TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 8),
      const Text(
          'Local nutrition logging, estimated targets, a starter food database, ingredient availability, equipment filters, video-search links and a simple weekly plan. Live grocery stock/prices, barcode scanning, wearable syncing, camera-based form analysis and genuinely AI-generated clinical advice require external services and further development.',
          style:
              TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF77758A))),
    ]);
  }

  Widget _featureCard(BuildContext context, String title, String subtitle,
          IconData icon, VoidCallback onTap) =>
      Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            leading: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                    color: lavender,
                    borderRadius: BorderRadius.all(Radius.circular(14))),
                child: Icon(icon, color: violet)),
            title: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, color: ink)),
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, height: 1.35, color: Color(0xFF77758A)))),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ));
}

class FoodItem {
  final String name, group;
  final double kcal, protein, carbs, fat;
  const FoodItem(
      this.name, this.group, this.kcal, this.protein, this.carbs, this.fat);
}

const List<FoodItem> foodDatabase = [
  FoodItem('Boiled egg (1)', 'Protein', 78, 6.3, 0.6, 5.3),
  FoodItem('Cooked dal (1 cup)', 'Protein', 180, 12, 30, 2),
  FoodItem('Paneer (100 g)', 'Protein', 265, 18, 4, 20),
  FoodItem('Tofu (100 g)', 'Protein', 145, 16, 3, 9),
  FoodItem('Cooked chickpeas (1 cup)', 'Protein', 269, 14.5, 45, 4.2),
  FoodItem('Roasted chana (30 g)', 'Protein', 120, 6, 18, 2),
  FoodItem('Curd (100 g)', 'Protein', 61, 3.5, 4.7, 3.3),
  FoodItem('Cooked rice (1 cup)', 'Grains', 205, 4.3, 45, 0.4),
  FoodItem('Chapati (1 medium)', 'Grains', 120, 3.5, 20, 3),
  FoodItem('Oats (40 g dry)', 'Grains', 152, 5.3, 27, 2.7),
  FoodItem('Idli (2 medium)', 'Grains', 116, 4, 24, 0.5),
  FoodItem('Dosa (1 medium)', 'Grains', 168, 4, 28, 4),
  FoodItem('Banana (1 medium)', 'Fruit', 105, 1.3, 27, 0.4),
  FoodItem('Apple (1 medium)', 'Fruit', 95, 0.5, 25, 0.3),
  FoodItem('Mixed vegetables (1 cup)', 'Vegetables', 80, 3, 15, 1),
  FoodItem('Peanuts (20 g)', 'Nuts', 113, 5.2, 3.2, 9.8),
  FoodItem('Milk (200 ml)', 'Dairy', 122, 6.4, 9.6, 6.4),
  FoodItem('Chicken breast cooked (100 g)', 'Protein', 165, 31, 0, 3.6),
  FoodItem('Fish cooked (100 g)', 'Protein', 140, 26, 0, 4),
];

class NutritionCentre extends StatefulWidget {
  final Map<String, dynamic> profile;
  const NutritionCentre({super.key, required this.profile});
  @override
  State<NutritionCentre> createState() => _NutritionCentreState();
}

class _NutritionCentreState extends State<NutritionCentre> {
  final List<Map<String, dynamic>> eaten = [];
  String meal = 'Breakfast';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lifecare_food_log_v1');
    if (raw != null) {
      try {
        final all = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        eaten.addAll(all.where((e) => e['date'] == today));
      } catch (_) {}
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final raw = prefs.getString('lifecare_food_log_v1');
    List<Map<String, dynamic>> all = [];
    if (raw != null) {
      try {
        all = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }
    all.removeWhere((e) => e['date'] == today);
    all.addAll(eaten);
    await prefs.setString('lifecare_food_log_v1', jsonEncode(all));
    if (mounted) setState(() {});
  }

  double total(String key) {
    return eaten.fold<double>(
      0.0,
      (sum, e) => sum + ((e[key] ?? 0) as num).toDouble(),
    );
  }

  double _num(String key) =>
      double.tryParse((widget.profile[key] ?? '').toString()) ?? 0;
  double get weight => _num('weight');
  double get height => _num('height');
  double get age => _num('age');
  double get bmr => (weight > 0 && height > 0 && age > 0)
      ? (10 * weight + 6.25 * height - 5 * age - 161)
      : 0;
  double get targetCalories {
    if (bmr <= 0) return 0;
    final factor = (widget.profile['exercise'] == 'Gym' ||
            widget.profile['exercise'] == 'A mix')
        ? 1.45
        : 1.3;
    final maintenance = bmr * factor;
    final goal = (widget.profile['goal'] ?? '').toString();
    if (goal == 'Weight management') return maintenance;
    return maintenance;
  }

  double get targetProtein => weight > 0 ? weight * 1.2 : 0;

  Future<void> _addFood(FoodItem food) async {
    setState(() => eaten.add({
          'name': food.name,
          'meal': meal,
          'kcal': food.kcal,
          'protein': food.protein,
          'carbs': food.carbs,
          'fat': food.fat,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now())
        }));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition & macros')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Today at a glance',
            style: TextStyle(
                fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 5),
        const Text(
            'Food values are approximate; portions and recipes change the totals.',
            style: TextStyle(fontSize: 12, color: Color(0xFF858298))),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metric('Calories eaten', total('kcal').round().toString(), 'kcal'),
          _metric('Protein', total('protein').toStringAsFixed(1), 'g'),
          _metric('Carbs', total('carbs').round().toString(), 'g'),
          _metric('Fat', total('fat').toStringAsFixed(1), 'g'),
        ]),
        const SizedBox(height: 14),
        Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: lavender, borderRadius: BorderRadius.circular(18)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estimated daily guide',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text(targetCalories > 0
                  ? 'Energy: about ${targetCalories.round()} kcal/day'
                  : 'Add age, height and weight in your profile to estimate energy needs.'),
              Text(targetProtein > 0
                  ? 'Protein: about ${targetProtein.round()} g/day as a general fitness estimate.'
                  : 'Add your weight in your profile to estimate a general protein target.'),
              const SizedBox(height: 7),
              const Text(
                  'This uses a simplified estimate and does not account for all medical, pregnancy, activity or body-composition factors. Do not treat it as a prescription or use it for restrictive dieting.',
                  style: TextStyle(
                      fontSize: 11, height: 1.4, color: Color(0xFF6F6A91))),
            ])),
        const SizedBox(height: 18),
        const Text('Log food',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
            value: meal,
            decoration: const InputDecoration(labelText: 'Meal'),
            items: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => meal = v);
            }),
        const SizedBox(height: 10),
        ...foodDatabase.map((food) => Container(
            margin: const EdgeInsets.only(bottom: 7),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              dense: true,
              title: Text(food.name,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, color: ink)),
              subtitle: Text(
                  '${food.kcal.round()} kcal · P ${food.protein}g · C ${food.carbs}g · F ${food.fat}g',
                  style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                  tooltip: 'Add to today',
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: violet),
                  onPressed: () => _addFood(food)),
            ))),
        const SizedBox(height: 12),
        const Text('Logged today',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
        if (eaten.isEmpty)
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No foods logged yet. Tap + next to a food above.')),
        ...eaten.asMap().entries.map((entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value['name'].toString()),
              subtitle: Text(
                  '${entry.value['meal']} · ${(entry.value['kcal'] as num).round()} kcal'),
              trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async {
                    setState(() => eaten.removeAt(entry.key));
                    await _save();
                  }),
            )),
      ]),
    );
  }

  Widget _metric(String title, String value, String unit) => Container(
      width: 155,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF858298))),
        const SizedBox(height: 5),
        Text('$value $unit',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
      ]));
}

class FoodAvailabilityPage extends StatefulWidget {
  final Map<String, dynamic> profile;
  const FoodAvailabilityPage({super.key, required this.profile});
  @override
  State<FoodAvailabilityPage> createState() => _FoodAvailabilityPageState();
}

class _FoodAvailabilityPageState extends State<FoodAvailabilityPage> {
  final Set<String> available = {};
  final TextEditingController custom = TextEditingController();
  final List<String> staples = [
    'Rice',
    'Roti / chapati',
    'Oats',
    'Idli / dosa',
    'Eggs',
    'Dal',
    'Chickpeas / beans',
    'Paneer',
    'Tofu',
    'Curd',
    'Chicken',
    'Fish',
    'Milk',
    'Soy chunks',
    'Roasted chana',
    'Peanuts / nuts',
    'Banana',
    'Other fruits',
    'Leafy greens',
    'Mixed vegetables',
    'Potatoes',
    'Bread'
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() =>
        available.addAll(prefs.getStringList('lifecare_pantry_v1') ?? []));
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('lifecare_pantry_v1', available.toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Food availability')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('What food do you have today?',
              style: TextStyle(
                  fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 6),
          const Text(
              'Tick ingredients available in your kitchen, hostel mess or nearby shop. This does not check live store inventory.',
              style: TextStyle(fontSize: 12, color: Color(0xFF858298))),
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: staples
                      .map((s) => FilterChip(
                          label: Text(s),
                          selected: available.contains(s),
                          onSelected: (v) async {
                            setState(() {
                              v ? available.add(s) : available.remove(s);
                            });
                            await _save();
                          }))
                      .toList())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: custom,
                    decoration: const InputDecoration(
                        hintText: 'Add another ingredient'))),
            const SizedBox(width: 8),
            IconButton.filled(
                onPressed: () async {
                  final v = custom.text.trim();
                  if (v.isNotEmpty) {
                    setState(() {
                      available.add(v);
                      custom.clear();
                    });
                    await _save();
                  }
                },
                icon: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 16),
          const Text('Ideas from your available foods',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 8),
          ..._ideas().map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.restaurant_menu, color: violet),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s,
                        style: const TextStyle(fontSize: 13, height: 1.4)))
              ]))),
        ]),
      );
  List<String> _ideas() {
    final a = available.map((e) => e.toLowerCase()).toSet();
    final ideas = <String>[];
    if ((a.contains('rice') || a.contains('roti / chapati')) &&
        (a.contains('dal') || a.contains('chickpeas / beans')))
      ideas.add(
          'Rice or roti with dal/beans; add any vegetables you have for a balanced meal.');
    if (a.contains('eggs') &&
        (a.contains('bread') || a.contains('roti / chapati')))
      ideas.add(
          'Eggs with bread or roti, plus fruit or vegetables if available.');
    if ((a.contains('oats') || a.contains('idli / dosa')) &&
        (a.contains('curd') ||
            a.contains('milk') ||
            a.contains('peanuts / nuts')))
      ideas.add(
          'Oats or idli/dosa with a protein-containing side that suits your diet.');
    if ((a.contains('paneer') ||
            a.contains('tofu') ||
            a.contains('soy chunks')) &&
        (a.contains('rice') || a.contains('roti / chapati')))
      ideas.add('Paneer, tofu or soy with rice/roti and vegetables.');
    if (a.contains('roasted chana') ||
        a.contains('banana') ||
        a.contains('other fruits'))
      ideas.add(
          'Quick snack: fruit, roasted chana or a small handful of nuts if suitable.');
    if (ideas.isEmpty)
      ideas.add(
          'Select a few ingredients above to get meal ideas. Include a protein food, grain and vegetables/fruit when available, based on your needs.');
    return ideas;
  }
}

class ExerciseInfo {
  final String name, target, level, equipment, instructions, query;
  const ExerciseInfo(this.name, this.target, this.level, this.equipment,
      this.instructions, this.query);
}

const exercises = <ExerciseInfo>[
  ExerciseInfo(
      'Bodyweight squat',
      'Legs & glutes',
      'Beginner',
      'No equipment',
      'Stand with feet about shoulder-width apart, sit hips back within a comfortable range, then stand. Keep the movement controlled.',
      'bodyweight squat beginner proper form'),
  ExerciseInfo(
      'Wall push-up',
      'Chest & arms',
      'Beginner',
      'Wall',
      'Place hands on a wall, keep your body aligned, bend elbows and push away.',
      'wall push up proper form beginner'),
  ExerciseInfo(
      'Glute bridge',
      'Glutes & hips',
      'Beginner',
      'Mat',
      'Lie on your back with knees bent; gently lift hips, pause, then lower without arching your back.',
      'glute bridge exercise proper form'),
  ExerciseInfo(
      'Bird dog',
      'Core & balance',
      'Beginner',
      'Mat',
      'On hands and knees, extend opposite arm and leg while keeping hips steady; alternate sides.',
      'bird dog exercise physical therapist'),
  ExerciseInfo(
      'Walking',
      'Cardio',
      'Beginner',
      'No equipment',
      'Walk at a pace where you can still speak in sentences; slow down if uncomfortable.',
      'beginner walking workout'),
  ExerciseInfo(
      'Dumbbell row',
      'Back & arms',
      'Beginner',
      'Dumbbells',
      'Support your torso, pull the weight toward your hip with a neutral wrist, and lower slowly.',
      'dumbbell row correct form'),
  ExerciseInfo(
      'Dumbbell goblet squat',
      'Legs & glutes',
      'Beginner',
      'Dumbbells',
      'Hold one dumbbell close to the chest, squat only as deep as comfortable, then stand.',
      'goblet squat correct form'),
  ExerciseInfo(
      'Dumbbell shoulder press',
      'Shoulders',
      'Intermediate',
      'Dumbbells',
      'Use a manageable weight, brace gently, press overhead without forcing range, then lower slowly.',
      'dumbbell shoulder press proper form'),
  ExerciseInfo(
      'Resistance-band row',
      'Back & arms',
      'Beginner',
      'Resistance band',
      'Anchor the band securely, pull elbows back and return slowly. Check the band for damage first.',
      'resistance band row correct form'),
  ExerciseInfo(
      'Stationary bike',
      'Cardio',
      'Beginner',
      'Exercise bike',
      'Adjust the seat so your knee stays slightly bent at the bottom of the pedal stroke; start easy.',
      'stationary exercise bike beginner setup'),
  ExerciseInfo(
      'Lat pulldown',
      'Back',
      'Beginner',
      'Gym machine',
      'Set the pad securely, pull the bar toward upper chest without swinging, and control the return.',
      'lat pulldown machine correct form'),
  ExerciseInfo(
      'Leg press',
      'Legs',
      'Beginner',
      'Gym machine',
      'Keep hips supported, use a comfortable range and do not lock knees forcefully. Ask gym staff to set the machine.',
      'leg press machine proper form beginner'),
  ExerciseInfo(
      'Treadmill walking',
      'Cardio',
      'Beginner',
      'Treadmill',
      'Start with a low speed, use the safety clip and step off only after the belt stops.',
      'treadmill walking beginner safety'),
  ExerciseInfo(
      'Plank from knees',
      'Core',
      'Beginner',
      'Mat',
      'Keep shoulders over elbows and torso aligned; stop if your back or wrists hurt.',
      'kneeling plank proper form'),
];

class ExerciseCentre extends StatefulWidget {
  final Map<String, dynamic> profile;
  const ExerciseCentre({super.key, required this.profile});
  @override
  State<ExerciseCentre> createState() => _ExerciseCentreState();
}

class _ExerciseCentreState extends State<ExerciseCentre> {
  String place = 'All', level = 'All levels', equipment = 'All equipment';
  Future<void> _video(ExerciseInfo e) async {
    final uri = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(e.query)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not open video search. Check your internet connection.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = exercises.where((e) {
      final placeOk = place == 'All' ||
          (place == 'Home' && !e.equipment.startsWith('Gym')) ||
          (place == 'Gym' &&
              (e.equipment.startsWith('Gym') ||
                  e.equipment == 'Dumbbells' ||
                  e.equipment == 'Resistance band' ||
                  e.equipment == 'Exercise bike' ||
                  e.equipment == 'Treadmill'));
      final levelOk = level == 'All levels' || e.level == level;
      final equipOk = equipment == 'All equipment' || e.equipment == equipment;
      return placeOk && levelOk && equipOk;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Find your movement',
            style: TextStyle(
                fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 6),
        const Text(
            'Each tutorial button opens a YouTube search for demonstrations; review the source and choose qualified instructors.',
            style: TextStyle(fontSize: 12, color: Color(0xFF858298))),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
            value: place,
            decoration: const InputDecoration(labelText: 'Workout location'),
            items: ['All', 'Home', 'Gym']
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: (v) => setState(() => place = v ?? 'All')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
            value: level,
            decoration: const InputDecoration(labelText: 'Fitness level'),
            items: ['All levels', 'Beginner', 'Intermediate']
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: (v) => setState(() => level = v ?? 'All levels')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
            value: equipment,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: [
              'All equipment',
              'No equipment',
              'Wall',
              'Mat',
              'Dumbbells',
              'Resistance band',
              'Exercise bike',
              'Gym machine',
              'Treadmill'
            ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setState(() => equipment = v ?? 'All equipment')),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No exercises match all selected filters. Try changing the equipment or level.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...list.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${e.target} · ${e.level} · ${e.equipment}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF858298),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.instructions,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _video(e),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Find video tutorial'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}

class WeeklyRoutinePage extends StatefulWidget {
  final Map<String, dynamic> profile;
  const WeeklyRoutinePage({super.key, required this.profile});
  @override
  State<WeeklyRoutinePage> createState() => _WeeklyRoutinePageState();
}

class _WeeklyRoutinePageState extends State<WeeklyRoutinePage> {
  final Map<String, bool> done = {};
  final days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lifecare_weekly_routine_v1');
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map)
            .forEach((k, v) => done[k.toString()] = v == true);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggle(String day, bool value) async {
    setState(() => done[day] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lifecare_weekly_routine_v1', jsonEncode(done));
  }

  @override
  Widget build(BuildContext context) {
    final preferred =
        (widget.profile['exercise'] ?? 'Walking / gentle movement').toString();
    final plans = [
      '20–30 min comfortable walk + mobility',
      'Beginner full-body strength: squat, wall push-up, row, glute bridge',
      'Gentle walk or stretching / yoga',
      'Easy cardio or a short home workout',
      'Beginner strength routine with rest between sets',
      'Enjoyable activity: walk, cycle, dance or sport',
      'Rest day, gentle mobility or recovery'
    ];
    return Scaffold(
        appBar: AppBar(title: const Text('Weekly routine')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('A flexible 7-day starter',
              style: TextStyle(
                  fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 6),
          Text(
              'Built as a general starting point around your preference: $preferred. Adjust to your ability, schedule and clinician guidance.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF858298))),
          const SizedBox(height: 14),
          ...List.generate(
              7,
              (i) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15)),
                  child: CheckboxListTile(
                    value: done[days[i]] ?? false,
                    onChanged: (v) => _toggle(days[i], v ?? false),
                    title: Text(days[i],
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: ink)),
                    subtitle: Text(plans[i],
                        style: const TextStyle(fontSize: 12, height: 1.35)),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: violet,
                  ))),
          const SizedBox(height: 8),
          Text(
              '${done.values.where((v) => v).length} of 7 sessions checked off',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, color: violet)),
          const SizedBox(height: 12),
          const Text(
              'This is a template, not a prescription. Rest, recovery and gradual progression are important; modify or skip activities that cause pain or symptoms.',
              style: TextStyle(
                  fontSize: 11, height: 1.4, color: Color(0xFF77758A))),
        ]));
  }
}

class ProfilePage extends StatelessWidget {
  final HealthData data;
  final VoidCallback onEdit, onReset;
  const ProfilePage(
      {super.key,
      required this.data,
      required this.onEdit,
      required this.onReset});
  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    final conditions = p['conditions'] is List
        ? (p['conditions'] as List).join(', ')
        : (p['conditions'] ?? 'Not provided').toString();
    final items = <(String, String)>[
      ('Name', (p['name'] ?? 'Not provided').toString()),
      ('Age', (p['age'] ?? 'Not provided').toString()),
      (
        'Height',
        p['height'] == null || p['height'].toString().isEmpty
            ? 'Not provided'
            : '${p['height']} cm'
      ),
      (
        'Weight',
        p['weight'] == null || p['weight'].toString().isEmpty
            ? 'Not provided'
            : '${p['weight']} kg'
      ),
      ('Main goal', (p['goal'] ?? 'Not provided').toString()),
      ('Conditions', conditions),
      ('Food preference', (p['diet'] ?? 'Not provided').toString()),
      (
        'Allergies / restrictions',
        (p['allergies'] ?? 'Not provided').toString()
      ),
      ('Symptoms to track', (p['symptoms'] ?? 'Not provided').toString()),
      (
        'Medicines / supplements',
        (p['medicines'] ?? 'Not provided').toString()
      ),
    ];
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('My health profile',
          style:
              TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 5),
      const Text('Review and update what you have shared.',
          style: TextStyle(color: Color(0xFF858298))),
      const SizedBox(height: 18),
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: lavender, borderRadius: BorderRadius.circular(22)),
                child:
                    const Icon(Icons.person_rounded, color: violet, size: 34)),
            const SizedBox(height: 10),
            Text(
                (p['name'] ?? 'Your profile').toString().isEmpty
                    ? 'Your profile'
                    : (p['name'] ?? 'Your profile').toString(),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 5),
            Text(
                '${data.dailyLogs.length} daily check-ins · ${data.periodLogs.length} cycle entries',
                style: const TextStyle(fontSize: 12, color: Color(0xFF858298))),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit health assessment'))),
          ])),
      const SizedBox(height: 18),
      ...items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 125,
                child: Text(item.$1,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF858298)))),
            Expanded(
                child: Text(item.$2,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ink))),
          ]))),
      const SizedBox(height: 16),
      Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: peach, borderRadius: BorderRadius.circular(18)),
          child: const Text(
              'Privacy: this starter version saves data on this device using local app preferences. It does not have cloud backup, encryption beyond the device/app environment, account login, or a clinician portal. Do not use it on a shared device for sensitive information.',
              style: TextStyle(fontSize: 12, height: 1.45, color: ink))),
      const SizedBox(height: 14),
      OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete all saved health data'),
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB33A53),
              padding: const EdgeInsets.symmetric(vertical: 14))),
      const SizedBox(height: 20),
    ]);
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(14),
            decoration:
                const BoxDecoration(color: lavender, shape: BoxShape.circle),
            child: Icon(icon, size: 27, color: violet)),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, height: 1.4, color: Color(0xFF858298))),
      ]));
}
