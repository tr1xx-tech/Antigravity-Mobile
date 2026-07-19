<div align="center">
  <h1>🚀 Antigravity 2.0 Mobile</h1>

  <p>
    <strong>A high-performance, native-patched, full-screen GUI for Google Antigravity 2.0 on Android.</strong>
  </p>

  <p>
    <a href="README_ru.md">🇷🇺 Русский</a> | 
    <strong>🇬🇧 English</strong>
  </p>

  <p>
    <img alt="Version" src="https://img.shields.io/badge/version-1.0.0-blue.svg?cacheSeconds=2592000" />
    <img alt="Platform" src="https://img.shields.io/badge/platform-Termux%20X11-lightgrey" />
    <img alt="GPU" src="https://img.shields.io/badge/acceleration-Adreno%20%7C%20Mali-success" />
  </p>
</div>

---

## ⚡ Quick Install

**Prerequisite:** Ensure you have the [Termux-X11 Android APK](https://github.com/termux/termux-x11/releases) installed on your device.

Copy and paste the following command into your Termux terminal to install or update Antigravity Mobile:

```bash
curl -sL https://raw.githubusercontent.com/tr1xx-tech/Antigravity-Mobile/main/install.sh | bash
```

> **Note:** The script will automatically detect your hardware (Adreno/Mali) and install the appropriate GPU drivers for maximum performance.

## 🌟 Features

* **Full-Screen Kiosk Mode:** Strips away all window borders and decorations using the Matchbox Window Manager for a clean, immersive coding experience.
* **Auto-Detect GPU Drivers:** Dynamically fetches and installs `freedreno` or `panfrost` Vulkan drivers depending on your Android device's SoC.
* **Native VA39 Bypass:** Includes a custom Python binary patcher that seamlessly resolves the TCMalloc 39-bit memory address limitations on Android without heavy ptrace overhead.
* **Self-Healing Updates:** If the Antigravity language server updates itself, the custom launcher (`gem`) automatically detects the unpatched binary and re-applies the VA39 bypass on the fly.
* **Host URL Forwarding:** Uses a native FIFO IPC bridge so OAuth logins and external links open directly in your Android system browser, not inside the Debian container.

## 🛠️ Usage

After installation, simply run the launcher from Termux:

```bash
gem
```

To run with verbose Electron stack dumping and debugging enabled:

```bash
gem --debug
```

## 🏗️ Architecture

* **Host:** Termux + Termux-X11 + Virgl/Zink Mesa Drivers
* **Container:** Debian PRoot (proot-distro)
* **Window Manager:** Matchbox Window Manager (Native Kiosk Mode)
* **Application:** Google Antigravity 2.0 (Electron)

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## 📜 License

This project is licensed under the MIT License.
