# 梦蝶 (Meng-Die)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**English** | [**简体中文**](#简体中文)

## Introduction

Meng-Die is a cross-platform Flutter application designed as a versatile client for interacting with various Large Language Models (LLMs), such as Google Gemini and OpenAI's models. It provides a user-friendly interface for managing conversations, API configurations, and exploring the capabilities of different AI models locally.

## What it does?

*   **Multi-LLM Interaction:** Connects to and interacts with multiple LLM services (currently supports Google Gemini and OpenAI).
*   **Chat Management:** Allows users to create, manage, and persist multiple chat sessions locally using Drift (SQLite).
*   **API Key Management:** Securely stores and manages API keys for different LLM services.
*   **Configuration:** Provides settings for customizing model parameters (e.g., temperature, context) and application behavior (e.g., themes).
*   **Cross-Platform:** Built with Flutter, aiming to run on iOS, Android, Web, Windows, macOS, and Linux.

## What problem does it solve?

*   **Unified Interface:** Offers a single application to interact with various LLMs, eliminating the need to switch between different platforms or tools.
*   **Local Data Persistence:** Keeps chat history and configurations stored locally, giving users control over their data.
*   **Simplified Configuration:** Streamlines the process of managing API keys and model settings for different services.
*   **Experimentation Platform:** Provides a convenient environment for developers and enthusiasts to experiment with different LLMs and their features.

## Key Features

*   Support for Google Gemini and OpenAI models.
*   Local chat history storage using Drift (SQLite).
*   Multiple chat session management.
*   Secure API key storage (using SharedPreferences or more secure methods if implemented).
*   Theme customization (Light, Dark, System).
*   Configuration options for LLM generation parameters.
*   Potential for chat import/export functionality (based on `chat_export_import_service.dart`).
*   Context management features (based on `context_xml_service.dart`).

## How to use?

1.  **Prerequisites:**
    *   Flutter SDK (version 3.x recommended) installed.
    *   Dart SDK (version 3.x recommended) installed.
    *   IDE (like VS Code or Android Studio) with Flutter plugins.
2.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd Meng-Die
    ```
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Configure API Keys:**
    *   Navigate to the API Key management screen within the application (e.g., Gemini API Keys, OpenAI API Configs).
    *   Enter your API keys obtained from the respective LLM providers.
5.  **Run the application:**
    ```bash
    flutter run # Select your target device/emulator
    ```
6.  **Start Chatting:** Create a new chat session and start interacting with the selected LLM.

*(Note: Specific build steps for different platforms like web or desktop might require additional configuration, e.g., enabling platform support via `flutter config`.)*

## Tech Stack

*   **Framework:** Flutter
*   **Language:** Dart
*   **State Management:** Riverpod
*   **Routing:** go_router
*   **Local Database:** Drift (SQLite wrapper)
*   **HTTP Client:** (Likely `http` or `dio`, check `pubspec.yaml`)
*   **LLM SDKs/APIs:** Google AI Dart SDK, OpenAI API (direct calls or via a Dart package)

## Scope

This application is suitable for:

*   Personal use for interacting with LLMs.
*   Developers experimenting with different AI models.
*   Learning and demonstrating Flutter application architecture with LLM integration.

## Target Audience

*   Flutter Developers
*   AI Enthusiasts
*   Users who want a unified interface for multiple LLMs.
*   Individuals concerned with local data storage for chat history.

---

## 简体中文

## 简介

梦蝶 (Meng-Die) 是一个跨平台的 Flutter 应用，旨在作为与各种大型语言模型 (LLM)（例如 Google Gemini 和 OpenAI 模型）交互的通用客户端。它提供了一个用户友好的界面，用于管理对话、API 配置以及在本地探索不同 AI 模型的功能。

## 用途

*   **多 LLM 交互:** 连接并与多个 LLM 服务进行交互（当前支持 Google Gemini 和 OpenAI）。
*   **聊天管理:** 允许用户使用 Drift (SQLite) 在本地创建、管理和持久化多个聊天会话。
*   **API 密钥管理:** 安全地存储和管理不同 LLM 服务的 API 密钥。
*   **配置:** 提供用于自定义模型参数（例如，温度、上下文）和应用程序行为（例如，主题）的设置。
*   **跨平台:** 使用 Flutter 构建，旨在运行于 iOS、Android、Web、Windows、macOS 和 Linux。

## 解决什么问题？

*   **统一界面:** 提供单个应用程序来与各种 LLM 交互，无需在不同平台或工具之间切换。
*   **本地数据持久化:** 将聊天记录和配置存储在本地，让用户可以控制自己的数据。
*   **简化配置:** 简化了管理不同服务的 API 密钥和模型设置的过程。
*   **实验平台:** 为开发者和爱好者提供了一个方便的环境来试验不同的 LLM 及其特性。

## 主要特性

*   支持 Google Gemini 和 OpenAI 模型。
*   使用 Drift (SQLite) 进行本地聊天记录存储。
*   多聊天会话管理。
*   安全的 API 密钥存储（使用 SharedPreferences 或其他已实现的安全方法）。
*   主题定制（浅色、深色、跟随系统）。
*   LLM 生成参数的配置选项。
*   潜在的聊天导入/导出功能（基于 [`chat_export_import_service.dart`](lib/services/chat_export_import_service.dart)）。
*   上下文管理功能（基于 [`context_xml_service.dart`](lib/services/context_xml_service.dart)）。

## 如何使用？

1.  **先决条件:**
    *   安装 Flutter SDK (推荐 3.x 版本)。
    *   安装 Dart SDK (推荐 3.x 版本)。
    *   安装 IDE (如 VS Code 或 Android Studio) 并配置 Flutter 插件。
2.  **克隆仓库:**
    ```bash
    git clone <仓库地址>
    cd Meng-Die
    ```
3.  **安装依赖:**
    ```bash
    flutter pub get
    ```
4.  **配置 API 密钥:**
    *   在应用程序内导航到 API 密钥管理屏幕（例如，Gemini API Keys, OpenAI API Configs）。
    *   输入从相应 LLM 提供商获取的 API 密钥。
5.  **运行应用:**
    ```bash
    flutter run # 选择你的目标设备/模拟器
    ```
6.  **开始聊天:** 创建一个新的聊天会话，并开始与选定的 LLM 互动。

*（注意：针对不同平台（如 Web 或桌面）的特定构建步骤可能需要额外的配置，例如通过 `flutter config` 启用平台支持。）*

## 技术栈

*   **框架:** Flutter
*   **语言:** Dart
*   **状态管理:** Riverpod
*   **路由:** go_router
*   **本地数据库:** Drift (SQLite 封装)
*   **HTTP 客户端:** (可能是 `http` 或 `dio`，请检查 [`pubspec.yaml`](pubspec.yaml))
*   **LLM SDK/API:** Google AI Dart SDK, OpenAI API (直接调用或通过 Dart 包)

## 适用范围

此应用程序适用于：

*   个人与 LLM 交互使用。
*   开发者试验不同的 AI 模型。
*   学习和演示集成了 LLM 的 Flutter 应用架构。

## 适用人群

*   Flutter 开发者
*   AI 爱好者
*   希望为多个 LLM 提供统一界面的用户。
*   关注聊天记录本地存储的个人。