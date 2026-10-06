# Inkbook

A native, offline iPad notebook app starter built with SwiftUI, PencilKit, and PDFKit.

## Open and run

1. On a Mac with Xcode 15 or later, open `Inkbook.xcodeproj`.
2. Choose an iPad simulator or connected iPad.
3. Select the Inkbook target. For a physical iPad, set your own signing team and bundle identifier under Signing & Capabilities.
4. Build and run.

The deployment target is iPadOS 17. There are no third-party dependencies or accounts.

## Included

- Apple Pencil drawing with pen, pencil, marker, highlighter, vector eraser, and lasso
- Adjustable ink color and stroke width
- Undo, redo, ruler, and optional finger drawing
- Multiple notebooks and pages, with blank, lined, grid, and dotted templates
- PDF import as writable pages
- PDF export through the system share sheet
- Local autosave of notebooks and PencilKit drawings

## Current scope

This is a first usable version, not a full Goodnotes replacement. PDF exports flatten handwriting into the resulting PDF. Imported PDF pages remain in their original PDF file inside the app's local storage; editing the original PDF's text or annotations is not included. Cloud sync, handwriting recognition, audio notes, shapes, and collaboration are not implemented.

The project was generated in a Linux workspace. It has received a static file check, but must be compiled and tried in Xcode on a Mac and with an iPad or iPad simulator.
