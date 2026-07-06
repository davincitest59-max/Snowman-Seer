import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/core/database/app_database.dart';
import 'package:ocean_baby/features/notes/data/notes_repository.dart';

void main() {
  test('新增笔记后可以按最近更新查询', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = NotesRepository(db);

    await repo.create(title: '购物清单', content: '牛奶\n面包', folder: '生活');

    final notes = await repo.listRecent();
    expect(notes, hasLength(1));
    expect(notes.single.title, '购物清单');
  });

  test('笔记可以编辑、置顶、搜索和删除', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = NotesRepository(db);

    final note = await repo.create(title: '购物清单', content: '牛奶', folder: '生活');
    await repo.update(
      id: note.id,
      title: '周末购物',
      content: '牛奶\n面包',
      folder: '生活',
      imagePaths: ['/tmp/note-image-a.png', '/tmp/note-image-b.png'],
    );
    await repo.setPinned(note.id, true);

    final searched = await repo.search('面包');
    expect(searched, hasLength(1));
    expect(searched.single.title, '周末购物');
    expect(searched.single.pinned, isTrue);
    expect(searched.single.imagePaths, [
      '/tmp/note-image-a.png',
      '/tmp/note-image-b.png',
    ]);
    expect(searched.single.imagePath, '/tmp/note-image-a.png');

    await repo.delete(note.id);
    expect(await repo.listRecent(), isEmpty);
  });

  test('旧版单图片路径会兼容读取为单张图片列表', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = NotesRepository(db);

    await repo.create(
      title: '旧笔记',
      content: '旧图片',
      folder: '默认',
      imagePath: '/tmp/legacy-image.png',
    );

    final notes = await repo.listRecent();
    expect(notes.single.imagePaths, ['/tmp/legacy-image.png']);
  });
}
