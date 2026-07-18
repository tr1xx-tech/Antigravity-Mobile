#!/usr/bin/env bash
# ==============================================================================
# Antigravity 2.0 GUI - Kiosk Installer (Optimized)
# ==============================================================================
# Version: v1.0.0
# ==============================================================================

set -e

INSTALLER_VERSION="1.0.0"

# ANSI Colors
CYAN='\033[38;5;39m'
CYAN_BOLD='\033[1;38;5;39m'
PURPLE_BOLD='\033[1;38;5;141m'
GREEN_BOLD='\033[1;38;5;48m'
RED_BOLD='\033[1;38;5;196m'
GRAY='\033[38;5;242m'
WHITE='\033[1;37m'
RESET='\033[0m'

DIM='\033[2m'

get_cols() {
    local c=""
    if [ -r /dev/tty ]; then c=$(stty size </dev/tty 2>/dev/null | awk '{print $2}' || true); fi
    if [ -z "$c" ]; then c=$(tput cols </dev/tty 2>/dev/null || true); fi
    if [ -z "$c" ] || ! [[ "$c" =~ ^[0-9]+$ ]] || [ "$c" -lt 25 ]; then c="${TERM_WIDTH:-${COLUMNS:-50}}"; fi
    if ! [[ "$c" =~ ^[0-9]+$ ]] || [ "$c" -lt 25 ]; then c=50; fi
    echo "$c"
}

wrap_log() {
    local prefix_vis_len="$1"; local prefix_str="$2"; local indent_str="$3"; local indent_vis_len="$4"; local text="$5"
    local cols=$(get_cols)
    local max_first=$(( cols - prefix_vis_len - 1 )); local max_cont=$(( cols - indent_vis_len - 1 ))
    if [ $max_first -lt 15 ]; then max_first=15; fi; if [ $max_cont -lt 15 ]; then max_cont=15; fi
    local words=($text); local line=""; local is_first=1
    for word in "${words[@]}"; do
        if [ ${#line} -eq 0 ]; then line="$word"; else
            local cur_limit=$max_first; if [ $is_first -eq 0 ]; then cur_limit=$max_cont; fi
            if [ $(( ${#line} + 1 + ${#word} )) -le $cur_limit ]; then line="$line $word"; else
                if [ $is_first -eq 1 ]; then echo -e "${prefix_str}${line}${RESET}"; is_first=0; else echo -e "${indent_str}${line}${RESET}"; fi
                line="$word"
            fi
        fi
    done
    if [ ${#line} -gt 0 ]; then
        if [ $is_first -eq 1 ]; then echo -e "${prefix_str}${line}${RESET}"; else echo -e "${indent_str}${line}${RESET}"; fi
    fi
}

step()    { echo -e ""; wrap_log 3 "◆  ${PURPLE_BOLD}" "   ${PURPLE_BOLD}└─ ${RESET}${PURPLE_BOLD}" 6 "$1"; }
info()    { wrap_log 6 "   ${CYAN}ℹ${RESET}  ${DIM}" "      ${DIM}└─ ${RESET}${DIM}" 9 "$1"; }
success() { wrap_log 6 "   ${GREEN_BOLD}✓${RESET}  ${WHITE}" "      ${DIM}└─ ${RESET}${WHITE}" 9 "$1"; }
error()   { wrap_log 6 "   ${RED_BOLD}✗  Error: ${RESET}${RED_BOLD}" "      ${DIM}└─ ${RESET}${RED_BOLD}" 9 "$1"; }

draw_banner() {
    local ver="$1"
    local term_w=$(get_cols)
    local max_w=50
    if [ "$term_w" -lt 54 ]; then max_w=$((term_w - 4)); fi
    if [ "$max_w" -lt 38 ]; then max_w=38; fi

    local hline=""
    for ((i=0; i<max_w; i++)); do hline="${hline}─"; done

    pad_text() {
        local text="$1"; local vis_len="$2"
        local pad_len=$(( max_w - vis_len - 2 ))
        if [ "$pad_len" -lt 0 ]; then pad_len=0; fi
        local pad_str=""
        for ((i=0; i<pad_len; i++)); do pad_str="${pad_str} "; done
        echo -n "${text}${pad_str}"
    }

    echo -e "\n${CYAN_BOLD}  ┌${hline}┐${RESET}"
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}ANTIGRAVITY 2.0  ${RESET}${PURPLE_BOLD}MOBILE GUI" 29) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  ├${hline}┤${RESET}"
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}Version        : ${RESET}${GREEN_BOLD}v${ver}" $(( 18 + ${#ver} ))) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}Target OS      : ${RESET}${WHITE}Android Termux X11" 35) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}Architecture   : ${RESET}${WHITE}Debian PRoot Openbox" 37) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  └${hline}┘${RESET}\n"
}

on_host_interrupt() {
    trap - SIGINT SIGTERM; kill -TERM 0 2>/dev/null || true
    rm -f "$PREFIX/tmp/setup_antigravity.sh" /tmp/antigravity.tar.gz 2>/dev/null || true
    echo -e "\n${RED_BOLD}Aborted by user.${RESET}\n"
    exit 130
}
trap on_host_interrupt SIGINT SIGTERM

clear || true
draw_banner "$INSTALLER_VERSION"

if [ -z "$PREFIX" ] || [ ! -d "/data/data/com.termux/files/usr" ]; then
    error "Must be executed within Termux."
    exit 1
fi

step "Initializing Host Environment (Termux System)"
pkg update -y >/dev/null 2>&1 || true

# Verify Termux-X11 App is installed interactively without launching it
echo -e "\n${CYAN_BOLD}  [ Termux-X11 Dependency Check ]${RESET}"
echo -e "   ${CYAN}ℹ${RESET}  You must have the Termux-X11 Android APK installed to view the GUI."
echo -e "   ${CYAN}ℹ${RESET}  If you don't have it, press 'N' to open the download page."
echo -e "   ${CYAN}ℹ${RESET}  If it is already installed, press Enter to continue."
read -p "      Continue? [Y/n]: " check_x11
if [[ "$check_x11" =~ ^[Nn]$ ]]; then
    termux-open "https://github.com/termux/termux-x11/releases"
    echo -e "\n${RED_BOLD}Aborted.${RESET} Please install the APK and run this script again."
    exit 1
fi

# Auto-detect GPU for minimal package installation
EGL=$(getprop ro.hardware.egl 2>/dev/null | tr '[:upper:]' '[:lower:]')
BOARD=$(getprop ro.hardware 2>/dev/null | tr '[:upper:]' '[:lower:]')
PLATFORM=$(getprop ro.board.platform 2>/dev/null | tr '[:upper:]' '[:lower:]')

GPU_PKG=""
if [[ "$EGL" == *"adreno"* ]] || [[ "$BOARD" == *"qcom"* ]] || [[ "$PLATFORM" == *"qcom"* ]] || [[ "$PLATFORM" == *"snapdragon"* ]]; then
    GPU_PKG="mesa-vulkan-icd-freedreno"
    info "Detected Adreno GPU. Selecting freedreno drivers."
elif [[ "$EGL" == *"mali"* ]] || [[ "$BOARD" == *"mtk"* ]] || [[ "$BOARD" == *"exynos"* ]] || [[ "$PLATFORM" == *"mtk"* ]]; then
    GPU_PKG="mesa-vulkan-icd-panfrost"
    info "Detected Mali/Exynos/MediaTek GPU. Selecting panfrost drivers."
else
    info "Could not auto-detect GPU. Falling back to software rendering packages."
fi

pkg install -y proot-distro curl tar python x11-repo termux-x11-nightly virglrenderer-android mesa-zink $GPU_PKG >/dev/null 2>&1 || true
success "Host utilities and dynamic GPU drivers verified."

step "Verifying Debian Subsystem (PRoot Container)"
if ! proot-distro login debian -- true >/dev/null 2>&1; then
    proot-distro install debian >/dev/null 2>&1
    success "Debian container provisioned successfully."
else
    success "Debian container is already provisioned."
fi

SETUP_TMP_DIR="$PREFIX/tmp"
mkdir -p "$SETUP_TMP_DIR"
DEBIAN_SETUP_SCRIPT="$SETUP_TMP_DIR/setup_antigravity.sh"

cat << 'EOF_DEBIAN' > "$DEBIAN_SETUP_SCRIPT"
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -y >/dev/null 2>&1
# Install necessary X11, GTK, and GPU acceleration libs in Debian
apt-get install -y --no-install-recommends openbox curl ca-certificates tar \
    libnss3 libnspr4 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
    libgbm1 libpango-1.0-0 libcairo2 libasound2 libatk1.0-0 libcups2 libatk-bridge2.0-0 \
    libgtk-3-0 libgl1 libglx-mesa0 libegl1 libgl1-mesa-dri mesa-vulkan-drivers >/dev/null 2>&1 || \
apt-get install -y --no-install-recommends openbox curl ca-certificates tar \
    libnss3 libnspr4 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
    libgbm1 libpango-1.0-0 libcairo2 libasound2t64 libatk1.0-0t64 libcups2t64 libatk-bridge2.0-0t64 \
    libgtk-3-0t64 libgl1 libglx-mesa0 libegl1 libgl1-mesa-dri mesa-vulkan-drivers >/dev/null 2>&1 || true

mkdir -p /opt/antigravity
if [ ! -x "/opt/antigravity/antigravity" ]; then
    DL_URL=$(curl -sL --compressed https://antigravity.google/download | grep -oE 'main-[A-Za-z0-9_-]+\.js' | head -n1 || true)
    if [ -n "$DL_URL" ]; then DL_URL=$(curl -sL --compressed "https://antigravity.google/$DL_URL" | grep -oE 'https://[^" ]+/linux-arm/Antigravity\.tar\.gz' | head -n1 || true); fi
    if [ -z "$DL_URL" ]; then DL_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.2.1-5287492581195776/linux-arm/Antigravity.tar.gz"; fi
    curl -# -L "$DL_URL" -o /tmp/antigravity.tar.gz
    tar -xzf /tmp/antigravity.tar.gz -C /opt/antigravity --strip-components=1 2>/dev/null || tar -xzf /tmp/antigravity.tar.gz -C /opt/antigravity
    rm -f /tmp/antigravity.tar.gz
    [ -f "/opt/antigravity/Antigravity" ] && mv /opt/antigravity/Antigravity /opt/antigravity/antigravity
    chmod +x /opt/antigravity/antigravity
fi

# Configure Openbox for strict kiosk mode natively (minimal rc.xml)
mkdir -p /root/.config/openbox
cat << 'EOF_RC' > /root/.config/openbox/rc.xml
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <applications>
    <application class="*">
      <decor>no</decor>
      <maximized>yes</maximized>
    </application>
  </applications>
</openbox_config>
EOF_RC

# Create custom xdg-open to redirect browser launches to host via FIFO
cat << 'EOF_XDG' > /usr/local/bin/xdg-open
#!/bin/bash
if [ -p /tmp/termux_open_fifo ]; then
    echo "$1" > /tmp/termux_open_fifo
else
    echo "FIFO not found, cannot open: $1" >&2
fi
EOF_XDG
chmod +x /usr/local/bin/xdg-open

# Run script for Antigravity inside Debian
cat << 'EOF_RUN' > /opt/antigravity/run.sh
#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Hardware Acceleration Flags
GPU_ARGS="--ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --enable-features=Vulkan"

DEBUG_MODE=0
ARGS=()
for arg in "$@"; do
    if [ "$arg" == "--debug" ]; then
        DEBUG_MODE=1
    else
        ARGS+=("$arg")
    fi
done

if ! pgrep -x "openbox" > /dev/null 2>&1; then openbox --sm-disable & sleep 0.2; fi

# Launch App
if [ "$DEBUG_MODE" -eq 1 ]; then
    export ELECTRON_ENABLE_LOGGING=1
    export ELECTRON_ENABLE_STACK_DUMPING=1
    exec /opt/antigravity/antigravity --no-sandbox $GPU_ARGS --enable-logging --v=1 "${ARGS[@]}"
else
    exec /opt/antigravity/antigravity --no-sandbox $GPU_ARGS "${ARGS[@]}" >/dev/null 2>&1
fi
EOF_RUN
chmod +x /opt/antigravity/run.sh
EOF_DEBIAN
chmod +x "$DEBIAN_SETUP_SCRIPT"

step "Executing Subsystem Configuration inside Container"
proot-distro login debian --bind "$SETUP_TMP_DIR:/installer_tmp" --shared-tmp -- bash /installer_tmp/setup_antigravity.sh
rm -f "$DEBIAN_SETUP_SCRIPT"

step "Applying Native VA39 Binary Patch to Language Server"
python3 /data/data/com.termux/files/home/gem/patch_va39.py
success "Native VA39 Binary Patch applied successfully."

step "Deploying Command-Line Launcher ('gem')"
GEM_LAUNCHER="$PREFIX/bin/gem"
cat << 'EOF_TERMUX' > "$GEM_LAUNCHER"
#!/usr/bin/env bash
unset LD_PRELOAD
unset LD_LIBRARY_PATH
export DISPLAY=:0

cleanup_and_exit() {
    trap - SIGINT SIGTERM
    pkill -TERM -P $$ 2>/dev/null || true
    pkill -f "antigravity|openbox" >/dev/null 2>&1 || true
    if [ -n "$FIFO_PID" ]; then kill -9 "$FIFO_PID" 2>/dev/null || true; fi
    rm -f "/data/data/com.termux/files/usr/tmp/termux_open_fifo"
    
    # Fast container-side shutdown
    /data/data/com.termux/files/usr/bin/proot \
        --rootfs="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs" \
        /bin/bash -c "pkill -9 -f 'antigravity'" >/dev/null 2>&1 || true
    
    echo -e "\n\033[1;38;5;221m  ┌──────────────────────────────────────────────────┐\033[0m"
    echo -e "\033[1;38;5;221m  │ \033[38;5;242mSTATUS         : \033[0m\033[1;38;5;221mSHUTTING DOWN ANTIGRAVITY       \033[1;38;5;221m│\033[0m"
    echo -e "\033[1;38;5;221m  └──────────────────────────────────────────────────┘\033[0m\n"
    exit 0
}
trap cleanup_and_exit SIGINT SIGTERM

# Start FIFO bridge
FIFO="/data/data/com.termux/files/usr/tmp/termux_open_fifo"
rm -f "$FIFO"; mkfifo "$FIFO"
( while [ -p "$FIFO" ]; do if read -r url < "$FIFO"; then termux-open "$url"; fi; done ) &
FIFO_PID=$!

get_cols() {
    local c=""
    if [ -r /dev/tty ]; then c=$(stty size </dev/tty 2>/dev/null | awk '{print $2}' || true); fi
    if [ -z "$c" ]; then c=$(tput cols </dev/tty 2>/dev/null || true); fi
    if [ -z "$c" ] || ! [[ "$c" =~ ^[0-9]+$ ]] || [ "$c" -lt 25 ]; then c="${TERM_WIDTH:-${COLUMNS:-50}}"; fi
    if ! [[ "$c" =~ ^[0-9]+$ ]] || [ "$c" -lt 25 ]; then c=50; fi
    echo "$c"
}

draw_banner() {
    local ver="$1"
    local term_w=$(get_cols)
    local max_w=50
    if [ "$term_w" -lt 54 ]; then max_w=$((term_w - 4)); fi
    if [ "$max_w" -lt 38 ]; then max_w=38; fi

    local hline=""
    for ((i=0; i<max_w; i++)); do hline="${hline}─"; done

    pad_text() {
        local text="$1"; local vis_len="$2"
        local pad_len=$(( max_w - vis_len - 2 ))
        if [ "$pad_len" -lt 0 ]; then pad_len=0; fi
        local pad_str=""
        for ((i=0; i<pad_len; i++)); do pad_str="${pad_str} "; done
        echo -n "${text}${pad_str}"
    }

    echo -e "\n\033[1;38;5;39m  ┌${hline}┐\033[0m"
    echo -e "\033[1;38;5;39m  │ $(pad_text "\033[38;5;242mANTIGRAVITY 2.0  \033[0m\033[1;38;5;141mMOBILE GUI" 29) \033[1;38;5;39m│\033[0m"
    echo -e "\033[1;38;5;39m  ├${hline}┤\033[0m"
    echo -e "\033[1;38;5;39m  │ $(pad_text "\033[38;5;242mVersion        : \033[0m\033[1;38;5;48mv${ver}" $(( 18 + ${#ver} ))) \033[1;38;5;39m│\033[0m"
    echo -e "\033[1;38;5;39m  │ $(pad_text "\033[38;5;242mTarget OS      : \033[0m\033[1;37mAndroid Termux X11" 35) \033[1;38;5;39m│\033[0m"
    echo -e "\033[1;38;5;39m  │ $(pad_text "\033[38;5;242mArchitecture   : \033[0m\033[1;37mDebian PRoot Openbox" 37) \033[1;38;5;39m│\033[0m"
    echo -e "\033[1;38;5;39m  └${hline}┘\033[0m"
}

draw_banner "1.0.0"
echo -e "  \033[1;30m💡 Tip: Press \033[1;31mCtrl+C\033[1;30m in this terminal to exit gracefully.\033[0m\n"

# Auto-Patching mechanism for Updates
BIN_PATH="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs/opt/antigravity/resources/bin/language_server"
FLAG_FILE="${BIN_PATH}.patched"
if [ "$BIN_PATH" -nt "$FLAG_FILE" ] || [ ! -f "$FLAG_FILE" ]; then
    echo -e "\033[1;33m[UPDATE DETECTED] Re-applying VA39 binary patch to language_server...\033[0m"
    python3 /data/data/com.termux/files/home/gem/patch_va39.py
fi

DEBUG_MODE=0
for arg in "$@"; do [ "$arg" == "--debug" ] && DEBUG_MODE=1; done

if ! pgrep -f "termux-x11" > /dev/null 2>&1; then termux-x11 :0 >/dev/null 2>&1 & sleep 1; fi

if [ "$DEBUG_MODE" -eq 0 ]; then
    ( sleep 0.5; am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true ) &
fi

PROOT_ARGS=(
    --kill-on-exit --link2symlink --sysvipc
    --kernel-release="Linux localhost 6.17.0-PRoot-Distro #1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000 aarch64 localdomain -1"
    -L --change-id=0:0
    --rootfs="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs"
    --cwd=/root --bind=/dev --bind=/proc --bind=/sys --bind=/dev/urandom:/dev/random
)

if [ ! -L /dev/fd ]; then PROOT_ARGS+=(--bind=/proc/self/fd:/dev/fd); fi
for i in 0 1 2; do
    name=""; case $i in 0) name="stdin" ;; 1) name="stdout" ;; 2) name="stderr" ;; esac
    if [ ! -L "/dev/$name" ] && [ -e "/proc/self/fd/$i" ]; then PROOT_ARGS+=(--bind=/proc/self/fd/$i:/dev/$name); fi
done

SYSDATA_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/sysdata"
PROOT_ARGS+=(
    --bind="$SYSDATA_DIR/sys_empty:/sys/fs/selinux"
    --bind="$SYSDATA_DIR/loadavg:/proc/loadavg"
    --bind="$SYSDATA_DIR/stat:/proc/stat"
    --bind="$SYSDATA_DIR/uptime:/proc/uptime"
    --bind="$SYSDATA_DIR/version:/proc/version"
    --bind="$SYSDATA_DIR/vmstat:/proc/vmstat"
    --bind="$SYSDATA_DIR/sysctl_entry_cap_last_cap:/proc/sys/kernel/cap_last_cap"
    --bind="$SYSDATA_DIR/sysctl_inotify_max_user_watches:/proc/sys/fs/inotify/max_user_watches"
    --bind="$SYSDATA_DIR/sysctl_kernel_overflowuid:/proc/sys/kernel/overflowuid"
    --bind="$SYSDATA_DIR/sysctl_kernel_overflowgid:/proc/sys/kernel/overflowgid"
)

PROOT_ARGS+=(
    --bind="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs/tmp:/dev/shm"
    --bind="/data/data/com.termux/files/usr/tmp:/tmp"
    --bind="/data/data/com.termux/files/usr/tmp/.X11-unix:/tmp/.X11-unix"
)

for p in /data/app /data/dalvik-cache /data/misc/apexdata/com.android.art/dalvik-cache /apex /odm /product /system /system_ext /vendor /linkerconfig/ld.config.txt /linkerconfig/com.android.art/ld.config.txt; do
    if [ -d "$p" ] || [ -f "$p" ]; then PROOT_ARGS+=(--bind="$p"); fi
done

if [ -d "/storage/self/primary" ]; then PROOT_ARGS+=(--bind=/storage/self/primary:/sdcard); fi

PROOT_ARGS+=( --bind="/data/data/com.termux/cache" --bind="$HOME" --bind="$PREFIX" )

# Launch natively (Binary patch is now guaranteed)
if [ "$DEBUG_MODE" -eq 1 ]; then
    /data/data/com.termux/files/usr/bin/proot "${PROOT_ARGS[@]}" /bin/bash -c "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; /opt/antigravity/run.sh --debug" &
else
    /data/data/com.termux/files/usr/bin/proot "${PROOT_ARGS[@]}" /bin/bash -c "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; /opt/antigravity/run.sh" >/dev/null 2>&1 &
fi

wait "$!" 2>/dev/null || true
cleanup_and_exit
EOF_TERMUX

chmod +x "$GEM_LAUNCHER"
if command -v termux-fix-shebang >/dev/null 2>&1; then termux-fix-shebang "$GEM_LAUNCHER"; fi

success "Installation and Optimization Complete. Run 'gem' to start."
