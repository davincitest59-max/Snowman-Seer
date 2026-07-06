import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ocean_baby/app/app_routes.dart';
import 'package:ocean_baby/app/app_theme.dart';
import 'package:ocean_baby/features/backup/data/backup_models.dart';
import 'package:ocean_baby/features/backup/data/backup_service.dart';
import 'package:ocean_baby/features/ledger/data/ledger_repository.dart';
import 'package:ocean_baby/features/mood/data/mood_repository.dart';
import 'package:ocean_baby/features/mood/services/mood_prompt_service.dart';
import 'package:ocean_baby/features/mood/ui/mood_page_title.dart';
import 'package:ocean_baby/features/notes/data/notes_repository.dart';
import 'package:ocean_baby/features/todos/data/todos_repository.dart';
import 'package:ocean_baby/platform/ocean_file_picker.dart';
import 'package:ocean_baby/platform/notification_permission.dart';

abstract class BackupFileBridge {
  Future<String?> saveBackup({
    required String fileName,
    required List<int> bytes,
  });

  Future<List<int>?> pickBackupBytes();
}

class OceanBackupFileBridge implements BackupFileBridge {
  const OceanBackupFileBridge([
    this._filePicker = const OceanFilePickerBridge(),
  ]);

  final OceanFilePicker _filePicker;

  @override
  Future<String?> saveBackup({
    required String fileName,
    required List<int> bytes,
  }) {
    return _filePicker.saveFile(
      fileName: fileName,
      mimeType: 'application/octet-stream',
      bytes: Uint8List.fromList(bytes),
    );
  }

  @override
  Future<List<int>?> pickBackupBytes() async {
    final file = await _filePicker.pickFile();
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.oceanbaby')) {
      throw const BackupException('请选择 .oceanbaby 备份文件');
    }
    return file.bytes;
  }
}

class BackupImportPickResult {
  const BackupImportPickResult._({this.bytes, this.message});

  const BackupImportPickResult.selected(List<int> bytes) : this._(bytes: bytes);

  const BackupImportPickResult.message(String message)
    : this._(message: message);

  final List<int>? bytes;
  final String? message;
}

Future<BackupImportPickResult> pickBackupForImport(
  BackupFileBridge backupFileBridge,
) async {
  try {
    final bytes = await backupFileBridge.pickBackupBytes();
    if (bytes == null) {
      return const BackupImportPickResult.message('已取消导入');
    }
    return BackupImportPickResult.selected(bytes);
  } on BackupException catch (error) {
    return BackupImportPickResult.message(error.message);
  } on PlatformException {
    return const BackupImportPickResult.message('无法打开文件选择器，请重新尝试');
  } catch (_) {
    return const BackupImportPickResult.message('无法读取备份文件，请重新选择');
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.ledgerRepository,
    required this.notesRepository,
    required this.todosRepository,
    required this.moodRepository,
    required this.promptService,
    required this.backupService,
    required this.onDataRestored,
    required this.onThemeChanged,
    required this.onOpenRoute,
    required this.onMoodChanged,
    BackupFileBridge? backupFileBridge,
    NotificationPermissionBridge? permissionBridge,
  }) : backupFileBridge = backupFileBridge ?? const OceanBackupFileBridge(),
       permissionBridge =
           permissionBridge ?? const NotificationPermissionBridge();

  final LedgerRepository ledgerRepository;
  final NotesRepository notesRepository;
  final TodosRepository todosRepository;
  final MoodRepository moodRepository;
  final MoodPromptService promptService;
  final BackupService backupService;
  final VoidCallback onDataRestored;
  final ValueChanged<OceanTheme> onThemeChanged;
  final ValueChanged<AppRoute> onOpenRoute;
  final VoidCallback onMoodChanged;
  final BackupFileBridge backupFileBridge;
  final NotificationPermissionBridge permissionBridge;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<bool> _promptEnabledFuture;
  late Future<bool> _showMoodDotFuture;
  late Future<bool> _showMoodTextFuture;
  late Future<bool> _showMoodNoteFuture;
  late Future<bool> _notificationEnabledFuture;
  late Future<bool> _todoAutoDeleteCompletedFuture;
  bool _backupBusy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _promptEnabledFuture = widget.moodRepository.getPromptEnabled();
    _showMoodDotFuture = widget.moodRepository.getShowMoodDot();
    _showMoodTextFuture = widget.moodRepository.getShowMoodText();
    _showMoodNoteFuture = widget.moodRepository.getShowMoodNote();
    _notificationEnabledFuture = widget.permissionBridge
        .isNotificationListenerEnabled();
    _todoAutoDeleteCompletedFuture = widget.todosRepository
        .getAutoDeleteCompleted();
  }

  Future<void> _setPromptEnabled(bool enabled) async {
    await widget.promptService.setPromptEnabled(enabled);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _setShowMoodDot(bool enabled) async {
    await widget.moodRepository.setShowMoodDot(enabled);
    if (!mounted) return;
    widget.onMoodChanged();
    setState(_reload);
  }

  Future<void> _setShowMoodText(bool enabled) async {
    await widget.moodRepository.setShowMoodText(enabled);
    if (!mounted) return;
    widget.onMoodChanged();
    setState(_reload);
  }

  Future<void> _setShowMoodNote(bool enabled) async {
    await widget.moodRepository.setShowMoodNote(enabled);
    if (!mounted) return;
    widget.onMoodChanged();
    setState(_reload);
  }

  Future<void> _setTodoAutoDeleteCompleted(bool enabled) async {
    await widget.todosRepository.setAutoDeleteCompleted(enabled);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _openNotificationSettings() async {
    await widget.permissionBridge.openNotificationListenerSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请在系统页面为 Ocean Baby 开启通知使用权')));
    setState(_reload);
  }

  Future<void> _exportBackup() async {
    setState(() => _backupBusy = true);
    try {
      final backup = await widget.backupService.createBackup();
      final savedPath = await widget.backupFileBridge.saveBackup(
        fileName: backup.fileName,
        bytes: backup.bytes,
      );
      if (!mounted) return;
      final imageMessage = backup.missingImagePaths.isEmpty
          ? ''
          : '，${backup.missingImagePaths.length} 张图片未找到';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null ? '已取消导出' : '数据已导出$imageMessage'),
        ),
      );
    } on BackupException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导出失败，请重新尝试')));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() => _backupBusy = true);
    final pickResult = await pickBackupForImport(widget.backupFileBridge);
    if (!mounted) return;
    setState(() => _backupBusy = false);
    final pickMessage = pickResult.message;
    if (pickMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pickMessage)));
      return;
    }
    final bytes = pickResult.bytes!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入恢复数据'),
        content: const Text('导入会覆盖当前全部本地数据。请确认已经保存好当前数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _backupBusy = true);
    try {
      await widget.backupService.restoreFromBytes(bytes);
      widget.onDataRestored();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据已恢复')));
    } on BackupException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导入失败，请重新选择备份文件')));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: SettingsHomeContent(
        settingsSection: HomeSettingsSection(
          promptEnabledFuture: _promptEnabledFuture,
          showMoodDotFuture: _showMoodDotFuture,
          showMoodTextFuture: _showMoodTextFuture,
          showMoodNoteFuture: _showMoodNoteFuture,
          notificationEnabledFuture: _notificationEnabledFuture,
          todoAutoDeleteCompletedFuture: _todoAutoDeleteCompletedFuture,
          backupBusy: _backupBusy,
          onPromptChanged: _setPromptEnabled,
          onShowMoodDotChanged: _setShowMoodDot,
          onShowMoodTextChanged: _setShowMoodText,
          onShowMoodNoteChanged: _setShowMoodNote,
          onTodoAutoDeleteCompletedChanged: _setTodoAutoDeleteCompleted,
          onNotificationSettingsRequested: _openNotificationSettings,
          onExportBackup: _exportBackup,
          onImportBackup: _importBackup,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }
}

class SettingsHomeContent extends StatelessWidget {
  const SettingsHomeContent({super.key, required this.settingsSection});

  final Widget settingsSection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SettingsHomeTitle(),
        const SizedBox(height: 20),
        settingsSection,
      ],
    );
  }
}

class SettingsHomeTitle extends StatelessWidget {
  const SettingsHomeTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoodPageTitle('设置');
  }
}

class HomeSettingsSection extends StatelessWidget {
  const HomeSettingsSection({
    super.key,
    required this.promptEnabledFuture,
    required this.showMoodDotFuture,
    required this.showMoodTextFuture,
    required this.showMoodNoteFuture,
    required this.notificationEnabledFuture,
    required this.todoAutoDeleteCompletedFuture,
    required this.backupBusy,
    required this.onPromptChanged,
    required this.onShowMoodDotChanged,
    required this.onShowMoodTextChanged,
    required this.onShowMoodNoteChanged,
    required this.onTodoAutoDeleteCompletedChanged,
    required this.onNotificationSettingsRequested,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onThemeChanged,
  });

  final Future<bool> promptEnabledFuture;
  final Future<bool> showMoodDotFuture;
  final Future<bool> showMoodTextFuture;
  final Future<bool> showMoodNoteFuture;
  final Future<bool> notificationEnabledFuture;
  final Future<bool> todoAutoDeleteCompletedFuture;
  final bool backupBusy;
  final ValueChanged<bool> onPromptChanged;
  final ValueChanged<bool> onShowMoodDotChanged;
  final ValueChanged<bool> onShowMoodTextChanged;
  final ValueChanged<bool> onShowMoodNoteChanged;
  final ValueChanged<bool> onTodoAutoDeleteCompletedChanged;
  final VoidCallback onNotificationSettingsRequested;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final ValueChanged<OceanTheme> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '设置',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _SettingsCategory(
          title: '外观设置',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('高级配色'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: OceanTheme.values.map((theme) {
                    return ActionChip(
                      avatar: CircleAvatar(backgroundColor: theme.seedColor),
                      label: Text(theme.label),
                      onPressed: () => onThemeChanged(theme),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<bool>(
          future: promptEnabledFuture,
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? true;
            return _SettingsCategory(
              title: '心情设置',
              child: Column(
                children: [
                  SwitchListTile(
                    value: enabled,
                    onChanged: onPromptChanged,
                    title: const Text('每日心情弹框'),
                    subtitle: const Text('开启后每天第一次打开应用时询问心情'),
                  ),
                  const Divider(height: 1),
                  FutureBuilder<bool>(
                    future: showMoodDotFuture,
                    builder: (context, snapshot) {
                      return SwitchListTile(
                        value: snapshot.data ?? true,
                        onChanged: onShowMoodDotChanged,
                        title: const Text('显示心情小圆点'),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  FutureBuilder<bool>(
                    future: showMoodTextFuture,
                    builder: (context, snapshot) {
                      return SwitchListTile(
                        value: snapshot.data ?? true,
                        onChanged: onShowMoodTextChanged,
                        title: const Text('显示心情文字'),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  FutureBuilder<bool>(
                    future: showMoodNoteFuture,
                    builder: (context, snapshot) {
                      return SwitchListTile(
                        value: snapshot.data ?? true,
                        onChanged: onShowMoodNoteChanged,
                        title: const Text('显示心情备注'),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<bool>(
          future: todoAutoDeleteCompletedFuture,
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            return _SettingsCategory(
              title: '待办设置',
              child: SwitchListTile(
                value: enabled,
                onChanged: onTodoAutoDeleteCompletedChanged,
                secondary: const Icon(Icons.task_alt_outlined),
                title: const Text('勾选待办自动删除'),
                subtitle: const Text('开启后勾选完成会自动删除；关闭后可手动删除已勾选待办。'),
              ),
            );
          },
        ),
        FutureBuilder<bool>(
          future: notificationEnabledFuture,
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            return _SettingsCategory(
              title: '账本设置',
              child: Column(
                children: [
                  SwitchListTile(
                    value: enabled,
                    onChanged: (_) => onNotificationSettingsRequested(),
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('自动记账'),
                    subtitle: Text(
                      enabled
                          ? '通知使用权已开启，微信和支付宝通知会自动进入账本'
                          : '点击前往系统设置，开启 Ocean Baby 通知使用权',
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('微信账单录入方式'),
                    subtitle: Text(
                      '安卓不允许第三方应用直接读取微信内部账单库。请开启通知自动记账，或导入微信、支付宝导出的账单文件。',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        _SettingsCategory(
          title: '数据备份与恢复',
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('导出全部数据'),
                subtitle: const Text('生成一个可用于重装后恢复的 Ocean Baby 备份文件'),
                trailing: backupBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: backupBusy ? null : onExportBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: const Text('导入恢复数据'),
                subtitle: const Text('选择 .oceanbaby 文件并覆盖恢复当前本地数据'),
                trailing: backupBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: backupBusy ? null : onImportBackup,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCategory extends StatelessWidget {
  const _SettingsCategory({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [child],
        ),
      ),
    );
  }
}
