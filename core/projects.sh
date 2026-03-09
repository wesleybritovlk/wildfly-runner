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
    echo -e "\n\e[1;34mSTATUS DOS SERVICOS EM EXECUCAO:\e[0m"
    printf "%-15s | %-7s | %-7s | %-7s | %-7s | %-30s\n" "PROJETO" "PID" "OFFSET" "PORTA" "DEBUG" "URL PRINCIPAL"
    echo "----------------------------------------------------------------------------------------------------------------"
    while read -r line; do
        [ -z "$line" ] && continue
        pid=$(echo "$line" | awk '{print $2}')
        p_name=$(echo "$line" | grep -oP '(?<=jboss\.server\.base\.dir=/tmp/wf-run/)[^ /]+' | head -n 1)
        [ -z "$p_name" ] && continue
        [ -n "$target" ] && [ "$target" != "$p_name" ] && continue

        offset=$(echo "$line" | grep -oP '(?<=port-offset=)[0-9]+' || echo "0")
        port=$((8080 + offset))
        is_debug="False"
        [[ "$line" == *"-agentlib:jdwp"* ]] && is_debug="True"

        war_name=$(ls /tmp/wf-run/$p_name/deployments/*.war 2>/dev/null | head -n 1 | xargs basename 2>/dev/null || echo "")
        ctx=${war_name%.war}
        [ -z "$ctx" ] || [ "$ctx" == "ROOT" ] && url="http://localhost:$port/" || url="http://localhost:$port/$ctx"

        printf "%-15s | %-7s | %-7s | %-7s | %-7s | %-30s\n" "$p_name" "$pid" "$offset" "$port" "$is_debug" "$url"
        if [ -n "$target" ]; then
            mgmt=$((9990 + offset))
            ajp=$((8009 + offset))
            https=$((8443 + offset))
            debug_port=$(echo "$line" | grep -oP '(?<=address=)[0-9]+' || echo "N/A")
            echo -e "   └── Detalhes de Portas: HTTP: $port | HTTPS: $https | MGMT: $mgmt | AJP: $ajp | DEBUG: $debug_port"
        fi
    done < <(ps aux | grep "jboss.server.base.dir=/tmp/wf-run/" | grep -v grep)
    echo ""
}