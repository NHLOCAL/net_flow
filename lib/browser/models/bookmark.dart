class Bookmark {
  const Bookmark({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      title: (json['title'] ?? json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }

  Map<String, String> toJson() {
    return <String, String>{
      'title': title,
      'url': url,
    };
  }
}
