#!/bin/sh

LANG=C
NULLFILE=/dev/null

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
        printf "%s" "$OS_RELEASE" | grep '^ID=' | cut -d= -f2 | tr -d '"'
    else
        printf "" # 待实现
    fi
}

get_os_name() {
    if [ "$(uname)" = "Linux" ]; then
        printf "%s" "$OS_RELEASE" | grep '^PRETTY_NAME=' | cut -d= -f2 | tr -d '"()'
    else
        printf "" # 待实现
    fi
}

get_arch() {
    uname -m
}

is_android() {
    uname -o 2> $NULLFILE | grep -q "Android" && return 0

    [ "$(uname)" = "Linux" ] || return 1

    if command -v getprop > $NULLFILE; then
        build_sdk=$(getprop ro.build.version.sdk 2> $NULLFILE)
        if [ -n "$build_sdk" ] 2> $NULLFILE; then
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
        if command -v hostnamectl > $NULLFILE; then
            hostnamectl | grep 'Hardware Model' | cut -d':' -f2 | xargs
        elif [ -f /sys/devices/virtual/dmi/id/product_name ]; then
            cat /sys/devices/virtual/dmi/id/product_name
            return 0
        fi
    else
        printf "" # 待实现
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
    fi
}

get_shell_path() {
    if command -v getent > $NULLFILE; then
        getent passwd "$(id -un)" | cut -d: -f7
    else
        grep "^$(whoami):" /etc/passwd | cut -d: -f7
    fi
}

get_shell() {
    shell_path=$(get_shell_path)
    basename "$shell_path"
}

get_de() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        printf "%s" "$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        printf "%s" "$DESKTOP_SESSION"
    elif [ -n "$GDMSESSION" ]; then
        printf "%s" "$GDMSESSION"
    fi
}

get_package_manager() {
    managers="apt dnf rpm pacman pkg eopkg nix-env yum zypper dpkg-install pm port pacstall emerge cave yay brew flatpak"
    found=""

    for m in $managers; do
        if command -v "$m" > $NULLFILE; then
            found="$found $m"
        fi
    done

    found="${found# }"

    if [ -n "$found" ]; then
        printf "%s\n" "$found"
    fi
}

get_cpu() {
    if [ "$(uname)" = "Linux" ]; then
        if command -v lscpu > $NULLFILE; then
            model="$(lscpu 2> $NULLFILE | sed -n 's/^[[:space:]]*Model name:[[:space:]]*//p' | awk 'NR>1{printf ", "} {printf "%s", $0} END{print ""}')"
            cores="$(lscpu 2> $NULLFILE | sed -n 's/^[[:space:]]*CPU(s):[[:space:]]*//p' | head -n 1)"

            printf "%s (%s)" "$model" "$cores"
            return 0
        elif [ -f /proc/cpuinfo ]; then
            model="$(sed -nE 's/^(model name|Hardware)[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -n1)"
            cores="$(grep -c '^processor' /proc/cpuinfo)"

            if is_android && [ -z "$model" ]; then
                model=$(getprop ro.soc.model)
            fi

            printf "%s (%s)" "$model" "$cores"
            return 0
        fi
    else
        printf "" # 待实现
    fi
}

get_gpu() {
    if command -v nvidia-smi > $NULLFILE; then
        nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2> $NULLFILE
    else
        printf "" # 待实现
    fi
}

get_meminfo() {
    mem_kb=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
    mem_gib=$(awk "BEGIN {printf \"%.1f\", $mem_kb / 1024 / 1024}")

    printf "%s GiB" "$mem_gib"
}

get_logo() {
    if [ -n "$LOGO_OVERRIDE" ]; then
        logo=$(printf '%s' "$LOGO_OVERRIDE" | tr '[:upper:]' '[:lower:]')
    else
        logo=$(printf '%s' "$OS_ID" | tr '[:upper:]' '[:lower:]')
    fi

    case $logo in
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
    first_line=$(printf '%s\n' "$OS_LOGO" | head -n1)
    bytes=$(printf '%s' "$first_line" | wc -c)
    printf '%d\n' $((bytes / 3)) # LANG 爲 C 的情況下，一個盲文字符長度是 3
}

draw_table() {
    logo_table_width=$((LOGO_WIDTH + 4))
    logo_table_dash=$(repeat_char "-" $logo_table_width)
    sys_info_dash=$(repeat_char "-" 35)
    
    printf "\033[0m"

    # 防止距离底部不足表格的高度打印后换行导致 esc[s 存储的位置错误
    repeat_char "\n" 18 #
    printf "\033[18A"

    printf "\033[s"
    
    # 打印表格第一个部分顶部 +-- ... --+-- ... --+
    printf "+%s+%s+\n" "$logo_table_dash" "$sys_info_dash"

    # 打印第一个部分内容区域 | ... | ... | 共十行
    # 设计之初为了 logo 的美观等，所有的 logo 高度都是 8 宽度不定，上下各空两行，至于为什么是 8 因为盲文 logo > 8 会有密集恐惧症（
    table_up="$(printf "|  \033[%dG  |  \033[31C  |" $logo_table_width)"
    repeat_line 10 "$table_up"

    # 打印表格一二部分中间 +-- ... --+-- ... --+
    printf "+%s+%s+\n" "$logo_table_dash" "$sys_info_dash"

    # 打印第而个部分内容区域 | ...... | 共五行
    table_down="$(printf "|  \033[%dG     \033[31C  |" $logo_table_width)"
    repeat_line 5 "$table_down"

    # 打印表格底部 +-- ...... --+
    printf "+%s-%s+\n" "$logo_table_dash" "$sys_info_dash"
}

_print_title() {
    row=$1
    col=$2
    text=$3

    printf "\033[u\033[2m\033[%dB\033[%dC%s" "$row" "$col" "$text"
}

fill_title() {
    printf "\033[0m"

    _print_title 10 $((LOGO_WIDTH)) "LOGO"
    _print_title 10 $((LOGO_WIDTH + 29)) "SYSTEM INFO"
    _print_title 16 $((LOGO_WIDTH + 29)) "DEVICE INFO"

    printf "\033[0m"
}

fill_logo() {
    printf "\033[0m\033[u\033[2B"
    printf "%s\n" "$OS_LOGO" | while read -r line; do
        printf "\033[4G%s\n" "$line"
    done
}

fill_info() {
    printf "\033[0m"

    _print_info() {
        row=$1
        left_col=$2
        left_text="$3"
        right_col=$4
        right_text=$(printf "%s" "$5" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        max_len=$6

        printf "\033[u\033[%dB\033[%dG%s\033[%dG: %.${max_len}s" "$row" "$left_col" "$left_text" "$right_col" "$right_text"
    }

    left_col=$((LOGO_WIDTH + 9))
    right_col=$((LOGO_WIDTH + 9 + 9))
    max_len=21
    _print_info 2 "$left_col" "SYSTEM" "$right_col" "$(get_os_name)" "$max_len"
    _print_info 3 "$left_col" "PLATFORM" "$right_col" "$(get_platform)" "$max_len"
    _print_info 4 "$left_col" "HOST" "$right_col" "$(get_host_name)" "$max_len"
    _print_info 5 "$left_col" "KERNEL" "$right_col" "$(uname) $(get_kernel)" "$max_len"
    _print_info 6 "$left_col" "UPTIME" "$right_col" "$(get_uptime)" "$max_len"
    _print_info 7 "$left_col" "SHELL" "$right_col" "$(get_shell)" "$max_len"
    _print_info 8 "$left_col" "DESKTOP" "$right_col" "$(get_de)" "$max_len"
    _print_info 9 "$left_col" "PACKAGE" "$right_col" "$(get_package_manager)" "$max_len"

    _print_info 13 4 "CPU" 8 "$(get_cpu)" 47
    _print_info 14 4 "GPU" 8 "$(get_gpu)" 47
    _print_info 15 4 "RAM" 8 "$(get_meminfo)" 47
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

draw_table
fill_title
fill_logo
fill_info
reset_cursor_to_end
