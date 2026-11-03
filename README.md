# .booklet

A free and open-source, component-based document application for education.

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

Version: 0.1

# Supported Platforms
Used flutter to make it platform independent.

Contributions are welcome.

**write mode**
- [X] linux desktop
- [X] mac desktop
- [ ] windows desktop

**read-only mode**
- [ ] android tablets, mobiles
- [ ] iOS tablets, mobiles
- [ ] web (published from desktop app)

# Document imports

Document settings → Import from supports Markdown, HTML, PDF, EPUB, DOCX, and TXT.

EPUB imports unencrypted books in reading order, with a page per chapter in a book group. Headings, basic text formatting, links, and embedded images remain editable. Single-chapter books become one page. Maximum EPUB size: 50 MB; expanded content: 200 MB. DRM-protected books and exact publisher layouts are not supported.

DOCX imports Word documents into a new editable page with headings, basic bold/italic/underline/strike formatting, lists, hyperlinks, and embedded PNG/JPEG/GIF/WebP/BMP images. Table-cell text imports in reading order; table grids, floating layouts, equations, headers/footers, and exact Word styling are not reconstructed. Convert legacy `.doc` and encrypted files to unencrypted `.docx` first. Maximum size: 50 MB; expanded content: 200 MB.

TXT imports plain text into a new editable page, preserving paragraphs, line breaks, and indentation. Supports UTF-8 and UTF-16 with a byte-order mark. The filename becomes the page title. Maximum size: 10 MB.

HTML accepts a website URL or local file. Wikipedia articles receive article-content cleanup, preserving headings, basic formatting, links, images, and captions while removing edit controls and navigation boxes. Tables, infobox layouts, equations, and complex styling may need manual adjustment. Web images remain linked to their source; pages requiring JavaScript or sign-in may not import.

# Screenshots

![](/readme-screenshots/preview.png)

![](/readme-screenshots/table.png)

![](/readme-screenshots/drawing.png)

![](/readme-screenshots/statistical-chart.png)

![](/readme-screenshots/math.png)



# Flutter

```
flutter run -d macos
flutter run -d chrome

flutter build macos


flutter clean
flutter pub get
flutter build macos --release

```

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3) - see the [LICENSE](LICENSE) file for details.