import 'package:booklet/business/booklet_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookletAsset', () {
    test('classifies supported preview and document types', () {
      expect(
        const BookletAsset(
          id: '1',
          name: 'photo.JPG',
          path: 'a/photo.JPG',
        ).kind,
        BookletAssetKind.image,
      );
      expect(
        const BookletAsset(id: '2', name: 'clip.mp4', path: 'a/clip.mp4').kind,
        BookletAssetKind.video,
      );
      expect(
        const BookletAsset(
          id: '3',
          name: 'report.pdf',
          path: 'a/report.pdf',
        ).kind,
        BookletAssetKind.pdf,
      );
      expect(
        const BookletAsset(
          id: '4',
          name: 'notes.docx',
          path: 'a/notes.docx',
        ).kind,
        BookletAssetKind.document,
      );
      expect(
        const BookletAsset(
          id: '5',
          name: 'archive.zip',
          path: 'a/archive.zip',
        ).kind,
        BookletAssetKind.file,
      );
    });

    test('round-trips the asset metadata through JSON', () {
      const asset = BookletAsset(
        id: 'asset-1',
        name: 'photo.png',
        path: 'assets/folder-1/photo.png',
      );

      expect(BookletAsset.fromJson(asset.toJson()).toJson(), asset.toJson());
    });
  });
}
