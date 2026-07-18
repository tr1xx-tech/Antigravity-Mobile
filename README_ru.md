<div align="center">
  <h1>🚀 Antigravity 2.0 Mobile</h1>

  <p>
    <strong>Высокопроизводительный полноэкранный графический интерфейс для Google Antigravity 2.0 на Android.</strong>
  </p>

  <p>
    <a href="README_ru.md">🇷🇺 Читать на русском</a> | 
    <a href="README.md">🇬🇧 Read in English</a>
  </p>

  <p>
    <img alt="Version" src="https://img.shields.io/badge/version-1.0.0-blue.svg?cacheSeconds=2592000" />
    <img alt="Platform" src="https://img.shields.io/badge/platform-Termux%20X11-lightgrey" />
    <img alt="GPU" src="https://img.shields.io/badge/acceleration-Adreno%20%7C%20Mali-success" />
  </p>
</div>

---

## ⚡ Быстрая установка

**Требование:** Убедитесь, что у вас установлено Android-приложение [Termux-X11](https://github.com/termux/termux-x11/releases) для отрисовки интерфейса.

Скопируйте и вставьте следующую команду в терминал Termux, чтобы установить или обновить Antigravity Mobile:

```bash
curl -sL https://raw.githubusercontent.com/tr1xx-tech/Antigravity-Mobile/main/install.sh | bash
```

> **Примечание:** Скрипт автоматически определит ваше железо (Adreno/Mali) и установит необходимые драйверы GPU для максимальной производительности.

## 🌟 Особенности

* **Полноэкранный Kiosk-режим:** Полностью убирает рамки и декорации окон с помощью кастомной конфигурации Openbox для максимального погружения в код.
* **Автоопределение GPU:** Динамически скачивает и устанавливает драйверы `freedreno` или `panfrost` Vulkan в зависимости от процессора вашего Android-устройства.
* **Нативный обход VA39:** Включает кастомный бинарный патчер на Python, который бесшовно решает проблему 39-битных адресов памяти TCMalloc на Android без тяжелого оверхеда от ptrace.
* **Автоматические обновления:** Если языковой сервер Antigravity обновится, лаунчер (`gem`) автоматически обнаружит непропатченный бинарник и на лету переустановит патч VA39.
* **Редирект ссылок на хост:** Использует нативный IPC-мост через FIFO, чтобы окна авторизации (OAuth) и внешние ссылки открывались напрямую в системном браузере Android, а не внутри контейнера Debian.

## 🛠️ Использование

После установки просто запустите лаунчер из Termux:

```bash
gem
```

Для запуска с режимом отладки и полным выводом логов Electron:

```bash
gem --debug
```

## 🏗️ Архитектура

* **Хост:** Termux + Termux-X11 + драйверы Virgl/Zink Mesa
* **Контейнер:** Debian PRoot (proot-distro)
* **Оконный менеджер:** Openbox (минималистичный Kiosk-режим)
* **Приложение:** Google Antigravity 2.0 (Electron)

## 🤝 Вклад в проект

Будем рады вашим предложениям, баг-репортам и пулл-реквестам!

## 📜 Лицензия

Этот проект распространяется под лицензией MIT.
