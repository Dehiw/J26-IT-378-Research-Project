# Hive Sense — Frontend Skill Guide

**For all 4 members.** Build every screen using the shared palette, components,
and conventions below. This keeps the app visually consistent as if one
person built it. Do not invent new colors or styles — use what's here.

Read this file before writing any new screen or widget.

---

## 1. Project structure 

```
frontend/
  lib/
    main.dart                    → app entry (splash → onboarding → home)
    utils/theme.dart             → AppColors + AppTheme (THE palette — single source)
    services/inference_service.dart
    screens/
      onboarding_screen.dart
      home_screen.dart           → scanner home page
      <your_screen>.dart         → new pages go here
    widgets/
      hero_art.dart              → dark panel + gold ring + badges (onboarding hero)
      confidence_bar.dart        → animated per-class probability bar
      image_source_sheet.dart    → camera/gallery bottom sheet
      result_card.dart           → inference result card
      <your_widget>.dart         → shared widgets go here
  assets/models/                 → .onnx files + labels.json + ood_config.json
  test/widget_test.dart
```

Rules:
- **Screens** = full pages with their own `Scaffold`. Name them `*_screen.dart`.
- **Widgets** = small reusable pieces. Name them `snake_case.dart` exporting a
  `PascalCase` class.
- Import theme from `'../utils/theme.dart'` (screens) or `'../utils/theme.dart'`
  / `'../../utils/theme.dart'` (widgets) — never hardcode hex colors in screens.

---

## 2. Shared palette (use these, never raw hex)

All colors live in `AppColors` in `lib/utils/theme.dart`. Reference them like
`AppColors.accent`, `AppColors.textPrimary`, etc.

### Core
| Token | Value | Use for |
|---|---|---|
| `bgPrimary` | `#FFF8EA` | screen background (cream) |
| `bgSecondary` / `bgCard` | `#FFFFFF` | cards, sheets, input fills |
| `bgElevated` | `#FFF3DC` | disabled buttons, subtle fills |
| `border` | `#E4DCC8` | card borders, dividers |

### Text
| Token | Value | Use for |
|---|---|---|
| `textPrimary` | `#211D16` | headings, body |
| `textSecondary` | `#8B8378` | body copy, secondary |
| `textMuted` | `#D8D0BF` | hints, inactive |

### Accents & status
| Token | Value | Use for |
|---|---|---|
| `accent` | `#D8A93D` | primary button, links, active nav |
| `accent2` | `#B25A3C` | secondary accents, warnings-in-context |
| `accent3` | `#5F7F5A` | leaf / environment hints |
| `success` | `#4C8C4A` | healthy / good status |
| `warning` | `#C98A1B` | caution / watch status |
| `error` | `#B44436` | danger / disease status |
| `info` / `blue` | `#3A4A63` | neutral / informational |

### Onboarding hero art tokens
| Token | Value | Use for |
|---|---|---|
| `panelBlack` | `#0E0E0E` | dark hero panel background |
| `ring` | `#C99B3F` | thin gold ring around art |
| `hiveTop` `#EAC46C` / `hiveMid` `#D5A24A` / `hiveLow` `#B9862F` / `hiveDoor` `#2A1E10` | hive stack gradient |
| `badgeLeafBg`/`badgeLeafFg`, `badgeWaveBg`/`badgeWaveFg`, `badgeTempBg`/`badgeTempFg`, `badgeBeeBg`/`badgeBeeFg` | pastel floating sensor badges |

### Gradients
```dart
AppColors.accentGradient   // gold → deep gold, for hero icons / badges
AppColors.cardGradient     // white → pale cream, for result banner
```

**Forbidden:** never write `Color(0xFF...)`, `Colors.red`, etc. in screens or
widgets. Always use the token names so colors stay consistent.

---

## 3. Typography — use Google Fonts Inter

The theme already sets `GoogleFonts.inter` on the `TextTheme`. When you need a
style that isn't in the default text theme, write:

```dart
Text('Title', style: GoogleFonts.inter(
  fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
))
```

Weights used across the app: `w800` (headings/CTA), `w700` (titles/buttons),
`w600` (subheads), `w400`/`w500` (body). Keep text sizes consistent with the
existing screens — see `theme.dart` `textTheme` for the canonical sizes.

---

## 4. Shared components — use these before building your own

### `HeroArt` (`lib/widgets/hero_art.dart`)
Dark square hero panel with gold ring, layered hive illustration, and 4
floating pastel badges. Used at the top of onboarding pages.

```dart
HeroArt(variant: 0)   // 0 = hive stack, 1 = sound bars, 2 = forage pin
```

For your own pages, don't copy this wholesale — build a simpler header that
uses `AppColors.panelBlack` or `AppColors.accentGradient` instead.

### `ImageSourceSheet` (`lib/widgets/image_source_sheet.dart`)
Camera/gallery bottom sheet. Use it anywhere you need the user to pick a photo
for inference.

```dart
ImageSourceSheet.show(
  context,
  onCamera: _pickFromCamera,
  onGallery: _pickFromGallery,
);
```

### `ConfidenceBar` (`lib/widgets/confidence_bar.dart`)
Animated horizontal bar for one class probability. Already handles top-
prediction highlight + color. Feed it `label` + `confidence` (0–1).

### `ResultCard` (`lib/widgets/result_card.dart`)
Full inference result card: title + confidence + severity badge + description +
OOD row + per-class `ConfidenceBar`s. Pass a `PredictionResult`.

---

## 5. Footer / bottom navigation — keep it identical on every screen

All "main" screens (Home, Health, Detection, Environment — your four research
modules) share the same bottom nav. Copy this pattern exactly:

```dart
bottomNavigationBar: BottomNavigationBar(
  type: BottomNavigationBarType.fixed,
  backgroundColor: AppColors.bgPrimary,
  selectedItemColor: AppColors.hiveLow,
  unselectedItemColor: AppColors.textSecondary,
  showUnselectedLabels: true,
  currentIndex: 0, // change per screen
  onTap: (i) { /* navigate */ },
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'Health'),
    BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Detection'),
    BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Environment'),
  ],
)
```

Rules for the footer:
- `type: BottomNavigationBarType.fixed` — always, so icons stay evenly spaced.
- `selectedItemColor` uses `AppColors.hiveLow` (deep gold), not `accent`.
- Icons are `Outlined` variants (`_outlined`), labels in Inter via the theme.
- Keep the same 4 items in the same order — it's the app's main navigation.

Onboarding and splash do **not** have a footer (they're full-bleed flows).

---

## 6. Screen template — copy this when starting a new page

Every new screen should follow this skeleton. Replace only the marked parts.

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

class MyModuleScreen extends StatelessWidget {
  const MyModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Module Title',                        // ← your page title
          style: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // ← your content here
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),   // ← same nav on every main page
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.bgPrimary,
      selectedItemColor: AppColors.hiveLow,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      currentIndex: 0,
      onTap: (i) {/* navigate */},
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'Health'),
        BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Detection'),
        BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Environment'),
      ],
    );
  }
}
```

---

## 7. Code conventions everyone must follow

- **`AppColors` for every color** — no `Color(0x...)` or `Colors.*` in screens.
- **`GoogleFonts.inter` for every text style** — set `fontSize`, `fontWeight`,
  `color` per text; don't rely on raw `TextStyle`.
- **Use `withValues(alpha: x)`** not `withOpacity(x)` (deprecated in this SDK).
- **`const` constructors** on static widgets — improves performance.
- **`EdgeInsets.symmetric(horizontal: 20)`** for page side padding (24 in
  onboarding top bar; 20 inside the body).
- **Animate sparingly** — `.animate().fadeIn()`/`slideY` from
  `flutter_animate` is already available. Use `300–500ms`, subtle offsets.
- **No `print()`** — use `developer.log(msg, name: 'ComponentName')`.
- **Widget names** `PascalCase`, file names `snake_case`, classes match file
  names (`home_screen.dart` → `HomeScreen`).
- **Reusable pieces go in `lib/widgets/`**, full pages in `lib/screens/`.
- **Never duplicate** a widget that already exists — check `widgets/` first.

---

## 8. Dependencies already in `pubspec.yaml` — use them, don't add more

| Package | Already there | Use for |
|---|---|---|
| `google_fonts` | ✅ | All text styling |
| `flutter_animate` | ✅ | Fade/slide animations |
| `animate_do` | ✅ | Extra animated widgets |
| `image_picker` | ✅ | Camera/gallery picking |
| `camera` | ✅ | Direct camera access |
| `image` | ✅ | Image decode/resize for ONNX |
| `onnxruntime` | ✅ | On-device inference |
| `fl_chart` | ✅ | Sensor/metric charts |
| `percent_indicator` | ✅ | Progress rings/bars |
| `lottie` | ✅ | Loading / success animations |
| `intl` | ✅ | Date/time formatting |
| `shared_preferences` | ✅ | Persist settings/flags |
| `path_provider` | ✅ | File paths for saved data |

If you think you need a new package, ask the group first — adding packages
affects everyone's build.

---

## 9. Inference model contract (for the member doing the AI)

These files must be bundled in `assets/models/` (declared in pubspec):

| File | Purpose | Exported from |
|---|---|---|
| `hive_model.onnx` | Hive-health classifier (input `[1,3,224,224]`, ImageNet norm) | training notebook |
| `feature_extractor.onnx` | Penultimate-layer features (for OOD) | training notebook |
| `labels.json` | `{"classes": ["Healthy Colony","Stressed Colony","Disease Signs","Empty / Other"]}` | training notebook |
| `ood_config.json` | `{"ood_threshold": …, "class_means": […], "precision_matrix": […]}` | training notebook |

`InferenceService` loads all four at app start via `_AppLoader`. Missing
models = graceful demo mode (banner, no crash). `predict()` returns a
`PredictionResult` with `predictedClass`, `confidence`, `isOod`, `oodScore`,
`oodThreshold`, `classScores` — that's what `ResultCard` and the home screen
consume.

If you need a different input size or class list, update `InferenceService`
and `labels.json` together and tell the group.

---

## 10. Quick check before you commit a screen

- [ ] No hardcoded `Color(0x...)` — used `AppColors` everywhere?
- [ ] All text uses `GoogleFonts.inter` or the theme's `textTheme`?
- [ ] Bottom nav matches the shared items/order/colors exactly?
- [ ] `withValues(alpha:)` used instead of `withOpacity`?
- [ ] `const` on static widgets?
- [ ] New file in the right folder (`screens/` vs `widgets/`)?
- [ ] Reused an existing widget from `lib/widgets/` before building new?

When in doubt, copy `home_screen.dart` — it shows all the patterns above.

---Where each UI goes

frontend/lib/
  screens/          ← full pages go here
    onboarding_screen.dart    (exists)
    home_screen.dart          (exists)
    health_screen.dart        ← you/your teammates create these
    detection_screen.dart
    acoustic_screen.dart
    environment_screen.dart
  widgets/          ← reusable pieces go here
    hero_art.dart             (exists)
    result_card.dart          (exists)
    ...
    health_chart.dart         ← only if 2+ screens reuse it
