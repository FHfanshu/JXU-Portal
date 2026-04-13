# JXU-Portal (Open Source UI)

嘉兴大学校园门户 App UI 开源部分。

这是一个 Flutter 项目的 UI 层开源代码，展示了应用的用户界面设计和组件结构。

**注意：本仓库仅包含 UI 界面代码，不包含以下敏感/核心功能：**

- 统一身份认证逻辑
- 教务系统登录与数据获取
- 校园卡支付相关功能
- 爬虫/数据抓取逻辑
- API 密钥和加密配置

## 项目结构

```text
lib/
  app/         # 应用入口、主题、路由
  core/        # Stub 实现（认证、网络等）
  features/    # UI 页面和组件
    campus_card/       # 校园卡页面 UI
    changxing_jiada/   # 畅行嘉大页面 UI
    dorm_electricity/  # 宿舍电费页面 UI
    grades/            # 成绩页面 UI
    home/              # 首页 UI
    my/                # 个人中心 UI
    notice/            # 通知公告页面 UI
    schedule/          # 课表页面 UI
    settings/          # 设置页面 UI
  shared/      # 共享 UI 组件
assets/        # 静态资源
test/          # 测试
android/       # Android 工程脚手架
```

## 技术栈

- Flutter 3.41.6
- Dart 3.11.4
- Material Design 3

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

注意：由于核心功能以 stub 实现，运行后大部分功能页面将显示"未实现"提示。

## 说明

- 本项目为个人开发项目，非学校官方应用
- 项目仅供学习与交流使用
- 开源部分仅展示 UI 设计，不涉及任何学校内部系统

## 致谢

- Claude Code
- OpenCode