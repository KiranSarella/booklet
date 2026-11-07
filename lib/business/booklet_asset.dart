import 'package:booklet/ui/components/media/online_video.dart';

enum BookletAssetKind { image, video, pdf, document, file }

class BookletAsset {
  const BookletAsset({
    required this.id,
    required this.name,
    required this.path,
    this.thumbnailPath,
    this.embedCode,
  });

  final String id;
  final String name;
  final String path;
  final String? thumbnailPath;
  final String? embedCode;

  bool get isRemote {
    final uri = Uri.tryParse(path);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String get extension {
    final dotIndex = name.lastIndexOf('.');
    return dotIndex < 0 ? '' : name.substring(dotIndex + 1).toLowerCase();
  }

  BookletAssetKind get kind {
    final provider = OnlineVideo.parse(path)?.provider;
    if (provider == OnlineVideoProvider.youtube ||
        provider == OnlineVideoProvider.instagram) {
      return BookletAssetKind.video;
    }
    if (const {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'heic',
    }.contains(extension)) {
      return BookletAssetKind.image;
    }
    if (const {'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'}.contains(extension)) {
      return BookletAssetKind.video;
    }
    if (extension == 'pdf') {
      return BookletAssetKind.pdf;
    }
    if (const {
      'doc',
      'docx',
      'odt',
      'rtf',
      'txt',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'pages',
      'numbers',
      'key',
    }.contains(extension)) {
      return BookletAssetKind.document;
    }
    return BookletAssetKind.file;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
    if (embedCode != null) 'embedCode': embedCode,
  };

  static BookletAsset fromJson(Map<String, dynamic> json) => BookletAsset(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Untitled file',
    path: json['path'] as String? ?? '',
    thumbnailPath: json['thumbnailPath'] as String?,
    embedCode: json['embedCode'] as String?,
  );
}
