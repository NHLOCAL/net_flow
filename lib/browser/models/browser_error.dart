enum BrowserErrorKind {
  load,
  netfreeBlocked,
  ssl,
  externalApp,
}

class BrowserError {
  const BrowserError({
    required this.url,
    required this.kind,
    required this.title,
    required this.message,
  });

  final String url;
  final BrowserErrorKind kind;
  final String title;
  final String message;

  factory BrowserError.fromHttpStatus({
    required String url,
    required int statusCode,
  }) {
    if (statusCode == 418) {
      return BrowserError(
        url: url,
        kind: BrowserErrorKind.netfreeBlocked,
        title: 'האתר נחסם או דורש בדיקה בנטפרי',
        message:
            'נטפרי החזיר קוד 418. ניתן לרענן, להעתיק את הכתובת או לפתוח אותה בדפדפן חיצוני.',
      );
    }

    return BrowserError(
      url: url,
      kind: BrowserErrorKind.load,
      title: 'הדף לא נטען',
      message: 'השרת החזיר שגיאה $statusCode.',
    );
  }

  factory BrowserError.fromWebViewDescription({
    required String url,
    required String description,
  }) {
    final lower = description.toLowerCase();
    if (lower.contains('ssl') ||
        lower.contains('certificate') ||
        lower.contains('cert')) {
      return BrowserError(
        url: url,
        kind: BrowserErrorKind.ssl,
        title: 'בעיה בתעודת האבטחה',
        message:
            'ייתכן שחסרה תעודת נטפרי או שקיימת בעיית SSL באתר. בדוק את התקנת התעודה ונסה שוב.',
      );
    }

    return BrowserError(
      url: url,
      kind: BrowserErrorKind.load,
      title: 'הטעינה נכשלה',
      message: description,
    );
  }

  factory BrowserError.externalApp({
    required String url,
  }) {
    return BrowserError(
      url: url,
      kind: BrowserErrorKind.externalApp,
      title: 'לא נמצאה אפליקציה מתאימה',
      message: 'אין אפליקציה במכשיר שיכולה לפתוח את הקישור הזה.',
    );
  }
}
