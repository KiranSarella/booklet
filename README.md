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

![](/readme-screenshots/math.png)


## Gantt Chart

Add **Gantt Chart** to plan tasks with start/end dates, progress percentages, and dependencies. The full-screen editor has synchronized **Preview**, **Tasks**, and **Raw data** tabs, with date pickers, task ordering, and day/week/month timeline labels. End dates are inclusive. Choose **Standard Gantt** for scheduling or **Tracking Gantt** to compare the current schedule with baseline dates. In Tracking Gantt, use **Capture baseline** before adjusting current dates. Circular dependencies are rejected; scheduling conflicts are highlighted without moving task dates. Page and minimap previews remain read-only.

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