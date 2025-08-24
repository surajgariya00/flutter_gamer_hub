# Flutter Gamer Hub

A modern, gamer-themed **Flutter web arcade** where you can list **all the games you create**, and **save each game's progress locally** using **Hive** (works on web via IndexedDB).

https://img.shields.io/badge/Flutter-Web-blue
https://img.shields.io/badge/Storage-Hive-success

## ✨ Features

- Neon, modern gamer UI
- Game library grid with search
- Sample games included:
  - **Tic-Tac-Toe** (saves board, turn, and scores)
  - **Memory Match** (saves deck seed, matched cards, moves)
- **Hive**-powered local progress per game
- Easy API for adding your own games

## 🚀 Getting Started

### Prereqs

- [Install Flutter](https://docs.flutter.dev/get-started/install)

### Run locally

```bash
flutter pub get
flutter run -d chrome
```

### Build for the web

```bash
flutter build web
```

This will output to `build/web`.

## 🌐 Host on GitHub Pages

Two easy ways:

### A) Use `docs/` folder on `main` branch

```bash
# From project root
flutter build web
rm -rf docs
mkdir docs
cp -R build/web/* docs/

git init
git add .
git commit -m "Initial commit: Flutter Gamer Hub"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

Then in your repo settings → **Pages**, set:

- **Source**: `Deploy from a branch`
- **Branch**: `main` → `/docs`
  Save. Your site will be live at `https://<user>.github.io/<repo>/`.

### B) Use a `gh-pages` branch

```bash
flutter build web
git init
git add .
git commit -m "project sources"
git branch -M main
git remote add origin https://github.com/<user>/<repo>.git
git push -u origin main

# Deploy build output
git subtree push --prefix build/web origin gh-pages
```

Then set Pages to use the **gh-pages** branch (root).

## 🧠 Add Your Own Game

1. Create a file like `lib/games/my_game.dart`.
2. Build your widget screen.
3. Persist progress:

```dart
final data = ProgressService.read('mygame'); // returns dynamic (Map/List/primitive) or null
await ProgressService.write('mygame', {
  'level': 2,
  'score': 9001,
});
```

4. Register in `lib/main.dart`:

```dart
GameDefinition(
  id: 'mygame',
  name: 'My Game',
  description: 'Short pitch here.',
  icon: Icons.sports_esports,
  build: (ctx) => const MyGameScreen(),
),
```

> Tip: Keep progress values to **primitives, lists, and maps** to avoid type adapters on web.

## 📦 Structure

```
lib/
  games/
    memory_match.dart
    tictactoe.dart
  models/
    game.dart
  services/
    progress_service.dart
  widgets/
    game_card.dart
  main.dart
  theme.dart
web/
  index.html
  icons/Icon-192.png
pubspec.yaml
```

## 🛠️ Customize Theme

See `lib/theme.dart` for the neon gradient, colors, and Material 3 setup.

## ⚠️ Notes

- On web, Hive uses **IndexedDB**—progress is per-browser.
- Clearing site data will remove saves.
- If you plan mobile targets, add `path_provider` and Hive directory setup for iOS/Android.

Enjoy building your arcade! 🎮
