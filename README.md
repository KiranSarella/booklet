# .booklet

A free and open-source, component-based document application for education.

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

Version: 0.1

# Supported Platforms
Used flutter to make it platform independent.

**write mode**
- [X] mac desktop
- [X] linux desktop
- [ ] windows desktop

**read-only mode**
- [ ] android tablets, mobiles
- [ ] iOS tablets, mobiles
- [ ] web (published from desktop app)

# Screenshots

![](/readme-screenshots/preview.png)

![](/readme-screenshots/table.png)

![](/readme-screenshots/drawing.png)

![](/readme-screenshots/statistical-chart.png)


## Math Graph

Add **Math Graph** to plot equations such as `2x + 1`, `x^2`, `exp(x)`, `ln(x)`, and `sin(x)`. The page and minimap show a read-only graph; open the full-screen editor to edit multiple equations, axis ranges, and radians/degrees. The **Preview**, **Equations**, and **Raw data** tabs share the same draft. Save applies changes; closing the editor leaves the saved graph unchanged.

Supported notation includes `+`, `-`, `*`, `/`, `^`, parentheses, implicit multiplication (`2x`), constants `pi` and `e`, and the functions listed in the editor. Graphs currently plot two-dimensional functions of the form `y = f(x)`.

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