# Locaproof

Locaproof is an Android-first GPS camera for geo-tagged photos, project albums and PDF reports.

## Stack

- Flutter / Dart, Material 3
- GetX for state, dependency injection and navigation
- GetStorage for lightweight settings (a database arrives with projects/photos)

## Structure

```
lib/
  main.dart                 bootstrap: storage init, app-wide services, runApp
  app/                      app shell: GetMaterialApp, routes, initial binding, theme tokens
  core/                     cross-feature constants, services, extensions, utils, errors
  shared/widgets/           reusable UI (buttons, inputs, empty states, layout)
  features/<feature>/       bindings, controllers, views, widgets, models, services
```

Each feature registers its controller through its own binding in `app/routes/app_pages.dart`.
Widgets read colors from `ColorScheme` and spacing/radius from `app/theme/app_dimens.dart`.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
