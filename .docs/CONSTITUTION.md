# Project Constitution

## 1. Product Context & Overview
Booklet is a local-first, privacy-focused document editor built around component nodes.

The core features of this editor are:
1. Component based Document Editor: instead of plian/rich/markdown text editor, the editor is a scrollview with components (text, headings, block quote, image, codeblock, and custom components, etc). Where as each text component dont contain newline char.
2. Editor Styles Theme - user can change text color, fonts, backgrounds of the document editor and components.
3. Side Navigation view - as document contains multiple and nested pages and media folders, need to show them visualy in expandable list.
4. Custom components creation - user can create custom components in a composer and use them in document editor like default components.
5. Document Format - while pages, media, custom components are packed and saved as .booklet document format.


## Core Architectural Constraints

### Text Component & Data Model Rules
1. **Single-Line Component Invariant:** A text component (`Title`, `Subtitle`, `Heading`, `Subheading`, `InlineHeading`, `Body`, `ListItem`) MUST NEVER contain a newline character (`\n`).
2. **Line Break Behavior (`Enter` Key):**
   - Pressing `Enter` inside an active text component splits or terminates the component at the cursor position.
   - It MUST create a new text component immediately below the currently active component.
   - Any trailing text after the cursor moves to the newly created component.
3. **Backspace / Delete Behavior (`Backspace` Key):**
   - Pressing `Backspace` at position `0` of an empty component deletes the component and moves focus to the end of the previous component.
   - Pressing `Backspace` at position `0` of a non-empty component merges its content into the preceding component.
4. - Undo/Redu 
5. - Drag and drop

## Tech Stack
- Frontend/Desktop: Flutter + Dart
- State/Storage: json files
- Architecture: 
    /UI contains all UI + ViewModels
    /Application is orcestration between ViewModels and [Business/Services/Repo]
    /Repo provides logic for document data, themes, custom components, media 


## Ground Rules
1. Keep dependencies minimal. No third-party network calls.
2. Code style: Clean, modular, self-contained components.
3. Keep all data formatted as [e.g., plain Markdown / Local JSON].