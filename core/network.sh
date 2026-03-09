#!/bin/bash
find_dynamic_offset() {
    local xml=$1
    local debug_mode=$2
    local ports=($(grep -oP 'port="(\$\{.*?:)?\K[0-9]+' "$xml"))
    [ "$debug_mode" = true ] && ports+=("8687")
    local offset=0
    while true; do
        local conflict=false
        for p in "${ports[@]}"; do
            local check_port=$((p + offset))
            if lsof -Pi :$check_port -sTCP:LISTEN -t >/dev/null ; then
                conflict=true
                break
            fi
        done
        if [ "$conflict" = false ]; then
            echo $offset
            return 0
        fi
        ((offset++))
    done
}

get_offset() {
    local off=$(grep "port-offset" "$1" | sed -n 's/.*port-offset="\${[^:]*:\([^}]*\)}".*/\1/p')
    echo ${off:-0}
}

find_free_port() {
    local port=$1
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; do ((port++)); done
    echo $port
}