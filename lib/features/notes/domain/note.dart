class Note {
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.folder,
    required this.pinned,
    String imagePath = '',
    List<String> imagePaths = const [],
    required this.updatedAt,
  }) : imagePaths = List.unmodifiable(
         imagePaths.isNotEmpty
             ? imagePaths
             : imagePath.isEmpty
             ? const <String>[]
             : <String>[imagePath],
       );

  final int id;
  final String title;
  final String content;
  final String folder;
  final bool pinned;
  final List<String> imagePaths;
  final DateTime updatedAt;

  String get imagePath => imagePaths.isEmpty ? '' : imagePaths.first;
}
