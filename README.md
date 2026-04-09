# JXU-Portal

[![Flutter](https://img.shields.io/badge/Flutter-3.41.6-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

嘉兴大学校园门户开源版，提供课表、成绩、校园卡、服务大厅等校园服务入口。

## 开发环境

- Flutter 3.41.6
- Dart 3.11.4
- Java 17

## 本地运行

```bash
flutter pub get
flutter run
```

## 构建 Release APK

```bash
flutter build apk --release
```

## 自动化流程

- `sync-from-private.yml`: 定时或手动从私有源仓库同步 `lib/`、`assets/`、`test/`、`pubspec.*`、`analysis_options.yaml`
- `android-ci.yml`: 在 push / pull request 时执行 `flutter analyze`、`flutter test` 并构建 release APK artifact
- `release.yml`: 在推送 `v*` 标签时构建并发布 release APK

## 同步边界

- Android 等 Flutter 脚手架文件由本公开仓库自行维护，不会被同步流程覆盖
- 业务 Dart 代码与相关资源文件从私有源仓库拉取

## 免责声明

本项目为嘉兴大学学生个人开发项目，非学校官方应用。仅供学习交流使用。
