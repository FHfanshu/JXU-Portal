# JXU-Portal

嘉兴大学校园门户, 由GPT5.4 | Claude-Opus-4.6 强力支援开发

一个把课表、成绩、校园卡、服务大厅什么的一堆东西放到同一个 App 里的 Flutter 项目。

## Quick Start

### 1. 准备环境

- Flutter 3.41.6
- Dart 3.11.4
- Java 17
- Android Studio / Android SDK

### 2. 获取代码

```bash
git clone https://github.com/FHfanshu/JXU-Portal.git
cd JXU-Portal
```

### 3. 安装依赖

```bash
flutter pub get
```

### 4. 运行 App

```bash
flutter run
```

## Build APK

```bash
flutter build apk --release
```

构建产物默认在 `build/app/outputs/flutter-apk/app-release.apk`。

## 项目结构

```text
lib/
  app/         # 应用入口、主题、路由
  core/        # 认证、网络、日志、学期能力
  features/    # 业务模块
  shared/      # 共享组件
assets/        # 静态资源
test/          # 测试
android/       # Android 工程脚手架
```

## 说明

- 本项目为个人开发项目，非学校官方应用
- 项目仅供学习与交流使用

## Contributors

- `FHfanshu`
- `3357264605@qq.com`
