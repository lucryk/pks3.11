class Note {
  final int id;
  final String title;
  final String body;
  final int userId;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? json['content'] ?? '',
      userId: json['userId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'userId': userId,
    };
  }

  @override
  String toString() {
    return 'Note{id: $id, title: $title, body: $body, userId: $userId}';
  }
}