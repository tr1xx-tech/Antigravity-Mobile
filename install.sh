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
    local max_w=$((term_w - 4))
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
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}ANTIGRAVITY 2.0  ${RESET}${PURPLE_BOLD}MOBILE GUI" 27) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  ├${hline}┤${RESET}"
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}Version        : ${RESET}${GREEN_BOLD}v${ver}" $(( 18 + ${#ver} ))) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}Target OS      : ${RESET}${WHITE}Android Termux X11" 35) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  │ $(pad_text "${GRAY}Architecture   : ${RESET}${WHITE}Debian PRoot Openbox" 37) ${CYAN_BOLD}│${RESET}"
    echo -e "${CYAN_BOLD}  └${hline}┘${RESET}"
}

on_host_interrupt() {
    trap - SIGINT SIGTERM
    echo -e "\n${RED_BOLD}✗  Installation aborted by user.${RESET}"
    rm -f "$PREFIX/tmp/setup_antigravity.sh" /tmp/antigravity.tar.gz 2>/dev/null || true
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
info "Updating Termux repository mirrors (this may take a few moments)..."
pkg update -y >/dev/null 2>&1 || true



# Auto-detect GPU for minimal package installation
EGL=$(getprop ro.hardware.egl 2>/dev/null | tr '[:upper:]' '[:lower:]')
BOARD=$(getprop ro.hardware 2>/dev/null | tr '[:upper:]' '[:lower:]')
PLATFORM=$(getprop ro.board.platform 2>/dev/null | tr '[:upper:]' '[:lower:]')

GPU_PKG=""
if [[ "$EGL" == *"adreno"* ]] || [[ "$BOARD" == *"qcom"* ]] || [[ "$PLATFORM" == *"qcom"* ]] || [[ "$PLATFORM" == *"snapdragon"* ]]; then
    GPU_PKG="mesa-vulkan-icd-freedreno"
    info "Detected Adreno GPU. Selecting freedreno drivers."
elif [[ "$EGL" == *"mali"* ]] || [[ "$BOARD" == *"mtk"* ]] || [[ "$BOARD" == *"exynos"* ]] || [[ "$PLATFORM" == *"mtk"* ]]; then
    GPU_PKG=""
    info "Detected Mali/Exynos/MediaTek GPU. Using system driver pipeline."
else
    info "Could not auto-detect GPU. Falling back to software rendering packages."
fi

info "Installing core system packages..."
pkg install -y proot-distro curl tar python x11-repo >/dev/null 2>&1 || true
pkg update -y >/dev/null 2>&1 || true
info "Installing GUI and hardware acceleration drivers..."
pkg install -y termux-x11-nightly virglrenderer-android $GPU_PKG >/dev/null 2>&1 || true

MISSING_PKGS=()
for cmd in proot-distro curl tar python3 termux-x11 virgl_test_server_android; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_PKGS+=("$cmd")
    fi
done

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    error "Failed to install required host packages: ${MISSING_PKGS[*]}"
    echo -e "   ${CYAN}ℹ${RESET}  ${DIM}└─ ${RESET}Please run 'pkg update -y' manually and check for Termux repository errors."
    exit 1
fi
success "Host utilities and dynamic GPU drivers successfully installed."

step "Verifying Debian Subsystem (PRoot Container)"
if ! proot-distro login debian -- true </dev/null >/dev/null 2>&1; then
    if ! proot-distro install debian </dev/null >/dev/null 2>&1; then
        error "Failed to provision Debian container. Check your connection."
        exit 1
    fi
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

info() {
    echo -e "   \033[1;36mℹ\033[0m  \033[2m$1\033[0m"
}

info "Updating Debian package lists..."
apt-get update -y >/dev/null 2>&1

info "Installing X11, GTK, graphics, and secure keyring dependencies..."
apt-get install -y --no-install-recommends openbox curl wget ca-certificates tar \
    libnss3 libnspr4 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
    libgbm1 libpango-1.0-0 libcairo2 libasound2 libatk1.0-0 libcups2 libatk-bridge2.0-0 \
    libgtk-3-0 libgl1 libglx-mesa0 libegl1 libgl1-mesa-dri \
    dbus-x11 gnome-keyring libsecret-1-0 >/dev/null 2>&1 || \
apt-get install -y --no-install-recommends openbox curl wget ca-certificates tar \
    libnss3 libnspr4 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
    libgbm1 libpango-1.0-0 libcairo2 libasound2t64 libatk1.0-0t64 libcups2t64 libatk-bridge2.0-0t64 \
    libgtk-3-0t64 libgl1 libglx-mesa0 libegl1 libgl1-mesa-dri \
    dbus-x11 gnome-keyring libsecret-1-0 >/dev/null 2>&1 || true

mkdir -p /opt/antigravity
if [ ! -x "/opt/antigravity/antigravity" ]; then
    info "Resolving Antigravity Core download URL..."
    DL_URL=$(curl -sL --compressed https://antigravity.google/download | grep -oE 'main-[A-Za-z0-9_-]+\.js' | head -n1 || true)
    if [ -n "$DL_URL" ]; then DL_URL=$(curl -sL --compressed "https://antigravity.google/$DL_URL" | grep -oE 'https://[^" ]+/linux-arm/Antigravity\.tar\.gz' | head -n1 || true); fi
    if [ -z "$DL_URL" ]; then DL_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.2.1-5287492581195776/linux-arm/Antigravity.tar.gz"; fi
    
    info "Downloading payload (this may take a minute)..."
    wget -q --show-progress "$DL_URL" -O /tmp/antigravity.tar.gz
    
    info "Extracting and configuring binary..."
    tar -xzf /tmp/antigravity.tar.gz -C /opt/antigravity --strip-components=1 2>/dev/null || tar -xzf /tmp/antigravity.tar.gz -C /opt/antigravity
    rm -f /tmp/antigravity.tar.gz
    [ -f "/opt/antigravity/Antigravity" ] && mv /opt/antigravity/Antigravity /opt/antigravity/antigravity
    chmod +x /opt/antigravity/antigravity
fi
info "Configuring Openbox and window manager bounds..."

# Configure Openbox for strict kiosk mode natively (minimal rc.xml)
mkdir -p /root/.config/openbox
cat << 'EOF_RC' > /root/.config/openbox/rc.xml
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <applications>
    <application class="*">
      <decor>no</decor>
      <maximized>yes</maximized>
      <fullscreen>yes</fullscreen>
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
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=:0
export ELECTRON_OZONE_PLATFORM_HINT=x11
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Initialize gnome-keyring-daemon (Passwordless login keyring)
mkdir -p "$HOME/.local/share/keyrings"
if [ ! -f "$HOME/.local/share/keyrings/default" ]; then
    echo -n "login" > "$HOME/.local/share/keyrings/default"
fi
if [ ! -f "$HOME/.local/share/keyrings/login.keyring" ]; then
    echo "[keyring]" > "$HOME/.local/share/keyrings/login.keyring"
    echo "display-name=login" >> "$HOME/.local/share/keyrings/login.keyring"
    echo "ctime=0" >> "$HOME/.local/share/keyrings/login.keyring"
    echo "mtime=0" >> "$HOME/.local/share/keyrings/login.keyring"
    echo "lock-on-idle=false" >> "$HOME/.local/share/keyrings/login.keyring"
    echo "lock-after=false" >> "$HOME/.local/share/keyrings/login.keyring"
    chmod 600 "$HOME/.local/share/keyrings/login.keyring" "$HOME/.local/share/keyrings/default"
fi

# Start D-Bus session if not running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Unlock/Start the keyring daemon
echo -n "" | gnome-keyring-daemon --unlock --components=secrets >/dev/null 2>&1 || true
eval $(gnome-keyring-daemon --start --components=secrets)
export GNOME_KEYRING_CONTROL
export GNOME_KEYRING_PID

# Hardware Acceleration Flags
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
GPU_ARGS="--ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --use-gl=egl --enable-webgl --enable-accelerated-2d-canvas --num-raster-threads=4 --start-maximized"

SOFTWARE_MODE=0
DEBUG_MODE=0
ARGS=()
for arg in "$@"; do
    if [ "$arg" == "--debug" ]; then
        DEBUG_MODE=1
    elif [ "$arg" == "--software" ]; then
        SOFTWARE_MODE=1
    else
        ARGS+=("$arg")
    fi
done

if [ "$SOFTWARE_MODE" -eq 1 ]; then
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    GPU_ARGS="--disable-gpu"
fi

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
proot-distro login debian --bind "$SETUP_TMP_DIR:/installer_tmp" --shared-tmp -- bash /installer_tmp/setup_antigravity.sh </dev/null
rm -f "$DEBIAN_SETUP_SCRIPT"

step "Applying Native VA39 Binary Patch to Language Server"
PATCHER="$PREFIX/bin/patch_va39.py"
cat << 'EOF_PATCHER' > "$PATCHER"
import shutil
import struct
from pathlib import Path
import os

bin_path = Path("/data/data/com.termux/files/usr/var/lib/proot-distro/containers/debian/rootfs/opt/antigravity/resources/bin/language_server")
bak_path = Path(str(bin_path) + ".bak")
flag_path = Path(str(bin_path) + ".patched")

if not bin_path.exists():
    print("Warning: language_server not found. Skipping binary patch.")
    exit(0)

# Check if already patched by looking at our mmap signature
try:
    data = bytearray(bin_path.read_bytes())
    if data.count(struct.pack("<I", 0xD2C00409)) > 0 and data.count(struct.pack("<I", 0xD2C20009)) == 0:
        print("   \033[1;32m✓\033[0m  VA39 binary patch already applied.")
        flag_path.touch()
        exit(0)
except Exception as e:
    print(f"Error reading {bin_path}: {e}")
    exit(1)

print("   \033[1;36mℹ\033[0m  \033[2mUnpatched binary detected. Applying VA39 patch...\033[0m")

# Create backup of the unpatched binary if it doesn't exist
if not bak_path.exists():
    shutil.copyfile(bin_path, bak_path)
elif os.path.getmtime(bin_path) > os.path.getmtime(bak_path):
    shutil.copyfile(bin_path, bak_path)

data = bytearray(bak_path.read_bytes())

def get(off): return struct.unpack_from("<I", data, off)[0]
def put(off, word): struct.pack_into("<I", data, off, word)

def find_section(name_target):
    if data[:4] != b"\x7fELF": return None, None
    e_shoff = struct.unpack_from("<Q", data, 40)[0]
    e_shentsize = struct.unpack_from("<H", data, 58)[0]
    e_shnum = struct.unpack_from("<H", data, 60)[0]
    e_shstrndx = struct.unpack_from("<H", data, 62)[0]
    shstr_base = e_shoff + e_shstrndx * e_shentsize
    shstr_off = struct.unpack_from("<Q", data, shstr_base + 24)[0]
    for i in range(e_shnum):
        base = e_shoff + i * e_shentsize
        sh_name = struct.unpack_from("<I", data, base)[0]
        sh_offset = struct.unpack_from("<Q", data, base + 24)[0]
        sh_size = struct.unpack_from("<Q", data, base + 32)[0]
        nend = data.index(b"\x00", shstr_off + sh_name)
        section = data[shstr_off + sh_name : nend].decode("utf-8", errors="replace")
        if section == name_target:
            return sh_offset, sh_offset + sh_size
    return None, None

lo, hi = 0, len(data)
sec_lo, sec_hi = find_section("google_malloc")
if sec_lo is not None: lo, hi = sec_lo, sec_hi
else:
    sec_lo, sec_hi = find_section(".text")
    if sec_lo is not None: lo, hi = sec_lo, sec_hi

word_rewrites = {
    0xD2C20009: 0xD2C00409, 0xD2C2000A: 0xD2C0040A,
    0xF2C20008: 0xF2DFF408, 0xF2C20009: 0xF2DFF409,
    0xD2C10009: 0xD2C00209, 0xD2C1000A: 0xD2C0020A,
    0xF2C38008: 0xF2DFF708, 0xF2C38009: 0xF2DFF709,
    0x92560A6C: 0x925D0A6C, 0x92560A6A: 0x925D0A6A,
    0xD2C3000D: 0xD2C0060D, 0xD2C3000C: 0xD2C0060C,
    0xD2C08008: 0xD2C00108,
}

ubfx_count = lsl_count = mask_count = mmap_count = tags_count = 0
for off in range(lo, hi, 4):
    w = get(off)
    if (w & 0x7F800000) == 0x53000000:
        immr = (w >> 16) & 0x3F
        imms = (w >> 10) & 0x3F
        if immr == 42 and imms == 44:
            put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (35 << 16) | (37 << 10))
            ubfx_count += 1
        elif immr == 22 and imms == 21:
            put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (29 << 16) | (28 << 10))
            lsl_count += 1
    elif w == 0xF2E00029:
        put(off, 0xD3596129)
        mmap_count += 1
    elif w == 0x92D3800A and off + 4 < hi and get(off + 4) == 0xF2E0000A:
        put(off, 0x9280000A)
        put(off + 4, 0xD35DFD4A)
        mask_count += 1
    elif w in word_rewrites:
        put(off, word_rewrites[w])
        tags_count += 1

bin_path.write_bytes(data)
bin_path.chmod(0o755)
flag_path.touch()

print(f"   \033[1;36mℹ\033[0m  \033[2mPatches applied: UBFX={ubfx_count}, LSL={lsl_count}, MASK={mask_count}, MMAP={mmap_count}, TAGS={tags_count}\033[0m")
print("   \033[1;32m✓\033[0m  Native VA39 Binary Patch applied successfully.")
EOF_PATCHER
python3 "$PATCHER"

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
    local max_w=$((term_w - 4))
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
    echo -e "\033[1;38;5;39m  │ $(pad_text "\033[38;5;242mANTIGRAVITY 2.0  \033[0m\033[1;38;5;141mMOBILE GUI" 27) \033[1;38;5;39m│\033[0m"
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
    python3 "$PREFIX/bin/patch_va39.py"
fi

DEBUG_MODE=0
for arg in "$@"; do [ "$arg" == "--debug" ] && DEBUG_MODE=1; done

if ! pgrep -f "virgl_test_server_android" > /dev/null 2>&1; then VIRGL_RENDERER_USE_EGL=1 virgl_test_server_android >/dev/null 2>&1 & fi
if ! pgrep -f "termux-x11" > /dev/null 2>&1; then termux-x11 :0 >/dev/null 2>&1 & sleep 1; fi

if [ "$DEBUG_MODE" -eq 0 ]; then
    if ! am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1; then
        echo -e "\n\033[1;31m✗ Error: Termux-X11 Android App is not installed!\033[0m"
        echo -e "\033[1;34mℹ\033[0m You need the Termux-X11 app to view the GUI."
        echo -e "\033[1;34mℹ\033[0m Opening the GitHub download page..."
        termux-open "https://github.com/termux/termux-x11/releases"
        exit 1
    fi
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
    /data/data/com.termux/files/usr/bin/proot "${PROOT_ARGS[@]}" /opt/antigravity/run.sh "$@" &
else
    /data/data/com.termux/files/usr/bin/proot "${PROOT_ARGS[@]}" /opt/antigravity/run.sh "$@" >/dev/null 2>&1 &
fi

wait "$!" 2>/dev/null || true
cleanup_and_exit
EOF_TERMUX

chmod +x "$GEM_LAUNCHER"
if command -v termux-fix-shebang >/dev/null 2>&1; then termux-fix-shebang "$GEM_LAUNCHER"; fi

success "Installation and Optimization Complete. Run 'gem' to start."
