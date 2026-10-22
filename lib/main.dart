import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');
const String kAppName = 'JULIENNE PIERRE-LOUIS';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = OperationsStore(screenshotMode: kScreenshotMode);
  await store.load();
  runApp(OperationsApp(store: store));
}

class OperationsApp extends StatelessWidget {
  const OperationsApp({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFF1F7C);
    const navy = Color(0xFF09123D);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(
          primary: navy,
          onPrimary: Colors.white,
          secondary: const Color(0xFF0F7F96),
          tertiary: const Color(0xFFD09460),
          surface: const Color(0xFFF6F8FC),
          surfaceContainerHighest: const Color(0xFFE5EBF4),
        );

    return StoreScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: kAppName,
        theme: ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          scaffoldBackgroundColor: scheme.surface,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        home: const OperationsShell(),
      ),
    );
  }
}

class StoreScope extends InheritedNotifier<OperationsStore> {
  const StoreScope({
    super.key,
    required OperationsStore store,
    required super.child,
  }) : super(notifier: store);

  static OperationsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope is missing from the widget tree');
    return scope!.notifier!;
  }
}

enum Workstream { payroll, shifts, facilities, training }

extension WorkstreamMeta on Workstream {
  String get label => switch (this) {
    Workstream.payroll => 'Payroll',
    Workstream.shifts => 'Shifts',
    Workstream.facilities => 'Facilities',
    Workstream.training => 'Training',
  };

  String get shortLabel => switch (this) {
    Workstream.payroll => 'Payroll',
    Workstream.shifts => 'Shifts',
    Workstream.facilities => 'Rooms',
    Workstream.training => 'Courses',
  };

  String get plural => switch (this) {
    Workstream.payroll => 'Payroll reports',
    Workstream.shifts => 'Shift coverage',
    Workstream.facilities => 'Facility bookings',
    Workstream.training => 'Training courses',
  };

  IconData get icon => switch (this) {
    Workstream.payroll => Icons.summarize_outlined,
    Workstream.shifts => Icons.calendar_month_outlined,
    Workstream.facilities => Icons.meeting_room_outlined,
    Workstream.training => Icons.school_outlined,
  };

  Color get accent => switch (this) {
    Workstream.payroll => const Color(0xFF1086B1),
    Workstream.shifts => const Color(0xFF0F7F96),
    Workstream.facilities => const Color(0xFFD09460),
    Workstream.training => const Color(0xFF4D6AB4),
  };

  String get ownerLabel => switch (this) {
    Workstream.payroll => 'Prepared by',
    Workstream.shifts => 'Lead',
    Workstream.facilities => 'Requester',
    Workstream.training => 'Coordinator',
  };

  String get scheduleLabel => switch (this) {
    Workstream.payroll => 'Pay period',
    Workstream.shifts => 'Shift date',
    Workstream.facilities => 'Booking time',
    Workstream.training => 'Course date',
  };

  String get metricLabel => switch (this) {
    Workstream.payroll => 'Gross total',
    Workstream.shifts => 'Coverage',
    Workstream.facilities => 'Room',
    Workstream.training => 'Progress',
  };

  List<String> get statuses => switch (this) {
    Workstream.payroll => ['Draft', 'Review', 'Ready', 'Filed'],
    Workstream.shifts => ['Open', 'Covered', 'Confirmed'],
    Workstream.facilities => ['Requested', 'Reserved', 'Ready'],
    Workstream.training => ['Planned', 'In progress', 'Complete'],
  };

  String get createLabel => switch (this) {
    Workstream.payroll => 'Add payroll report',
    Workstream.shifts => 'Add shift plan',
    Workstream.facilities => 'Book facility',
    Workstream.training => 'Add course',
  };
}

class OpsRecord {
  const OpsRecord({
    required this.id,
    required this.stream,
    required this.title,
    required this.owner,
    required this.scheduledFor,
    required this.status,
    required this.metric,
    required this.summary,
  });

  final String id;
  final Workstream stream;
  final String title;
  final String owner;
  final String scheduledFor;
  final String status;
  final String metric;
  final String summary;

  OpsRecord copyWith({String? status}) {
    return OpsRecord(
      id: id,
      stream: stream,
      title: title,
      owner: owner,
      scheduledFor: scheduledFor,
      status: status ?? this.status,
      metric: metric,
      summary: summary,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'stream': stream.name,
    'title': title,
    'owner': owner,
    'scheduledFor': scheduledFor,
    'status': status,
    'metric': metric,
    'summary': summary,
  };

  factory OpsRecord.fromJson(Map<String, Object?> json) {
    return OpsRecord(
      id: json['id'] as String,
      stream: Workstream.values.firstWhere(
        (stream) => stream.name == json['stream'],
        orElse: () => Workstream.payroll,
      ),
      title: json['title'] as String,
      owner: json['owner'] as String,
      scheduledFor: json['scheduledFor'] as String,
      status: json['status'] as String,
      metric: json['metric'] as String,
      summary: json['summary'] as String,
    );
  }
}

class OperationsStore extends ChangeNotifier {
  OperationsStore({required this.screenshotMode});

  static const _storageKey = 'julienne_operations_records_v1';
  final bool screenshotMode;
  List<OpsRecord> _records = [];

  List<OpsRecord> get records => List.unmodifiable(_records);

  Future<void> load() async {
    if (screenshotMode) {
      _records = _sampleRecords();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _records = [];
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    _records = decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => OpsRecord.fromJson(Map<String, Object?>.from(item)))
        .toList();
  }

  List<OpsRecord> byStream(Workstream stream) {
    return _records.where((record) => record.stream == stream).toList();
  }

  int countByStream(Workstream stream) => byStream(stream).length;

  int get readyCount {
    return _records.where((record) {
      final normalized = record.status.toLowerCase();
      return normalized == 'ready' ||
          normalized == 'filed' ||
          normalized == 'confirmed' ||
          normalized == 'complete';
    }).length;
  }

  void addRecord(OpsRecord record) {
    _records = [record, ..._records];
    notifyListeners();
    unawaited(_save());
  }

  void updateStatus(String id, String status) {
    _records = [
      for (final record in _records)
        if (record.id == id) record.copyWith(status: status) else record,
    ];
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _records.map((record) => record.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }

  static List<OpsRecord> _sampleRecords() => const [
    OpsRecord(
      id: 'payroll-may',
      stream: Workstream.payroll,
      title: 'JULIENNE PIERRE-LOUIS',
      owner: 'M. Laurent',
      scheduledFor: 'May 1-15, 2026',
      status: 'Review',
      metric: '\$42,860',
      summary: 'Timesheets reconciled for 38 staff with overtime notes ready.',
    ),
    OpsRecord(
      id: 'shift-weekend',
      stream: Workstream.shifts,
      title: 'Weekend front desk roster',
      owner: 'A. Bernard',
      scheduledFor: 'Sat, May 16',
      status: 'Covered',
      metric: '8 of 8',
      summary: 'Coverage confirmed for reception, receiving, and closing.',
    ),
    OpsRecord(
      id: 'facility-room-a',
      stream: Workstream.facilities,
      title: 'North training room',
      owner: 'Operations',
      scheduledFor: 'Thu, May 14 - 10:00',
      status: 'Reserved',
      metric: 'Room A',
      summary: 'Seats arranged for 16 staff with projector and access cards.',
    ),
    OpsRecord(
      id: 'training-safety',
      stream: Workstream.training,
      title: 'Safety refresher course',
      owner: 'J. Pierre-Louis',
      scheduledFor: 'Fri, May 15',
      status: 'In progress',
      metric: '72%',
      summary: 'Managers are reviewing incident response and sign-off items.',
    ),
    OpsRecord(
      id: 'training-policy',
      stream: Workstream.training,
      title: 'New hire policy module',
      owner: 'Training desk',
      scheduledFor: 'Mon, May 18',
      status: 'Planned',
      metric: '12 seats',
      summary: 'Enrollment list prepared for the next onboarding group.',
    ),
  ];
}

class OperationsShell extends StatefulWidget {
  const OperationsShell({super.key});

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      const NavigationDestination(
        key: ValueKey('nav-dashboard'),
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Desk',
      ),
      NavigationDestination(
        key: const ValueKey('nav-payroll'),
        icon: Icon(Workstream.payroll.icon),
        selectedIcon: Icon(Workstream.payroll.icon),
        label: 'Payroll',
      ),
      NavigationDestination(
        key: const ValueKey('nav-shifts'),
        icon: Icon(Workstream.shifts.icon),
        selectedIcon: Icon(Workstream.shifts.icon),
        label: 'Shifts',
      ),
      NavigationDestination(
        key: const ValueKey('nav-facilities'),
        icon: Icon(Workstream.facilities.icon),
        selectedIcon: Icon(Workstream.facilities.icon),
        label: 'Rooms',
      ),
      NavigationDestination(
        key: const ValueKey('nav-training'),
        icon: Icon(Workstream.training.icon),
        selectedIcon: Icon(Workstream.training.icon),
        label: 'Courses',
      ),
    ];

    final pages = [
      DashboardScreen(
        onOpenStream: (stream) {
          setState(() => _index = Workstream.values.indexOf(stream) + 1);
        },
      ),
      RecordsScreen(stream: Workstream.payroll),
      RecordsScreen(stream: Workstream.shifts),
      RecordsScreen(stream: Workstream.facilities),
      RecordsScreen(stream: Workstream.training),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations desk'),
        actions: [
          IconButton(
            key: const ValueKey('settings-button'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: destinations,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenStream});

  final ValueChanged<Workstream> onOpenStream;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final total = store.records.length;
    final ready = store.readyCount;
    final readiness = total == 0 ? 0 : (ready / total * 100).round();

    return ListView(
      key: const ValueKey('dashboard-screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 2.05,
                child: Image.asset('docs/featured.png', fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kAppName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Daily operations status',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.28,
          children: [
            StatTile(
              icon: Icons.assignment_turned_in_outlined,
              label: 'Records',
              value: '$total',
              color: scheme.primary,
            ),
            StatTile(
              icon: Icons.verified_outlined,
              label: 'Ready',
              value: '$ready',
              color: scheme.secondary,
            ),
            StatTile(
              icon: Icons.trending_up_outlined,
              label: 'Readiness',
              value: '$readiness%',
              color: scheme.tertiary,
            ),
            StatTile(
              icon: Icons.event_available_outlined,
              label: 'Today',
              value: '${store.records.take(2).length}',
              color: const Color(0xFF4D6AB4),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Workstreams',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final stream in Workstream.values) ...[
          WorkstreamTile(
            stream: stream,
            count: store.countByStream(stream),
            onTap: () => onOpenStream(stream),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkstreamTile extends StatelessWidget {
  const WorkstreamTile({
    super.key,
    required this.stream,
    required this.count,
    required this.onTap,
  });

  final Workstream stream;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: stream.accent.withValues(alpha: 0.14),
          foregroundColor: stream.accent,
          child: Icon(stream.icon),
        ),
        title: Text(stream.plural),
        subtitle: Text('$count active ${count == 1 ? 'item' : 'items'}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.stream});

  final Workstream stream;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final records = store.byStream(stream);

    return Scaffold(
      key: ValueKey('${stream.name}-screen'),
      body: records.isEmpty
          ? EmptyRecords(stream: stream)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
              itemCount: records.length + 1,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return StreamHeader(stream: stream, count: records.length);
                }
                final record = records[index - 1];
                return RecordCard(record: record);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: ValueKey('add-${stream.name}'),
        heroTag: 'add-${stream.name}',
        tooltip: stream.createLabel,
        icon: const Icon(Icons.add),
        label: Text(stream.createLabel),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecordFormScreen(stream: stream),
            ),
          );
        },
      ),
    );
  }
}

class StreamHeader extends StatelessWidget {
  const StreamHeader({super.key, required this.stream, required this.count});

  final Workstream stream;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stream.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stream.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(stream.icon, color: stream.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stream.plural,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text('$count active ${count == 1 ? 'record' : 'records'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyRecords extends StatelessWidget {
  const EmptyRecords({super.key, required this.stream});

  final Workstream stream;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: stream.accent.withValues(alpha: 0.12),
              foregroundColor: stream.accent,
              child: Icon(stream.icon, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              stream.plural,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'No records saved yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record});

  final OpsRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecordDetailScreen(recordId: record.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: record.stream.accent.withValues(
                      alpha: 0.12,
                    ),
                    foregroundColor: record.stream.accent,
                    child: Icon(record.stream.icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(record.scheduledFor),
                      ],
                    ),
                  ),
                  StatusChip(label: record.status, color: record.stream.accent),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                record.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(record.owner)),
                  Text(
                    '${record.stream.metricLabel}: ${record.metric}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RecordDetailScreen extends StatelessWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final record = store.records.firstWhere((item) => item.id == recordId);
    final nextStatuses = record.stream.statuses.where(
      (status) => status != record.status,
    );

    return Scaffold(
      key: const ValueKey('detail-screen'),
      appBar: AppBar(title: Text(record.stream.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: record.stream.accent.withValues(
                          alpha: 0.14,
                        ),
                        foregroundColor: record.stream.accent,
                        child: Icon(record.stream.icon),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          record.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StatusChip(label: record.status, color: record.stream.accent),
                  const SizedBox(height: 18),
                  DetailRow(
                    label: record.stream.ownerLabel,
                    value: record.owner,
                  ),
                  DetailRow(
                    label: record.stream.scheduleLabel,
                    value: record.scheduledFor,
                  ),
                  DetailRow(
                    label: record.stream.metricLabel,
                    value: record.metric,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(record.summary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Update status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in nextStatuses)
                ActionChip(
                  label: Text(status),
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  onPressed: () => store.updateStatus(record.id, status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, required this.stream});

  final Workstream stream;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _owner;
  late final TextEditingController _scheduledFor;
  late final TextEditingController _metric;
  late final TextEditingController _summary;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.stream.statuses.first;
    _title = TextEditingController();
    _owner = TextEditingController();
    _scheduledFor = TextEditingController();
    _metric = TextEditingController();
    _summary = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    _scheduledFor.dispose();
    _metric.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('record-form-screen'),
      appBar: AppBar(title: Text(widget.stream.createLabel)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const ValueKey('record-title-field'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('record-owner-field'),
              controller: _owner,
              decoration: InputDecoration(labelText: widget.stream.ownerLabel),
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('record-schedule-field'),
              controller: _scheduledFor,
              decoration: InputDecoration(
                labelText: widget.stream.scheduleLabel,
              ),
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('record-metric-field'),
              controller: _metric,
              decoration: InputDecoration(labelText: widget.stream.metricLabel),
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('record-status-field'),
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final status in widget.stream.statuses)
                  DropdownMenuItem(value: status, child: Text(status)),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('record-summary-field'),
              controller: _summary,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notes'),
              validator: _required,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('save-record-button'),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save record'),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final record = OpsRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      stream: widget.stream,
      title: _title.text.trim(),
      owner: _owner.text.trim(),
      scheduledFor: _scheduledFor.text.trim(),
      status: _status,
      metric: _metric.text.trim(),
      summary: _summary.text.trim(),
    );
    StoreScope.of(context).addRecord(record);
    Navigator.of(context).pop();
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('settings-screen'),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'docs/icon.png',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kAppName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Local operations workspace',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.storage_outlined,
                  title: 'Device storage',
                  subtitle: 'Records stay on this Android device.',
                  color: scheme.primary,
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.cloud_off_outlined,
                  title: 'No account sync',
                  subtitle:
                      'No login, analytics, advertising IDs, or cloud transfer.',
                  color: scheme.secondary,
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy contact',
                  subtitle: 'support@juliennepierre-louis.com',
                  color: scheme.tertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
