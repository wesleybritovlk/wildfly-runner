#!/bin/bash
get_offset() {
    local off=$(grep "port-offset" "$1" | sed -n 's/.*port-offset="\${[^:]*:\([^}]*\)}".*/\1/p')
    echo ${off:-0}
}

find_free_port() {
    local port=$1
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; do ((port++)); done
    echo $port
}