import 'package:flutter/material.dart';
import 'package:ocean_baby/app/app_routes.dart';
import 'package:ocean_baby/app/app_theme.dart';
import 'package:ocean_baby/app/ocean_baby_material_app.dart';
import 'package:ocean_baby/core/database/app_database.dart';
import 'package:ocean_baby/features/backup/data/backup_service.dart';
import 'package:ocean_baby/features/home/ui/home_page.dart';
import 'package:ocean_baby/features/ledger/data/ledger_repository.dart';
import 'package:ocean_baby/features/ledger/ui/ledger_page.dart';
import 'package:ocean_baby/features/mood/data/mood_repository.dart';
import 'package:ocean_baby/features/mood/services/mood_prompt_service.dart';
import 'package:ocean_baby/features/mood/ui/mood_page_title.dart';
import 'package:ocean_baby/features/mood/ui/mood_prompt_dialog.dart';
import 'package:ocean_baby/features/mood/ui/mood_page.dart';
import 'package:ocean_baby/features/notes/data/notes_repository.dart';
import 'package:ocean_baby/features/notes/ui/notes_page.dart';
import 'package:ocean_baby/features/todos/data/todos_repository.dart';
import 'package:ocean_baby/features/todos/ui/todos_page.dart';

class OceanBabyApp extends StatefulWidget {
  const OceanBabyApp({super.key, this.database});

  final AppDatabase? database;

  @override
  State<OceanBabyApp> createState() => _OceanBabyAppState();
}

class _OceanBabyAppState extends State<OceanBabyApp> {
  OceanTheme _theme = OceanTheme.tiffanyBlue;

  @override
  Widget build(BuildContext context) {
    return OceanBabyMaterialApp(
      oceanTheme: _theme,
      home: widget.database == null
          ? _DatabaseLoader(onThemeChanged: _setTheme)
          : _OceanBabyShell(
              database: widget.database!,
              onThemeChanged: _setTheme,
            ),
    );
  }

  void _setTheme(OceanTheme theme) {
    setState(() => _theme = theme);
  }
}

class _DatabaseLoader extends StatefulWidget {
  const _DatabaseLoader({required this.onThemeChanged});

  final ValueChanged<OceanTheme> onThemeChanged;

  @override
  State<_DatabaseLoader> createState() => _DatabaseLoaderState();
}

class _DatabaseLoaderState extends State<_DatabaseLoader> {
  late final Future<AppDatabase> _databaseFuture = AppDatabase.open();
  AppDatabase? _database;

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDatabase>(
      future: _databaseFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _database = snapshot.data;
          return _OceanBabyShell(
            database: snapshot.data!,
            onThemeChanged: widget.onThemeChanged,
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('本地数据库打开失败：${snapshot.error}')),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _OceanBabyShell extends StatefulWidget {
  const _OceanBabyShell({required this.database, required this.onThemeChanged});

  final AppDatabase database;
  final ValueChanged<OceanTheme> onThemeChanged;

  @override
  State<_OceanBabyShell> createState() => _OceanBabyShellState();
}

class _OceanBabyShellState extends State<_OceanBabyShell> {
  static const _compactRoutes = <AppRoute>[
    AppRoute.ledger,
    AppRoute.notes,
    AppRoute.todos,
    AppRoute.mood,
    AppRoute.home,
  ];

  static const _wideRoutes = <AppRoute>[
    AppRoute.ledger,
    AppRoute.notes,
    AppRoute.todos,
    AppRoute.mood,
    AppRoute.home,
  ];

  AppRoute _route = AppRoute.home;

  late final _ledgerRepository = LedgerRepository(widget.database);
  late final _notesRepository = NotesRepository(widget.database);
  late final _todosRepository = TodosRepository(widget.database);
  late final _moodRepository = MoodRepository(widget.database);
  late final _moodPromptService = MoodPromptService(_moodRepository);
  late final _backupService = BackupService(widget.database);
  bool _dailyPromptChecked = false;
  int _moodRevision = 0;
  int _dataRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDailyMoodPrompt());
  }

  Future<void> _showDailyMoodPrompt() async {
    if (_dailyPromptChecked || !mounted) return;
    _dailyPromptChecked = true;
    final shouldShow = await _moodPromptService.shouldShowPrompt(
      DateTime.now(),
    );
    if (!mounted || !shouldShow) return;
    final result = await showDialog<MoodPromptResult>(
      context: context,
      builder: (_) => const MoodPromptDialog(),
    );
    if (result == null) return;
    await _moodPromptService.saveFromPrompt(
      DateTime.now(),
      result.mood,
      note: result.note,
    );
    if (!mounted) return;
    _refreshMood();
  }

  void _refreshMood() {
    setState(() => _moodRevision++);
  }

  void _refreshDataAfterRestore() {
    setState(() {
      _dataRevision++;
      _moodRevision++;
      _route = AppRoute.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        return isWide ? _buildWideShell(context) : _buildCompactShell(context);
      },
    );
  }

  Widget _buildCompactShell(BuildContext context) {
    final selectedIndex = _compactRoutes.contains(_route)
        ? _compactRoutes.indexOf(_route)
        : _compactRoutes.indexOf(AppRoute.home);

    return Scaffold(
      appBar: AppBar(title: const Text('Ocean Baby')),
      body: CompactRoutePager(
        routes: _compactRoutes,
        selectedRoute: _compactRoutes[selectedIndex],
        onRouteChanged: (route) => setState(() => _route = route),
        pageBuilder: _buildPageWithMoodScope,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _route = _compactRoutes[index]);
        },
        destinations: _compactRoutes.map((route) {
          return NavigationDestination(
            icon: Icon(route.icon),
            selectedIcon: Icon(route.selectedIcon),
            label: route.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWideShell(BuildContext context) {
    final selectedIndex = _wideRoutes.contains(_route)
        ? _wideRoutes.indexOf(_route)
        : _wideRoutes.indexOf(AppRoute.home);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _route = _wideRoutes[index]);
            },
            leading: const Padding(
              padding: EdgeInsets.fromLTRB(12, 24, 12, 8),
              child: SizedBox(
                width: 160,
                child: Text(
                  'Ocean Baby',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            destinations: _wideRoutes.map((route) {
              return NavigationRailDestination(
                icon: Icon(route.icon),
                selectedIcon: Icon(route.selectedIcon),
                label: Text(route.label),
              );
            }).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              appBar: AppBar(title: Text(_wideRoutes[selectedIndex].label)),
              body: _buildPageWithMoodScope(_wideRoutes[selectedIndex]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageWithMoodScope(AppRoute route) {
    return MoodScope(
      repository: _moodRepository,
      revision: _moodRevision,
      onMoodTap: () => setState(() => _route = AppRoute.mood),
      child: _pageFor(route),
    );
  }

  Widget _pageFor(AppRoute route) {
    return switch (route) {
      AppRoute.home => HomePage(
        key: ValueKey('home-$_dataRevision'),
        ledgerRepository: _ledgerRepository,
        notesRepository: _notesRepository,
        todosRepository: _todosRepository,
        moodRepository: _moodRepository,
        promptService: _moodPromptService,
        backupService: _backupService,
        onDataRestored: _refreshDataAfterRestore,
        onThemeChanged: widget.onThemeChanged,
        onOpenRoute: (route) => setState(() => _route = route),
        onMoodChanged: _refreshMood,
      ),
      AppRoute.ledger => LedgerPage(
        key: ValueKey('ledger-$_dataRevision'),
        repository: _ledgerRepository,
      ),
      AppRoute.notes => NotesPage(
        key: ValueKey('notes-$_dataRevision'),
        repository: _notesRepository,
      ),
      AppRoute.todos => TodosPage(
        key: ValueKey('todos-$_dataRevision'),
        repository: _todosRepository,
      ),
      AppRoute.mood => MoodPage(
        key: ValueKey('mood-$_dataRevision'),
        repository: _moodRepository,
        promptService: _moodPromptService,
        onMoodChanged: _refreshMood,
      ),
    };
  }
}

class CompactRoutePager extends StatefulWidget {
  const CompactRoutePager({
    super.key,
    required this.routes,
    required this.selectedRoute,
    required this.onRouteChanged,
    required this.pageBuilder,
  });

  final List<AppRoute> routes;
  final AppRoute selectedRoute;
  final ValueChanged<AppRoute> onRouteChanged;
  final Widget Function(AppRoute route) pageBuilder;

  @override
  State<CompactRoutePager> createState() => _CompactRoutePagerState();
}

class _CompactRoutePagerState extends State<CompactRoutePager> {
  late final PageController _controller = PageController(
    initialPage: _selectedIndex,
  );
  int? _programmaticTargetIndex;

  int get _selectedIndex {
    final index = widget.routes.indexOf(widget.selectedRoute);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant CompactRoutePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoute == widget.selectedRoute ||
        !_controller.hasClients) {
      return;
    }
    _programmaticTargetIndex = _selectedIndex;
    _controller
        .animateToPage(
          _selectedIndex,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (!mounted) return;
          if (_programmaticTargetIndex == _selectedIndex) {
            _programmaticTargetIndex = null;
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const ValueKey('compact-route-pager'),
      controller: _controller,
      itemCount: widget.routes.length,
      onPageChanged: (index) {
        final targetIndex = _programmaticTargetIndex;
        if (targetIndex != null) {
          if (index == targetIndex) {
            _programmaticTargetIndex = null;
          }
          return;
        }
        widget.onRouteChanged(widget.routes[index]);
      },
      itemBuilder: (context, index) => widget.pageBuilder(widget.routes[index]),
    );
  }
}
