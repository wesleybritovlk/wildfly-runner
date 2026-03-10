#!/bin/bash

list_projects() {
    echo -e "\n\e[1;34mPROJETOS CONFIGURADOS:\e[0m"
    printf "%-15s | %-12s | %-12s | %-12s | %-20s\n" "NOME" "JAVA" "MAVEN" "WILDFLY" "REPOSITORIO"
    echo "----------------------------------------------------------------------------------------------------------------"
    for p_dir in "$SOURCE_DIR/projects"/*; do
        [ ! -d "$p_dir" ] && continue
        name=$(basename "$p_dir")
        JAVA_VER="N/A"; MVN_PATH="N/A"; WF_SELECTED_VER="N/A"
        source "$p_dir/.engine-versions" 2>/dev/null
        repo_path=$(cat "$p_dir/.repo-path" 2>/dev/null)
        [ -z "$repo_path" ] && continue
        mvn_v=$(echo $MVN_PATH | grep -oP 'maven-\K[0-9.]+' || echo "N/A")
        printf "%-15s | %-12s | %-12s | %-12s | %-20s\n" "$name" "$JAVA_VER" "$mvn_v" "$WF_SELECTED_VER" "$repo_path"
    done
    echo ""
}

update_project() {
    local name=$1
    if [ -z "$name" ]; then
        projects=($(ls -d $SOURCE_DIR/projects/*/ 2>/dev/null | xargs -n1 basename))
        if [ ${#projects[@]} -eq 0 ]; then
            echo "Erro: Nenhum projeto configurado." && exit 1
        fi
        echo "Selecione o projeto para rodar:"
        for i in "${!projects[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${projects[$i]}"; done
        read -p "Escolha (1): " choice
        choice=${choice:-1}
        name=${projects[$((choice-1))]}
    fi
    local p_dir="$SOURCE_DIR/projects/$name"
    [ ! -d "$p_dir" ] && echo "Erro: Projeto nao existe" && exit 1
    echo "--- Atualizando projeto: $name ---"
    install_engines "$name"
    setup_repository "$name" "$p_dir"
    source "$p_dir/.engine-versions"
    REPO_PATH=$(cat "$p_dir/.repo-path")
    configure_profiles "$p_dir" "$REPO_PATH" "$MVN_PATH"
    echo "Projeto $name atualizado com sucesso!"
}

remove_project() {
    local name=$1
    if [ -z "$name" ]; then
        projects=($(ls -d $SOURCE_DIR/projects/*/ 2>/dev/null | xargs -n1 basename))
        if [ ${#projects[@]} -eq 0 ]; then
            echo "Erro: Nenhum projeto configurado." && exit 1
        fi
        echo "Selecione o projeto para rodar:"
        for i in "${!projects[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${projects[$i]}"; done
        read -p "Escolha (1): " choice
        choice=${choice:-1}
        name=${projects[$((choice-1))]}
    fi
    local p_dir="$SOURCE_DIR/projects/$name"
    [ ! -d "$p_dir" ] && echo "Erro: Projeto nao existe" && exit 1
    local repo_path=$(cat "$p_dir/.repo-path")
    read -p "Deseja remover tambem a pasta do codigo fonte em $repo_path? (s/N): " del_repo
    rm -rf "$p_dir"
    if [[ "${del_repo,,}" == "s" ]]; then
        rm -rf "$repo_path"
        echo "Projeto e repositorio removidos."
    else
        echo "Configuracoes removidas. Repositorio mantido em $repo_path"
    fi
}

show_status() {
    local target=$1
    local uid=$(id -u)
    printf "\n\033[1;34mSTATUS DOS SERVICOS EM EXECUCAO (UID: $uid):\033[0m\n"
    printf "%-15s | %-7s | %-7s | %-7s | %-7s | %-10s | %-30s\n" "PROJETO" "PID" "OFFSET" "PORTA" "DEBUG" "MODO" "URL PRINCIPAL"
    echo "----------------------------------------------------------------------------------------------------------------------------"
    while read -r line; do
        [ -z "$line" ] && continue
        pid=$(echo "$pid" | awk '{print $2}')
        pid=$(echo "$line" | awk '{print $2}')
        base_dir=$(echo "$line" | grep -oP '(?<=jboss\.server\.base\.dir=)[^ ]+')
        mode="RUN"
        [[ "$base_dir" == *"/wf-watch-"* ]] && mode="WATCH"
        p_name=$(basename "$base_dir")
        [ -z "$p_name" ] && continue
        [ -n "$target" ] && [ "$target" != "$p_name" ] && continue
        local repo_path=$(cat "$SOURCE_DIR/projects/$p_name/.repo-path" 2>/dev/null)
        local ctx=""
        local target_dir=$(find "$repo_path" -maxdepth 4 -type d -name "WEB-INF" -path "*/target/*" 2>/dev/null | sed 's|/WEB-INF||' | head -n 1)
        if [ -n "$target_dir" ]; then
            ctx=$(basename "$target_dir")
        else
            local war_path=$(find "$repo_path" -name "*.war" -path "*/target/*" -not -path "*/.*" 2>/dev/null | head -n 1)
            ctx=$(basename "$war_path" .war)
        fi
        offset=$(echo "$line" | grep -oP '(?<=port-offset=)[0-9]+' || echo "0")
        port=$((8080 + offset))
        is_debug="False"
        [[ "$line" == *"-agentlib:jdwp"* ]] && is_debug="True"
        if [ -z "$ctx" ] || [ "$ctx" == "ROOT" ]; then 
            url="http://localhost:$port/"
        else 
            url="http://localhost:$port/$ctx"
        fi
        printf "%-15s | %-7s | %-7s | %-7s | %-7s | %-10s | %-30s\n" "$p_name" "$pid" "$offset" "$port" "$is_debug" "$mode" "$url"
        if [ -n "$target" ]; then
            mgmt=$((9990 + offset))
            https=$((8443 + offset))
            debug_port=$(echo "$line" | grep -oP '(?<=address=)[0-9]+' || echo "N/A")
            printf "    └── Detalhes: HTTPS: $https | MGMT: $mgmt | DEBUG: $debug_port | PATH: $base_dir\n"
        fi
    done < <(ps aux | grep "jboss.server.base.dir=/tmp/wf-" | grep -v grep)
    printf "\n"
}