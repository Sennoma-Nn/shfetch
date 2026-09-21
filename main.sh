#!/bin/sh

export LANG=C

NULLFILE=/dev/null
VERSION=0.2.1
UNAME_S=$(uname)
PLAIN_OUTPUT=
LOGO_OVERRIDE=""
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
if [ -n "${SHFETCH_LOGO_DIR:-}" ]; then
    LOGO_DIR=$SHFETCH_LOGO_DIR
elif [ -d "$SCRIPT_DIR/logos" ]; then
    LOGO_DIR=$SCRIPT_DIR/logos
else
    LOGO_DIR=$SCRIPT_DIR/../share/shfetch/logos
fi

upper() {
    tr '[:lower:]' '[:upper:]'
}

lower() {
    tr '[:upper:]' '[:lower:]'
}

get_os_release_file() {
    if [ -f /etc/os-release ]; then
        os_release_file=/etc/os-release
    elif [ -f /usr/lib/os-release ]; then
        os_release_file=/usr/lib/os-release
    else
        return 1
    fi

    printf "%s" "$os_release_file"
}

get_os_id() {
    if [ "$UNAME_S" = "Linux" ]; then
        get_os_value ID
    else
        platform=$(uname | lower)
        case "$platform" in
            mingw*|msys*|cygwin*) printf 'windows' ;;
            *) printf '%s' "$platform" ;;
        esac
    fi
}

get_os_value() {
    key=$1
    printf '%s\n' "$OS_RELEASE" | sed -n "s/^${key}=//p" | sed 's/^"//; s/"$//'
}

get_os_id_with_override() {
    if [ -n "$LOGO_OVERRIDE" ]; then
        printf '%s' "$LOGO_OVERRIDE"
        return 0
    fi

    get_os_id
}

get_os_name() {
    if [ "$UNAME_S" = "Linux" ]; then
        name=$(get_os_value PRETTY_NAME)
        [ -n "$name" ] && printf '%s' "$name" && return 0
        get_os_value NAME
    else
        printf '%s' "$UNAME_S"
    fi
}

get_arch() {
    uname -m
}

is_android() {
    [ "$UNAME_S" = "Linux" ] || return 1

    uname -o 2> $NULLFILE | grep -q "Android" && return 0

    if command -v getprop > $NULLFILE; then
        build_sdk=$(getprop ro.build.version.sdk 2> $NULLFILE)
        if [ -n "$build_sdk" ]; then
            return 0
        fi
    fi

    return 1
}

get_host_name() {
    if command -v hostname > $NULLFILE; then
        name=$(hostname 2> $NULLFILE)
        [ -n "$name" ] && printf '%s' "$name" && return 0
    fi
    [ -n "$HOSTNAME" ] && printf '%s' "$HOSTNAME" && return 0
    return 1
}

get_kernel() {
    uname -r
}

get_uptime() {
    if [ "$UNAME_S" = "Linux" ]; then
        if [ -r /proc/uptime ]; then
            seconds=$(awk '{print int($1)}' /proc/uptime)
            days=$((seconds / 86400))
            hours=$(( (seconds % 86400) / 3600 ))
            minutes=$(( (seconds % 3600) / 60 ))

            printf "%dD %dH %dM" $days $hours $minutes
            return 0
        fi
    else
        return 1
    fi
    return 1
}

get_shell_path() {
    user="$(id -un)"

    if command -v getent > $NULLFILE; then
        shell_path=$(getent passwd "$user" | cut -d: -f7)
        if [ -n "$shell_path" ]; then
            printf '%s' "$shell_path"
            return 0
        fi
    fi
    
    if [ -r /etc/passwd ]; then
        shell_path=$(grep "^$user:" /etc/passwd | cut -d: -f7)
        if [ -n "$shell_path" ]; then
            printf '%s' "$shell_path"
            return 0
        fi
    fi

    if [ -n "$SHELL" ]; then
        printf '%s' "$SHELL"
        return 0
    fi

    return 1
}

get_shell() {
    shell_path=$(get_shell_path) || return 1
    [ -n "$shell_path" ] || return 1
    basename "$shell_path"
}

get_de() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        printf "%s" "$XDG_CURRENT_DESKTOP"
        return 0
    elif [ -n "$DESKTOP_SESSION" ]; then
        printf "%s" "$DESKTOP_SESSION"
        return 0
    elif [ -n "$GDMSESSION" ]; then
        printf "%s" "$GDMSESSION"
        return 0
    fi

    return 1
}

get_package_manager() {
    case "$OS_ID" in
        alpine) managers="apk" ;;
        arch|artix|cachyos|endeavouros|manjaro) managers="pacman" ;;
        debian|deepin|elementary|linuxmint|ubuntu) managers="apt apt-get" ;;
        fedora|rhel|centos|rocky|almalinux) managers="dnf yum" ;;
        opensuse*) managers="zypper" ;;
        void) managers="xbps-install" ;;
        nixos) managers="nix-env" ;;
        darwin) managers="brew" ;;
        *) managers="apt-get dnf yum pacman apk xbps-install zypper nix-env brew pkg" ;;
    esac
    for manager in $managers; do
        if command -v "$manager" > $NULLFILE; then
            printf '%s' "$manager"
            return 0
        fi
    done
    return 1
}

join_comma() {
    awk 'NR>1{printf ", "} {printf "%s", $0} END{print ""}'
}

get_cpu() {
    if [ "$UNAME_S" = "Linux" ]; then
        if command -v lscpu > $NULLFILE; then
            model="$(lscpu 2> $NULLFILE | sed -n 's/^[[:space:]]*Model name:[[:space:]]*//p' | join_comma)"
            cores="$(lscpu 2> $NULLFILE | sed -n 's/^[[:space:]]*CPU(s):[[:space:]]*//p' | tr -d ' ' | head -n 1)"
        fi
        
        if [ -f /proc/cpuinfo ]; then
            [ -z "$model" ] && model="$(sed -nE 's/^(model name|Hardware)[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | awk '!seen[$0]++' | join_comma)"
            [ -z "$cores" ] && cores="$(grep -c '^processor' /proc/cpuinfo)"
        fi

        if is_android && [ -z "$model" ]; then
            model=$(getprop ro.soc.model 2> $NULLFILE)
        fi

        if [ -z "$model" ]; then
            [ -z "$cores" ] && return 1
            model="Unknown CPU"
        fi

        if [ -n "$cores" ]; then
            printf "%s (%s)" "$model" "$cores"
        else
            printf "%s" "$model"
        fi

        return 0
    elif command -v sysctl > $NULLFILE; then
        model=$(sysctl -n hw.model 2> $NULLFILE)
        cores=$(sysctl -n hw.ncpu 2> $NULLFILE)
        [ -n "$model" ] || return 1
        [ -n "$cores" ] && printf '%s (%s)' "$model" "$cores" || printf '%s' "$model"
        return 0
    fi
    return 1
}

get_gpu() {
    if command -v lspci > $NULLFILE; then
        gpu=$(lspci 2> $NULLFILE | grep -iE 'VGA|3D|Display' | cut -d':' -f3- | join_comma | sed 's/^[[:space:]]*//' | sed 's/,$//')
        if [ -n "$gpu" ]; then
            printf '%s' "$gpu"
            return 0
        fi
    fi
    if command -v nvidia-smi > $NULLFILE; then
        gpu=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2> $NULLFILE | join_comma)
        if [ -n "$gpu" ]; then
            printf '%s' "$gpu"
            return 0
        fi
    fi
    return 1
}

get_hwm() {
    if [ "$UNAME_S" = "Linux" ]; then
        if [ -r /sys/devices/virtual/dmi/id/product_name ]; then
            model=$(cat /sys/devices/virtual/dmi/id/product_name)
            [ -n "$model" ] && printf '%s' "$model" && return 0
        fi
        if command -v hostnamectl > $NULLFILE; then
            model=$(hostnamectl 2> $NULLFILE | sed -n 's/^[[:space:]]*Hardware Model:[[:space:]]*//p' | head -n1)
            [ -n "$model" ] && printf '%s' "$model" && return 0
        fi
    elif command -v sysctl > $NULLFILE; then
        model=$(sysctl -n hw.model 2> $NULLFILE)
        [ -n "$model" ] && printf '%s' "$model" && return 0
    fi
    return 1
}

get_mem() {
    if [ -r /proc/meminfo ]; then
        mem_kb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo)
        [ -n "$mem_kb" ] || return 1
        awk -v kb="$mem_kb" 'BEGIN{printf "%.1f GiB", kb/1024/1024}'
        return 0
    fi
    if command -v sysctl > $NULLFILE; then
        mem_bytes=$(sysctl -n hw.memsize 2> $NULLFILE)
        [ -n "$mem_bytes" ] || mem_bytes=$(sysctl -n hw.physmem 2> $NULLFILE)
        [ -n "$mem_bytes" ] || return 1
        awk -v bytes="$mem_bytes" 'BEGIN{printf "%.1f GiB", bytes/1024/1024/1024}'
        return 0
    fi
    return 1
}

get_logo_names() {
    for logo_file in "$LOGO_DIR"/*.txt; do
        [ -f "$logo_file" ] || continue
        logo_name=${logo_file##*/}
        [ "$logo_name" = default.txt ] && continue
        printf '%s\n' "${logo_name%.txt}"
    done | sort
}

get_logo() {
    logo=$(get_os_id_with_override | lower)
    case "$logo" in
        *[!a-z0-9_-]*) logo=default ;;
    esac
    logo_file="$LOGO_DIR/$logo.txt"
    [ -r "$logo_file" ] || logo_file="$LOGO_DIR/default.txt"
    [ -r "$logo_file" ] || return 1
    cat "$logo_file"
}

repeat_char() {
    char="$1"
    count="$2"
    printf "%${count}s" "" | tr ' ' "$char"
}

repeat_line() {
    n=$1
    line=$2
    i=0
    while [ $i -lt "$n" ]; do
        printf "%s\n" "$line"
        i=$((i + 1))
    done
}

get_logo_width() {
    bytes=$(printf '%s\n' "$OS_LOGO" | awk '{ if (length($0) > max) max=length($0) } END { print max + 0 }')
    width=$(printf '%s\n' "$OS_LOGO" | LC_ALL=C.UTF-8 awk '{ if (length($0) > max) max=length($0) } END { print max + 0 }' 2> $NULLFILE)
    case "$width" in
        ''|*[!0-9]*|0)
            if printf '%s' "$OS_LOGO" | LC_ALL=C grep -q '[^ -~]'; then
                width=$((bytes / 3))
            else
                width=$bytes
            fi
            ;;
    esac
    if printf '%s' "$OS_LOGO" | LC_ALL=C grep -q '[^ -~]' && [ "$width" -gt $((bytes / 2)) ]; then
        width=$((bytes / 3))
    fi
    printf '%d\n' "$width"
}

truncate_text() {
    max_len=$1
    value=$2
    printf '%s' "$value" | awk -v max="$max_len" 'BEGIN { if (max < 4) max=4 } { if (length($0) > max) printf "%s...", substr($0, 1, max-3); else printf "%s", $0 }'
}

collect_info() {
    INFO_SYSTEM=
    INFO_HOST=
    INFO_KERNEL=
    INFO_PACKAGE=
    INFO_UPTIME=
    INFO_PLATFORM=
    INFO_DESKTOP=
    INFO_SHELL=
    INFO_CPU=
    INFO_GPU=
    INFO_RAM=
    INFO_HWM=
    HAS_CPU=0
    HAS_GPU=0
    HAS_RAM=0
    HAS_HWM=0

    INFO_SYSTEM=$(get_os_name 2> $NULLFILE) || INFO_SYSTEM=
    INFO_HOST=$(get_host_name 2> $NULLFILE) || INFO_HOST=
    INFO_KERNEL="$UNAME_S $(get_kernel 2> $NULLFILE)"
    INFO_PACKAGE=$(get_package_manager 2> $NULLFILE) || INFO_PACKAGE=
    INFO_UPTIME=$(get_uptime 2> $NULLFILE) || INFO_UPTIME=
    INFO_PLATFORM=$(get_arch 2> $NULLFILE) || INFO_PLATFORM=
    INFO_DESKTOP=$(get_de 2> $NULLFILE) || INFO_DESKTOP=
    INFO_SHELL=$(get_shell 2> $NULLFILE) || INFO_SHELL=

    if INFO_CPU=$(get_cpu 2> $NULLFILE); then HAS_CPU=1; fi
    if INFO_GPU=$(get_gpu 2> $NULLFILE); then HAS_GPU=1; fi
    if INFO_HWM=$(get_hwm 2> $NULLFILE); then HAS_HWM=1; fi
    if INFO_RAM=$(get_mem 2> $NULLFILE); then HAS_RAM=1; fi

    DEVICE_LINES=0
    [ "$HAS_CPU" -eq 1 ] && DEVICE_LINES=$((DEVICE_LINES + 1))
    [ "$HAS_GPU" -eq 1 ] && DEVICE_LINES=$((DEVICE_LINES + 1))
    [ "$HAS_RAM" -eq 1 ] && DEVICE_LINES=$((DEVICE_LINES + 1))
    [ "$HAS_HWM" -eq 1 ] && DEVICE_LINES=$((DEVICE_LINES + 1))
    [ "$DEVICE_LINES" -gt 0 ] && DEVICE_LINES=$((DEVICE_LINES + 2))
    [ "$DEVICE_LINES" -eq 0 ] && DEVICE_LINES=$((DEVICE_LINES - 1))
}

print_plain_field() {
    label=$1
    value=$2
    max_len=${3:-80}
    [ -n "$value" ] || return 0
    printf '%-10s: %s\n' "$label" "$(truncate_text "$max_len" "$value")"
}

print_plain() {
    printf '%s\n' "$OS_LOGO"
    print_plain_field SYSTEM   "$INFO_SYSTEM"   80
    print_plain_field HOST     "$INFO_HOST"     80
    print_plain_field KERNEL   "$INFO_KERNEL"   80
    print_plain_field PACKAGE  "$INFO_PACKAGE"  40
    print_plain_field UPTIME   "$INFO_UPTIME"   40
    print_plain_field PLATFORM "$INFO_PLATFORM" 40
    print_plain_field DESKTOP  "$INFO_DESKTOP"  40
    print_plain_field SHELL    "$INFO_SHELL"    40
    print_plain_field CPU      "$INFO_CPU"      100
    print_plain_field GPU      "$INFO_GPU"      100
    print_plain_field HWM      "$INFO_HWM"      40
    print_plain_field RAM      "$INFO_RAM"      40
}

draw_table() {
    logo_table_width=$((LOGO_WIDTH + 4))
    logo_table_dash=$(repeat_char "-" $logo_table_width)
    sys_info_width=35
    sys_info_dash=$(repeat_char "-" "$sys_info_width")
    right_gap=$((sys_info_width - 4))
    
    printf "\033[0m"

    # 防止距离底部不足表格的高度打印后换行导致 esc[s 存储的位置错误
    down_lines=$((13 + DEVICE_LINES))
    repeat_char "\n" $down_lines #
    printf "\033[%sA" $down_lines

    printf "\033[s"
    
    # 打印表格第一个部分顶部 +-- ... --+-- ... --+
    printf "+%s+%s+\n" "$logo_table_dash" "$sys_info_dash"

    # 打印第一个部分内容区域 | ... | ... | 共十行
    # 设计之初为了 logo 的美观等，所有的 logo 高度都是盲文 8 宽度不定，上下各空两行，至于为什么是 8 因为盲文 logo > 8 会有密集恐惧症（
    table_up="$(printf "|  \033[%dG  |  \033[%dC  |" "$logo_table_width" "$right_gap")"
    repeat_line 10 "$table_up"

    # 打印表格一二部分中间 +-- ... --+-- ... --+
    printf "+%s+%s+\n" "$logo_table_dash" "$sys_info_dash"

    # 打印第而个部分内容区域 | ...... |
    table_down="$(printf "|  \033[%dG     \033[%dC  |" "$logo_table_width" "$right_gap")"
    repeat_line "$DEVICE_LINES" "$table_down"

    # 打印表格底部 +-- ...... --+ 如果沒有獲取到任何硬體信息就不列印
    [ "$DEVICE_LINES" -gt 0 ] && printf "+%s-%s+\n" "$logo_table_dash" "$sys_info_dash"
}

_print_title() {
    row=$1
    col=$2
    text=$3

    printf "\033[u\033[2m\033[%dB\033[%dC%s" "$row" "$col" "$text"
}

fill_title() {
    printf '\033[0m'

    id_max_len=$((LOGO_WIDTH + 2))

    show_id=$(get_os_id_with_override | upper)
    show_id=$(printf "%.${id_max_len}s" "$show_id")

    _print_title 10 $((LOGO_WIDTH + 4 - ${#show_id})) "$show_id"
    _print_title 10 $((LOGO_WIDTH + 34)) "SYSTEM"

    [ "$DEVICE_LINES" -gt 0 ] && _print_title $((11 + DEVICE_LINES)) $((LOGO_WIDTH + 34)) "DEVICE"

    printf '\033[0m'
}

fill_logo() {
    printf "\033[0m\033[u\033[2B"
    printf "%s\n" "$OS_LOGO" | while read -r line; do
        printf "\033[4G%s\n" "$line"
    done
}

_print_info() {
    row=$1
    left_col=$2
    left_text="$3"
    right_col=$4
    max_len=$6
    right_text=$(truncate_text "$max_len" "$5" | upper | tr '-' '_')

    printf "\033[u\033[%dB\033[%dG%s\033[%dG: %.${max_len}s" "$row" "$left_col" "$left_text" "$right_col" "$right_text"
}

fill_info() {
    printf "\033[0m"

    left_col=$((LOGO_WIDTH + 9))
    right_col=$((LOGO_WIDTH + 9 + 9))

    sys_info_max_len=21
    dev_info_max_len=$((LOGO_WIDTH + 30))

    line=2
    if [ -n "$INFO_SYSTEM" ];   then _print_info $line "$left_col" "SYSTEM"   "$right_col" "$INFO_SYSTEM"   $sys_info_max_len; line=$((line+1)); fi
    if [ -n "$INFO_HOST" ];     then _print_info $line "$left_col" "HOST"     "$right_col" "$INFO_HOST"     $sys_info_max_len; line=$((line+1)); fi
    if [ -n "$INFO_KERNEL" ];   then _print_info $line "$left_col" "KERNEL"   "$right_col" "$INFO_KERNEL"   $sys_info_max_len; line=$((line+1)); fi
    if [ -n "$INFO_PACKAGE" ];  then _print_info $line "$left_col" "PACKAGE"  "$right_col" "$INFO_PACKAGE"  $sys_info_max_len; line=$((line+1)); fi
    if [ -n "$INFO_UPTIME" ];   then _print_info $line "$left_col" "UPTIME"   "$right_col" "$INFO_UPTIME"   $sys_info_max_len; line=$((line+1)); fi
    if [ -n "$INFO_PLATFORM" ]; then _print_info $line "$left_col" "PLATFORM" "$right_col" "$INFO_PLATFORM" $sys_info_max_len; line=$((line+1)); fi
    if [ -n "$INFO_DESKTOP" ];  then _print_info $line "$left_col" "DESKTOP"  "$right_col" "$INFO_DESKTOP"  $sys_info_max_len; line=$((line+1)); fi
    if [ -n "$INFO_SHELL" ];    then _print_info $line "$left_col" "SHELL"    "$right_col" "$INFO_SHELL"    $sys_info_max_len; line=$((line+1)); fi

    line=13
    if [ "$HAS_CPU" -eq 1 ]; then _print_info $line 4 "CPU" 8 "$INFO_CPU" $dev_info_max_len; line=$((line+1)); fi
    if [ "$HAS_GPU" -eq 1 ]; then _print_info $line 4 "GPU" 8 "$INFO_GPU" $dev_info_max_len; line=$((line+1)); fi
    if [ "$HAS_HWM" -eq 1 ]; then _print_info $line 4 "HWM" 8 "$INFO_HWM" $dev_info_max_len; line=$((line+1)); fi
    if [ "$HAS_RAM" -eq 1 ]; then _print_info $line 4 "RAM" 8 "$INFO_RAM" $dev_info_max_len; line=$((line+1)); fi
}

reset_cursor_to_end() {
    printf "\033[u\033[%sB" $((13 + DEVICE_LINES))
    printf "\033[0m"
}

usage() {
    printf '%s\n' \
        "Usage: $0 [options]" \
        "  -l, --logo NAME       use a specific logo" \
        "  -p, --plain           print without ANSI cursor controls" \
        "  -t, --table           print use table" \
        "  -V, --version         print version" \
        "  -L  --list-logos      list supported logo names" \
        "  -h, --help            show this help"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -l|--logo)
            [ "$#" -ge 2 ] || { printf 'Error: %s requires a value\n' "$1" >&2; exit 1; }
            LOGO_OVERRIDE=$2
            shift 2
            ;;
        -p|--plain)
            PLAIN_OUTPUT=1
            shift
            ;;
        -t|--table)
            PLAIN_OUTPUT=0
            shift
            ;;
        -V|--version)
            printf 'shfetch %s\n' "$VERSION"
            exit 0
            ;;
        -L|--list-logos)
            get_logo_names
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -* )
            printf 'Error: unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
        *)
            printf 'Error: unexpected argument: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

OS_RELEASE_FILE=$(get_os_release_file)
if [ -n "$OS_RELEASE_FILE" ]; then
    OS_RELEASE=$(cat "$OS_RELEASE_FILE")
else
    OS_RELEASE=""
fi

OS_ID=$(get_os_id)
OS_LOGO=$(get_logo)
LOGO_WIDTH=$(get_logo_width)
collect_info

TERMINAL_WIDTH=${COLUMNS:-80}
if command -v tput > $NULLFILE && [ -t 1 ]; then
    detected_width=$(tput cols 2> $NULLFILE)
    case "$detected_width" in
        ''|*[!0-9]*) ;;
        *) TERMINAL_WIDTH=$detected_width ;;
    esac
fi

if [ -z "$PLAIN_OUTPUT" ]; then
    PLAIN_OUTPUT=0
    if [ ! -t 1 ] || [ "$TERM" = dumb ] || [ "$TERMINAL_WIDTH" -lt 70 ]; then
        PLAIN_OUTPUT=1
    fi
fi

if [ "$PLAIN_OUTPUT" -eq 1 ]; then
    print_plain
else
    draw_table
    fill_title
    fill_logo
    fill_info
    reset_cursor_to_end
    printf "\n"
fi
