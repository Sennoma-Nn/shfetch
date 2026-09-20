#!/bin/sh

export LANG=C

NULLFILE=/dev/null

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
    if [ "$(uname)" = "Linux" ]; then
        printf "%s" "$OS_RELEASE" | grep '^ID=' | cut -d= -f2- | tr -d '"'
    else
        printf "" # 待实现
        return 1
    fi
}

get_os_id_with_override() {
    if [ -n "$LOGO_OVERRIDE" ]; then
        printf '%s' "$LOGO_OVERRIDE"
        return 0
    fi

    get_os_id
}

get_os_name() {
    if [ "$(uname)" = "Linux" ]; then
        printf "%s" "$OS_RELEASE" | grep '^PRETTY_NAME=' | cut -d= -f2- | tr -d '"()'
    else
        printf "" # 待实现
        return 1
    fi
}

get_arch() {
    uname -m
}

is_android() {
    [ "$(uname)" = "Linux" ] || return 1

    uname -o 2> $NULLFILE | grep -q "Android" && return 0

    if command -v getprop > $NULLFILE; then
        build_sdk=$(getprop ro.build.version.sdk 2> $NULLFILE)
        if [ -n "$build_sdk" ]; then
            return 0
        fi
    fi

    return 1
}

get_platform() {
    arch=$(get_arch)
    printf "%s" "$arch"
}

get_host_name() {
    if [ "$(uname)" = "Linux" ]; then
        name=$(hostnamectl 2>/dev/null | sed -n 's/^[[:space:]]*Hardware Model:[[:space:]]*//p' | head -n1)
        if [ -n "$name" ]; then
            printf '%s' "$name"
            return 0
        fi

        if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
            name=$(cat /sys/devices/virtual/dmi/id/product_name)
            if [ -n "$name" ]; then
                printf '%s' "$name"
                return 0
            fi
        fi

        if [ -n "$HOSTNAME" ]; then
            printf '%s' "$HOSTNAME"
            return 0
        fi

        return 1
    else
        printf "" # 待实现
        return 1
    fi
}

get_kernel() {
    uname -r
}

get_uptime() {
    if [ "$(uname)" = "Linux" ]; then
        if [ -r /proc/uptime ]; then
            seconds=$(awk '{print int($1)}' /proc/uptime)
            days=$((seconds / 86400))
            hours=$(( (seconds % 86400) / 3600 ))
            minutes=$(( (seconds % 3600) / 60 ))

            printf "%dD %dH %dM" $days $hours $minutes
            return 0
        fi
    else
        printf "" # 待实现
        return 1
    fi
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
    shell_path=$(get_shell_path)
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
    managers="apt dnf rpm pacman xbps-install pkg apk eopkg nix-env yum zypper dpkg pm port pacstall emerge cave yay brew flatpak"
    found=""

    for m in $managers; do
        if command -v "$m" > $NULLFILE; then
            found="$found $m"
        fi
    done

    found="${found# }"

    if [ -n "$found" ]; then
        printf "%s" "$found"
        return 0
    fi

    return 1
}

join_comma() {
    awk 'NR>1{printf ", "} {printf "%s", $0} END{print ""}'
}

get_cpu() {
    if [ "$(uname)" = "Linux" ]; then
        if command -v lscpu > $NULLFILE; then
            model="$(lscpu 2> $NULLFILE | sed -n 's/^[[:space:]]*Model name:[[:space:]]*//p' | join_comma)"
            cores="$(lscpu 2> $NULLFILE | sed -n 's/^[[:space:]]*CPU(s):[[:space:]]*//p' | tr -d ' ' | head -n 1)"
        elif [ -f /proc/cpuinfo ]; then
            model="$(sed -nE 's/^(model name|Hardware)[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | awk '!seen[$0]++' | join_comma)"
            cores="$(grep -c '^processor' /proc/cpuinfo)"

            if is_android && [ -z "$model" ]; then
                model=$(getprop ro.soc.model 2> $NULLFILE)
            fi
        fi

        [ -z "$model" ] && model="UNKNOWN CPU"

        if [ -n "$cores" ]; then
            printf "%s (%s)" "$model" "$cores"
        else
            printf "%s" "$model"
        fi

        return 0
    else
        printf "" # 待实现
        return 1
    fi
}

get_gpu() {
    if command -v lspci > $NULLFILE; then
        lspci 2> $NULLFILE | grep -iE "VGA|3D|Display" | cut -d':' -f3- | join_comma | sed 's/^[[:space:]]*//' | sed 's/,$//'
        return 0
    elif command -v nvidia-smi > $NULLFILE; then
        nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2> $NULLFILE | join_comma
        return 0
    else
        printf "" # 待实现
        return 1
    fi
}

get_mem() {
    [ -r /proc/meminfo ] || return 1

    mem_kb=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo)
    [ -n "$mem_kb" ] || return 1

    mem_gib=$(awk "BEGIN {printf \"%.1f\", $mem_kb / 1024 / 1024}")
    printf "%s GiB" "$mem_gib"
}

get_logo() {
    if [ -n "$LOGO_OVERRIDE" ]; then
        logo=$(printf '%s' "$LOGO_OVERRIDE" | lower)
    else
        logo=$(printf '%s' "$OS_ID" | lower)
    fi

    case "$logo" in
        alpine)
            printf '%s\n' \
                "⠀⠀⠀⢀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀" \
                "⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠀⠀" \
                "⠀⢠⣿⣿⣿⣿⡿⠋⠙⢿⡿⠟⢿⣿⣿⣿⣿⡄⠀" \
                "⣰⣿⣿⣿⡿⠋⢀⣴⣄⠀⠀⢀⠀⠙⢿⣿⣿⣿⣆" \
                "⠹⣿⣟⠉⢀⣔⠁⣿⣿⣷⣄⠀⢑⣄⠀⢙⣿⣿⠏" \
                "⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀" \
                "⠀⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀" \
                "⠀⠀⠀⠈⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠁⠀⠀⠀" \
            ;;
        arch)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⠀⠀⢠⡄⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⢠⣿⣿⡄⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⢀⡛⣿⣿⣿⡄⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⢠⣾⣿⣿⣿⣿⣿⡄⠀⠀⠀⠀" \
                "⠀⠀⠀⢠⣿⣿⣿⠿⠿⣿⣿⣿⡄⠀⠀⠀" \
                "⠀⠀⢠⣿⣿⣿⠇⠀⠀⠸⣿⣿⣿⣄⠀⠀" \
                "⠀⣠⣿⣿⡿⠿⠄⠀⠀⠠⠿⢿⣿⣦⣄⠀" \
                "⡰⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠻⢆"
            ;;
        artix)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⠀⠀⣰⣆⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⣰⣿⣿⣆⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⣀⡀⠈⠛⠿⣿⣿⣆⠀⠀⠀⠀" \
                "⠀⠀⠀⣰⣿⣿⣷⣶⣤⣀⠉⠻⢆⠀⠀⠀" \
                "⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⡿⠗⠂⢀⠀⠀" \
                "⠀⣰⣿⣿⣿⡿⠿⠛⠉⠁⣀⣴⣾⣿⣆⠀" \
                "⣰⠿⠛⠉⠁⠀⠀⠀⠀⠀⠀⠉⠙⠛⠿⣆" \
            ;;
        cachyos)
            printf '%s\n' \
                "⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⣀⠀⠀⠀" \
                "⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠉⠀⠀⠀" \
                "⠀⢠⣿⣿⣿⣿⣿⠟⠉⠉⠉⠉⠀⠀⣠⣄⠀⠀⠀⠀" \
                "⣰⣿⣿⣿⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⠙⠋⠀⠀⠀⠀" \
                "⠹⣿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣶⣦" \
                "⠀⠘⣿⣿⣿⣿⣿⣦⣀⣀⣀⣀⣀⣀⣀⣀⡀⠻⠿⠟" \
                "⠀⠀⠘⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀⠀" \
                "⠀⠀⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀" \
            ;;
        centos)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⠀⢠⣼⣧⡄⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⢰⣶⡆⢴⣶⢸⡇⣶⡦⢰⣶⡆⠀⠀" \
                "⠀⠀⢈⣍⠻⣦⡉⢸⡇⢉⣴⠟⣩⡁⠀⠀" \
                "⣀⣶⣈⣛⣃⣈⠋⠀⠀⠙⣁⣘⣛⣁⣶⣀" \
                "⠉⠿⢉⣭⡍⢉⣄⠀⠀⣠⡉⢩⣭⡉⠿⠉" \
                "⠀⠀⢈⣋⣴⠟⣁⢸⡇⣈⠻⣦⣙⡁⠀⠀" \
                "⠀⠀⠸⠿⠇⠺⠿⢸⡇⠿⠗⠸⠿⠇⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠘⢻⡟⠃⠀⠀⠀⠀⠀⠀" \
            ;;
        debian)
            printf '%s\n' \
                "⠀⠀⠀⠀⢀⣤⣶⠿⠶⠶⣦⣄⡀⠀⠀⠀" \
                "⠀⠀⠀⣰⠿⠋⠁⠀⠀⠀⠀⠹⣿⡆⠀⠀" \
                "⠀⠀⣸⠏⠀⠀⠀⡠⠒⠀⠀⠀⢸⡆⠀⠀" \
                "⠀⠀⣿⠀⠀⠀⢸⠀⠀⠀⠀⠀⢸⠇⠀⠀" \
                "⠀⠀⢿⠀⠀⠀⠈⢣⣀⠀⣀⡤⠋⠀⠀⠀" \
                "⠀⠀⠸⣷⠀⠀⠀⠀⠉⠉⠁⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠙⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠙⠦⡀⠀⠀⠀⠀⠀⠀⠀⠀" \
            ;;
        deepin)
            printf '%s\n' \
                "⠀⠀⠀⣠⣴⣶⣿⣿⣿⠟⠲⢦⣄⠀⠀⠀" \
                "⠀⣠⠞⠁⣿⣿⣿⡟⠁⠀⢀⣠⣼⣷⣄⠀" \
                "⢰⠏⠀⠀⣿⣿⡏⢀⡴⣻⠉⡉⠉⠛⠻⡆" \
                "⣿⠀⠀⠀⠹⣿⡀⣯⡾⠋⡼⢸⠀⠀⠀⣿" \
                "⣿⣄⡀⠀⠀⠙⠷⣤⣤⠞⢁⣾⠀⠀⠀⣿" \
                "⠸⣿⣿⣷⣦⣤⣤⣤⣤⣴⣿⠏⠀⠀⣰⠇" \
                "⠀⠙⢿⣿⣿⣿⣿⣿⠿⠛⠁⠀⢀⡴⠋⠀" \
                "⠀⠀⠀⠙⠻⠦⣤⣤⣤⣤⠴⠞⠋⠀⠀⠀" \
            ;;
        elementary)
            printf '%s\n' \
                "⠀⠀⠀⣠⠴⠒⠛⣉⣉⠛⠒⠦⣄⠀⠀⠀" \
                "⠀⣠⠞⠁⢀⠔⠋⠁⠈⠙⢦⠀⠈⠳⣄⠀" \
                "⢰⠃⠀⣰⠏⠀⠀⠀⠀⠀⢸⠀⠀⠀⠘⡆" \
                "⡟⠀⠀⡿⠀⠀⠀⠀⠀⣠⠏⠀⠀⠀⣰⢿" \
                "⣧⠀⠀⣷⠀⠀⠀⣠⠔⠁⠀⠀⢀⡼⠁⣼" \
                "⠸⣄⢀⣘⣷⣴⡚⠁⠀⣀⣤⠞⠋⠀⢠⠇" \
                "⠀⠙⢯⡉⠀⠈⠉⠛⠉⠉⠀⠀⢀⡴⠋⠀" \
                "⠀⠀⠀⠙⠲⠤⣤⣀⣀⣤⠤⠖⠋⠀⠀⠀" \
            ;;
        endeavouros)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⢀⣾⣆⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⣰⠏⣠⣿⣿⣿⣧⠈⢦⡀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⢀⡾⠃⣰⣿⣿⣿⣿⣿⣷⡀⢷⡄⠀⠀" \
                "⠀⠀⠀⠀⣰⡿⠁⣼⣿⣿⣿⣿⣿⣿⣿⣷⠈⢿⣆⠀" \
                "⠀⠀⢠⣾⡿⠁⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢸⣿⡄" \
                "⠀⣴⣿⡟⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢸⣿⣿" \
                "⠚⠿⢏⣀⡈⠉⠛⠛⠛⠛⠛⠛⠛⠛⠛⠋⢁⣼⣿⡿" \
                "⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠿⠿⠛⠛⠉⠀" \
            ;;
        fedora)
            printf '%s\n' \
                "⠀⠀⠀⣀⣴⣶⣿⣿⣿⣿⣶⣦⣀⠀⠀⠀" \
                "⠀⢠⣾⣿⣿⣿⣿⣿⡿⠿⠿⣿⣿⣷⡄⠀" \
                "⢰⣿⣿⣿⣿⣿⣿⠋⢀⣤⣄⠈⣿⣿⣿⡆" \
                "⣿⣿⣿⣿⣿⣿⣿⠀⢸⣿⣿⣶⣿⣿⣿⣿" \
                "⣿⣿⡿⠋⢀⣤⣿⠀⢠⣤⣿⣿⣿⣿⣿⣿" \
                "⣿⣿⡇⠀⣿⣿⡿⠀⣸⣿⣿⣿⣿⣿⣿⠇" \
                "⣿⣿⣷⣄⣈⣉⣀⣴⣿⣿⣿⣿⣿⡿⠃⠀" \
                "⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠟⠉⠀⠀⠀" \
            ;;
        kali)
            printf '%s\n' \
                "⠀⠉⠉⠉⠑⠒⠲⠤⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" \
                "⠉⠉⠉⢉⣉⣩⠭⠭⠽⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" \
                "⠤⠒⠉⠁⠀⠀⠀⠀⢀⡼⠖⠒⠶⢤⣄⡀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⡏⠀⠀⠀⠀⠀⠀⠙⠷⡀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⢧⡀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠲⠶⠶⠦⠤⣤⣄⡀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢎⠑⠄" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠃⠀" \
            ;;
        linuxmint)
            printf '%s\n' \
                "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣄⡀⠀" \
                "⣿⣿⣿⣿⡟⢻⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄" \
                "⠿⠿⣿⣿⡇⢸⣿⡟⠉⡈⠛⢁⠉⢻⣿⣿" \
                "⠀⠀⣿⣿⡇⢸⣿⡇⢸⣿⠀⣿⡇⢸⣿⣿" \
                "⠀⠀⣿⣿⡇⢸⣿⣇⣸⣿⣀⣿⡇⢸⣿⣿" \
                "⠀⠀⣿⣿⡇⠘⠿⠿⠿⠿⠿⠿⠃⢸⣿⣿" \
                "⠀⠀⠘⣿⣿⣶⣶⣶⣶⣶⣶⣶⣶⣿⣿⣿" \
                "⠀⠀⠀⠈⠛⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿" \
            ;;
        macos)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⠇⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⣀⠀⠀⢠⡾⠃⠀⣀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⣿⠀⢀⣾⠁⠀⠀⣿⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠿⠷⢶⡶⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠐⠷⢦⣤⣤⣤⣼⣧⣤⡴⠾⠂⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣧⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡄⠀⠀⠀⠀⠀⠀" \
            ;;
        manjaro)
            printf '%s\n' \
                "⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣦" \
                "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿" \
                "⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿" \
                "⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿" \
                "⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿" \
                "⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿" \
                "⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⣿" \
                "⠻⣿⣿⣿⠀⠀⣿⣿⣿⣿⠀⠀⣿⣿⣿⠟" \
            ;;
        march7th)
            printf '%s\n' \
                "⠀⠀⢠⣶⣿⡿⣷⣦⡀⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⣿⡏⠀⠀⠀⠉⢻⡶⠿⠿⠿⢿⣶⡄" \
                "⠀⠀⣿⡇⠀⢿⣿⡄⠈⢀⣀⣤⠀⠈⣿⣿" \
                "⠀⣀⣼⠷⠄⠈⠻⣿⣴⣿⡿⠛⠀⢠⣿⠇" \
                "⣰⡿⠁⠀⣴⣾⣿⠟⣿⣦⠀⠐⢶⡟⠁⠀" \
                "⣿⣧⠀⠈⠛⠉⠀⠀⠹⣿⡧⠀⢸⣷⠀⠀" \
                "⠘⠿⣷⣶⣶⣶⠾⣦⡀⠀⠀⠀⣼⣿⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠘⠻⢿⣾⣿⠿⠃⠀⠀" \
            ;;
        mx)
            printf '%s\n' \
                "⠀⠀⠀⠀⣠⣾⣦⠀⠀⠀⠀⠀⠀⠀⣠⣾⠆⠀⠀⠀" \
                "⠀⠀⠀⠀⠙⢿⣿⣷⣄⠀⠀⠀⢀⣼⡿⠋⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠻⣿⣿⣧⡀⣰⣿⠟⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⢀⠈⢻⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⣠⣾⣷⣴⡿⢿⣿⣷⣄⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⢀⣾⣿⣿⣿⣿⣧⡈⠻⣿⣿⣦⣴⡀⠀⠀⠀" \
                "⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣄⠈⣿⣿⣿⣿⣦⠀⠀" \
                "⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄" \
            ;;
        nixos)
            printf '%s\n' \
                "⠀⠀⠀⠀⢾⣷⡀⠀⠘⣿⣧⢀⣾⡷⠀⠀⠀⠀" \
                "⠀⠀⢠⣤⣤⣿⣿⣤⣄⠘⣿⣿⡟⠁⠀⡀⠀⠀" \
                "⠀⠀⠛⠛⠛⠛⠛⠛⠛⠂⠘⢿⡷⠀⣼⣿⠀⠀" \
                "⣠⣤⣤⣤⣾⡿⠁⠀⠀⠀⠀⠈⢁⣼⣿⣧⣤⣄" \
                "⠙⠛⢻⣿⡟⢁⡀⠀⠀⠀⠀⢀⣾⡿⠛⠛⠛⠋" \
                "⠀⠀⣿⡟⠀⢾⣷⡄⠠⣤⣤⣤⣤⣤⣤⣤⠀⠀" \
                "⠀⠀⠈⠀⠀⣼⣿⣿⡄⠙⠛⣿⣿⠛⠛⠃⠀⠀" \
                "⠀⠀⠀⠀⢾⡿⠁⢻⣿⡄⠀⠈⢿⡷⠀⠀⠀⠀"
            ;;
        windows10)
            printf '%s\n' \
                "⠀⠀⠀⢀⣀⣀⡀⢠⣤⣤⣤⣶⣶⣶⣿⣿" \
                "⣿⣿⣿⣿⣿⣿⡇⢸⣿⣿⣿⣿⣿⣿⣿⣿" \
                "⣿⣿⣿⣿⣿⣿⡇⢸⣿⣿⣿⣿⣿⣿⣿⣿" \
                "⠿⠿⠿⠿⠿⠿⠇⠸⠿⠿⠿⠿⠿⠿⠿⠿" \
                "⣶⣶⣶⣶⣶⣶⡆⢰⣶⣶⣶⣶⣶⣶⣶⣶" \
                "⣿⣿⣿⣿⣿⣿⡇⢸⣿⣿⣿⣿⣿⣿⣿⣿" \
                "⣿⣿⣿⣿⣿⣿⡇⢸⣿⣿⣿⣿⣿⣿⣿⣿" \
                "⠀⠀⠀⠈⠉⠉⠁⠘⠛⠛⠛⠿⠿⠿⣿⣿" \
            ;;
        opensuse)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⠀⠀⣀⣠⣴⣶⣶⣿⣿⣿⣿⣿⣿⣿⣶⣶⣦⣤⣰⣶⣶⣤⣤⣀⡀⠀⠀" \
                "⠀⠀⠀⠀⣠⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢫⡤⢍⢳⡀" \
                "⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣟⠿⣷⡘⠿⢋⣼⣧" \
                "⢀⣾⣿⣿⠿⠿⠿⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⣍⣙⣛⣩⡥" \
                "⣼⣿⠟⢁⣤⣶⣶⣤⡀⠙⢿⣿⣿⣿⡿⠿⠿⢿⣿⣿⣿⣿⠟⠛⠛⠛⠛⠛⠛⠋⠁⠀" \
                "⣿⣿⠀⢸⣿⣁⡈⠹⣿⡆⠀⢻⣿⡏⠀⠀⠀⠀⠈⠻⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" \
                "⠹⣿⣧⣈⠛⠛⠋⣠⣿⠇⠀⠈⠙⠃⠀⠀⠀⠀⠀⠀⠈⠛⠧⠀⠀⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠈⠻⠿⣿⣿⣿⠿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀" \
            ;;
        redhat)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⢠⣾⣶⣤⣾⣿⣶⣦⣄⡀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀" \
                "⠀⠀⠀⣀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀" \
                "⣴⣿⣿⣿⡀⠈⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀" \
                "⢿⣿⣿⣿⣿⣦⡀⠀⠈⠉⠛⠛⠛⠛⠛⠋⠀⣷⣄⠀" \
                "⠀⠻⣿⣿⣿⣿⣿⣷⣶⣤⣄⣀⣀⣀⣀⣤⣾⣿⣿⣷" \
                "⠀⠀⠀⠙⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿" \
                "⠀⠀⠀⠀⠀⠀⠈⠙⠛⠿⠿⣿⣿⣿⣿⣿⡿⠿⠋⠀" \
            ;;
        ubuntu)
            # 为了视觉上的平衡所以右侧空两格
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⠠⣾⣿⣦⠀⠀⠀" \
                "⠀⠀⠀⠀⢀⣤⡘⢿⡿⠿⣿⣧⣙⣛⡁⠀⠀⠀" \
                "⠀⠀⠀⣰⣿⡿⠃⠀⠀⠀⠀⠈⠙⣿⣿⡄⠀⠀" \
                "⣴⣶⣦⢻⣿⠁⠀⠀⠀⠀⠀⠀⠀⠘⠿⠿⠀⠀" \
                "⠻⠿⠟⣼⣿⡀⠀⠀⠀⠀⠀⠀⠀⢠⣶⣶⠀⠀" \
                "⠀⠀⠀⠹⣿⣷⡄⠀⠀⠀⠀⢀⣠⣿⣿⠃⠀⠀" \
                "⠀⠀⠀⠀⠈⠛⢡⣾⣷⣶⣿⡟⣩⣭⡁⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠐⢿⣿⠟⠀⠀⠀" \
            ;;
        void)
            printf '%s\n' \
                "⠀⠀⠀⢀⣤⣶⣿⣿⣿⣿⣶⣤⣀⠀⠀⠀" \
                "⠀⢀⠀⠀⠙⠛⠋⠉⠉⠙⠻⢿⣿⣷⡄⠀" \
                "⢠⣿⣷⠀⠀⠀⠀⣀⣀⠀⠀⠀⠹⣿⣿⡄" \
                "⣿⣿⡏⠀⠀⢠⣿⣿⣿⣿⡄⠀⠀⢹⣿⣿" \
                "⣿⣿⣇⠀⠀⠘⣿⣿⣿⣿⠃⠀⠀⣸⣿⣿" \
                "⠘⣿⣿⣆⠀⠀⠀⠉⠉⠀⠀⠀⠀⢿⣿⠃" \
                "⠀⠘⢿⣿⣷⣦⣄⣀⣀⣠⣤⣄⠀⠀⠁⠀" \
                "⠀⠀⠀⠉⠛⠿⣿⣿⣿⣿⠿⠛⠁⠀⠀⠀" \
            ;;
        zorin)
            printf '%s\n' \
                "⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠀⠀⠀" \
                "⠀⠀⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀⠀⠀" \
                "⠀⢀⣀⣀⣀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⡀⠀" \
                "⣰⣿⣿⣿⣿⣿⣿⠟⠋⠁⠀⠀⢀⣤⣶⣿⣿⣆" \
                "⠹⣿⣿⠿⠛⠁⠀⠀⢀⣠⣴⣾⣿⣿⣿⣿⣿⠏" \
                "⠀⠈⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠀" \
                "⠀⠀⠀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⠀⠀⠀" \
                "⠀⠀⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀⠀" \
            ;;
        *)
            printf '%s\n' \
                "⠀⠀⠀⠀⠀⣠⣶⣿⣿⣿⣿⣶⣄⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⣼⣿⣿⠟⠉⠉⠻⣿⣿⣷⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠛⠛⠛⠀⠀⠀⢀⣿⣿⡿⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣿⣿⠟⠁⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⠏⠁⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⣴⣶⣶⡄⠀⠀⠀⠀⠀⠀⠀" \
                "⠀⠀⠀⠀⠀⠀⠀⠻⣿⡿⠃⠀⠀⠀⠀⠀⠀⠀"
            ;;
    esac
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
    first_line=$(printf '%s\n' "$OS_LOGO" | head -n1) # 寬度獲取的是第一行，所以第一行的寬度必須和圖標最寬的地方一樣寬，推薦所有行寬度一樣
    bytes=$(printf '%s' "$first_line" | wc -c)
    printf '%d\n' $((bytes / 3)) # LANG 爲 C 的情況下，一個盲文字符長度是 3
}

draw_table() {
    get_cpu > $NULLFILE 2>&1 && DEVICE_LINES=$((DEVICE_LINES + 1))
    get_gpu > $NULLFILE 2>&1 && DEVICE_LINES=$((DEVICE_LINES + 1))
    get_mem > $NULLFILE 2>&1 && DEVICE_LINES=$((DEVICE_LINES + 1))
    [ "$DEVICE_LINES" -gt 0 ] && DEVICE_LINES=$((DEVICE_LINES + 2))
    [ "$DEVICE_LINES" -eq 0 ] && DEVICE_LINES=$((DEVICE_LINES - 1))

    logo_table_width=$((LOGO_WIDTH + 4))
    logo_table_dash=$(repeat_char "-" $logo_table_width)
    sys_info_dash=$(repeat_char "-" 35)
    
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
    table_up="$(printf "|  \033[%dG  |  \033[31C  |" $logo_table_width)"
    repeat_line 10 "$table_up"

    # 打印表格一二部分中间 +-- ... --+-- ... --+
    printf "+%s+%s+\n" "$logo_table_dash" "$sys_info_dash"

    # 打印第而个部分内容区域 | ...... |
    table_down="$(printf "|  \033[%dG     \033[31C  |" $logo_table_width)"
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
    right_text=$(printf "%s" "$5" | upper | tr '-' '_')
    max_len=$6

    printf "\033[u\033[%dB\033[%dG%s\033[%dG: %.${max_len}s" "$row" "$left_col" "$left_text" "$right_col" "$right_text"
}

fill_info() {
    printf "\033[0m"

    left_col=$((LOGO_WIDTH + 9))
    right_col=$((LOGO_WIDTH + 9 + 9))

    sys_info_max_len=21
    dev_info_max_len=$((LOGO_WIDTH + 30))

    line=2
    if v=$(get_os_name 2> $NULLFILE);         then _print_info $line "$left_col" "SYSTEM"   "$right_col" "$v"          $sys_info_max_len; line=$((line+1)); fi
    if v=$(get_host_name 2> $NULLFILE);       then _print_info $line "$left_col" "HOST"     "$right_col" "$v"          $sys_info_max_len; line=$((line+1)); fi
    if v=$(get_kernel 2> $NULLFILE);          then _print_info $line "$left_col" "KERNEL"   "$right_col" "$(uname) $v" $sys_info_max_len; line=$((line+1)); fi
    if v=$(get_package_manager 2> $NULLFILE); then _print_info $line "$left_col" "PACKAGE"  "$right_col" "$v"          $sys_info_max_len; line=$((line+1)); fi
    if v=$(get_uptime 2> $NULLFILE);          then _print_info $line "$left_col" "UPTIME"   "$right_col" "$v"          $sys_info_max_len; line=$((line+1)); fi
    if v=$(get_platform 2> $NULLFILE);        then _print_info $line "$left_col" "PLATFORM" "$right_col" "$v"          $sys_info_max_len; line=$((line+1)); fi
    if v=$(get_de 2> $NULLFILE);              then _print_info $line "$left_col" "DESKTOP"  "$right_col" "$v"          $sys_info_max_len; line=$((line+1)); fi
    if v=$(get_shell 2> $NULLFILE);           then _print_info $line "$left_col" "SHELL"    "$right_col" "$v"          $sys_info_max_len; line=$((line+1)); fi

    line=13
    if v=$(get_cpu 2> $NULLFILE); then _print_info $line 4 "CPU" 8 "$v" $dev_info_max_len; line=$((line+1)); fi
    if v=$(get_gpu 2> $NULLFILE); then _print_info $line 4 "GPU" 8 "$v" $dev_info_max_len; line=$((line+1)); fi
    if v=$(get_mem 2> $NULLFILE); then _print_info $line 4 "RAM" 8 "$v" $dev_info_max_len; line=$((line+1)); fi
}

reset_cursor_to_end() {
    printf "\033[u\033[18B"
    printf "\033[0m"
}

LOGO_OVERRIDE=""

while getopts ":l:h" opt; do
    case "$opt" in
        l)
            LOGO_OVERRIDE="$OPTARG"
            ;;
        h)
            echo "Usage: $0 [-l <logo-name>]"
            exit 0
            ;;
        :)
            echo "Error: -$OPTARG 缺少参数" >&2
            exit 1
            ;;
        \?)
            echo "未知的选项: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

OS_RELEASE_FILE=$(get_os_release_file)
if [ -n "$OS_RELEASE_FILE" ]; then
    OS_RELEASE=$(cat "$OS_RELEASE_FILE")
else
    OS_RELEASE=""
fi

OS_ID=$(get_os_id)
OS_LOGO=$(get_logo)
LOGO_WIDTH=$(get_logo_width)
DEVICE_LINES=0

draw_table
fill_title
fill_logo
fill_info
reset_cursor_to_end
