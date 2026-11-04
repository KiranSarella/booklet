# Booklet Features


# Android tablet reader (initial implementation)

Android uses a separate read-only reader shell. It includes page navigation,
page search, booklet-wide search, table of contents, page themes, document
appearance, font size controls, and document information. Navigation opens as a
drawer on compact and portrait layouts; wide landscape windows can pin it beside
the page. Desktop continues to use the editor shell.

Run on a connected Android tablet or emulator:

```sh
flutter devices
flutter run -d <android-device-id>
```

Choose **Open booklet** and select a `.booklet` document. Android opens the
same single file saved by the desktop application, in read-only mode.

## Portable document format

Save and autosave write a single `.booklet` file on macOS and Linux. The file is
a ZIP container holding the manifest, pages, media, attachments, metadata,
snapshots and deleted items. Packing and unpacking run off the UI thread.
A private directory is used internally while editing; users transfer only the
`.booklet` file. Saves build a complete temporary archive before replacing the
last saved document.

Existing directory-based packages can still be opened using **Open older folder package…**. An explicit **Save**
converts the package to a single file and retains the original directory beside
it with a `.legacy-…` suffix. **Save As** creates a portable file at the chosen
location without replacing the old package. No manual compression or export is
needed. Copies of the older ZIP transfer format can also be read.

Tablet validation should cover portrait/landscape, split-screen, large fonts,
wide content, local media, both cold and warm file opens, and cancelled/invalid
selections. iPad integration is not enabled yet; the reader widgets can be reused
for it.

# Document imports

Document settings → Import from supports Markdown, HTML, PDF, EPUB, DOCX, and TXT.

EPUB imports unencrypted books in reading order, with a page per chapter in a book group. Headings, basic text formatting, links, and embedded images remain editable. Single-chapter books become one page. Maximum EPUB size: 50 MB; expanded content: 200 MB. DRM-protected books and exact publisher layouts are not supported.

DOCX imports Word documents into a new editable page with headings, basic bold/italic/underline/strike formatting, lists, hyperlinks, and embedded PNG/JPEG/GIF/WebP/BMP images. Table-cell text imports in reading order; table grids, floating layouts, equations, headers/footers, and exact Word styling are not reconstructed. Convert legacy `.doc` and encrypted files to unencrypted `.docx` first. Maximum size: 50 MB; expanded content: 200 MB.

TXT imports plain text into a new editable page, preserving paragraphs, line breaks, and indentation. Supports UTF-8 and UTF-16 with a byte-order mark. The filename becomes the page title. Maximum size: 10 MB.

HTML accepts a website URL or local file. Wikipedia articles receive article-content cleanup, preserving headings, basic formatting, links, images, and captions while removing edit controls and navigation boxes. Tables, infobox layouts, equations, and complex styling may need manual adjustment. Web images remain linked to their source; pages requiring JavaScript or sign-in may not import.
