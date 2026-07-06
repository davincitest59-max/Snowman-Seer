import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../platform/app_directories.dart';
import '../../../platform/ocean_file_picker.dart';
import '../../mood/ui/mood_page_title.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.repository});

  final NotesRepository repository;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late Future<List<Note>> _notesFuture;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _notesFuture = widget.repository.search(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openNote(Note note) async {
    final editRequested = await showDialog<bool>(
      context: context,
      builder: (_) => NoteDetailDialog(note: note),
    );
    if (editRequested == true) {
      await _editNote(note: note);
    }
  }

  Future<void> _editNote({Note? note}) async {
    final result = await showDialog<_NoteDraft>(
      context: context,
      builder: (_) => NoteEditorDialog(note: note),
    );
    if (result == null) return;

    if (note == null) {
      await widget.repository.create(
        title: result.title,
        content: result.content,
        folder: result.folder,
        imagePaths: result.imagePaths,
      );
    } else {
      await widget.repository.update(
        id: note.id,
        title: result.title,
        content: result.content,
        folder: result.folder,
        imagePaths: result.imagePaths,
      );
    }
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定删除“${note.title}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.delete(note.id);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _togglePinned(Note note) async {
    await widget.repository.setPinned(note.id, !note.pinned);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Note>>(
      future: _notesFuture,
      builder: (context, snapshot) {
        return NotesListContent(
          searchController: _searchController,
          notes: snapshot.data ?? const <Note>[],
          isLoading: snapshot.connectionState != ConnectionState.done,
          onSearchChanged: (_) => setState(_reload),
          onCreateNote: () => _editNote(),
          onOpenNote: _openNote,
          onTogglePinned: _togglePinned,
          onDeleteNote: _deleteNote,
        );
      },
    );
  }
}

class NotesListContent extends StatelessWidget {
  const NotesListContent({
    super.key,
    required this.searchController,
    required this.notes,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onCreateNote,
    required this.onOpenNote,
    required this.onTogglePinned,
    required this.onDeleteNote,
  });

  final TextEditingController searchController;
  final List<Note> notes;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreateNote;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<Note> onTogglePinned;
  final ValueChanged<Note> onDeleteNote;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const MoodPageTitle('笔记'),
        const SizedBox(height: 16),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: '搜索笔记',
          ),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (notes.isEmpty)
          const Card(
            child: ListTile(
              title: Text('暂无笔记'),
              subtitle: Text('点击下方按钮创建第一条笔记'),
            ),
          )
        else
          Column(
            children: notes.map((note) {
              return NoteListItem(
                note: note,
                onTap: () => onOpenNote(note),
                onTogglePinned: () => onTogglePinned(note),
                onDelete: () => onDeleteNote(note),
              );
            }).toList(),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreateNote,
          icon: const Icon(Icons.add),
          label: const Text('新建笔记'),
        ),
      ],
    );
  }
}

class NoteDetailDialog extends StatelessWidget {
  const NoteDetailDialog({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(note.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.content.isEmpty)
              const Text('暂无正文')
            else
              Text(note.content),
            if (note.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < note.imagePaths.length; index++)
                    InkWell(
                      key: ValueKey('note-image-preview-trigger-$index'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          useSafeArea: false,
                          barrierColor: Colors.black,
                          builder: (_) => ImagePreviewDialog(
                            imagePaths: note.imagePaths,
                            initialIndex: index,
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 132,
                        height: 96,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(note.imagePaths[index]),
                            width: 132,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('编辑'),
        ),
      ],
    );
  }
}

class ImagePreviewDialog extends StatefulWidget {
  ImagePreviewDialog({
    super.key,
    String imagePath = '',
    List<String> imagePaths = const [],
    this.initialIndex = 0,
  }) : imagePaths = imagePaths.isNotEmpty
           ? List.unmodifiable(imagePaths)
           : imagePath.isEmpty
           ? const <String>[]
           : List.unmodifiable([imagePath]);

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  key: index == widget.initialIndex
                      ? const ValueKey('note-image-preview-viewer')
                      : ValueKey('note-image-preview-viewer-$index'),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      File(widget.imagePaths[index]),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteListItem extends StatelessWidget {
  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePinned;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: IconButton(
          tooltip: note.pinned ? '取消置顶' : '置顶',
          icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
          onPressed: onTogglePinned,
        ),
        title: Text(note.title),
        subtitle: null,
        onTap: onTap,
        trailing: IconButton(
          tooltip: '删除',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class NoteEditorDialog extends StatefulWidget {
  const NoteEditorDialog({super.key, this.note, OceanFilePicker? filePicker})
    : filePicker = filePicker ?? const OceanFilePickerBridge();

  final Note? note;
  final OceanFilePicker filePicker;

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _folderController = TextEditingController(text: '默认');
  final List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _folderController.text = note.folder;
      _imagePaths.addAll(note.imagePaths);
    }
  }

  Future<void> _pickImage() async {
    final images = await widget.filePicker.pickImages(allowMultiple: true);
    if (images.isEmpty) {
      return;
    }
    try {
      final storedPaths = <String>[];
      for (final image in images) {
        storedPaths.add(
          await _copyImageToAppStorage(
            fileName: image.name,
            bytes: image.bytes,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _imagePaths.addAll(storedPaths));
    } on FileSystemException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片保存失败，请重新选择')));
    }
  }

  Future<String> _copyImageToAppStorage({
    required String fileName,
    required List<int> bytes,
  }) async {
    final directory = await const AppDirectoriesBridge()
        .applicationDocumentsDirectory();
    final imageDirectory = Directory(p.join(directory.path, 'note_images'));
    if (!await imageDirectory.exists()) {
      await imageDirectory.create(recursive: true);
    }
    final extension = p.extension(fileName);
    final targetName =
        '${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}';
    final target = File(p.join(imageDirectory.path, targetName));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '标题'),
            autofocus: true,
          ),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(labelText: '内容'),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          if (_imagePaths.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < _imagePaths.length; index++)
                  SizedBox(
                    key: ValueKey('note-editor-image-$index'),
                    width: 96,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_imagePaths[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const DecoratedBox(
                              decoration: BoxDecoration(color: Colors.black12),
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton.filledTonal(
                            tooltip: '移除图片',
                            iconSize: 16,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            onPressed: () =>
                                setState(() => _imagePaths.removeAt(index)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_imagePaths.isEmpty ? '添加图片' : '继续添加图片'),
                ),
              ),
            ],
          ),
          TextField(
            controller: _folderController,
            decoration: const InputDecoration(labelText: '分类'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.of(context).pop(
              _NoteDraft(
                title: title,
                content: _contentController.text.trim(),
                folder: _folderController.text.trim().isEmpty
                    ? '默认'
                    : _folderController.text.trim(),
                imagePaths: List.unmodifiable(_imagePaths),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _NoteDraft {
  const _NoteDraft({
    required this.title,
    required this.content,
    required this.folder,
    required this.imagePaths,
  });

  final String title;
  final String content;
  final String folder;
  final List<String> imagePaths;
}
