---
name: flutter-coding-guidelines
description: Core Flutter coding guidelines for this project, covering Riverpod, Drift, and architecture.
---

# Flutter Coding Guidelines

Use this skill whenever you write or modify Flutter/Dart code in this project.

## Architecture & State Management
- **Riverpod**: Use `flutter_riverpod` for all state management. Use `Notifier` and `AsyncNotifier` (with code generation if applicable, or manual providers).
- **Separation of Concerns**: Keep business logic in Notifiers/Services, away from UI files.
- **Dependency Injection**: Use Riverpod's `ref.read` and `ref.watch` for accessing dependencies.

## UI & Styling
- **Material 3**: Use Material 3 widgets and conventions.
- **Theme Extensions**: Use custom theme extensions for project-specific colors and text styles.
- **Responsive Design**: Ensure UI scales gracefully across different screen sizes.

## Database (Drift)
- Use **Drift** for local SQLite storage.
- Keep database queries in DAO (Data Access Object) classes or repositories.
- Use `Stream` queries for reactive UI updates from the database.

## Background Services
- When dealing with background services (like location tracking), ensure clear separation between the UI isolate and the background isolate.
- Use platform channels or `flutter_background_service` invoke methods for IPC (Inter-Process Communication).
