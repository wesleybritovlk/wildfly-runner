#!/bin/bash

configure_profiles_cmd() {
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
    if [ -z "$name" ]; then
        echo -e "\e[31mErro: Nenhum projeto selecionado. Uso: wf profiles [nome]\e[0m"
        return 1
    fi
    local p_dir="$SOURCE_DIR/projects/$name"
    [ ! -d "$p_dir" ] && echo "Erro: Projeto nao existe" && return 1
    source "$p_dir/.engine-versions"
    local repo_path=$(cat "$p_dir/.repo-path")
    configure_profiles "$p_dir" "$repo_path" "$MVN_PATH"
}

configure_profiles() {
    local p_dir=$1
    local repo=$2
    local mvn_bin=$3
    cd "$repo"
    echo "Lendo profiles disponíveis no projeto..."
    $mvn_bin help:all-profiles | grep "Profile Id:" | sort -u
    echo ""
    read -p "Digite os profiles desejados separados por virgula: " selected
    [ ! -z "$selected" ] && echo "$selected" | tr ',' ' ' | xargs > "$p_dir/.profiles"
    echo "Profiles salvos em $p_dir/.profiles"
}

check_maven_profiles() {
    local repo=$1
    local profiles=$2
    local mvn_bin=$3
    cd "$repo"
    echo "Verificando ativação de profiles..."
    local output=$($mvn_bin help:all-profiles ${profiles:+-P $profiles} | grep "Profile Id:" | sort -u)
    IFS=',' read -ra PROFS <<< "$profiles"
    for p in "${PROFS[@]}"; do
        p=$(echo "$p" | xargs)
        [ -z "$p" ] && continue
        if echo "$output" | grep -qP "Profile Id: $p \(Active: true"; then
            echo "  - Profile [$p]: ACTIVE ✅"
        else
            echo "  - Profile [$p]: INACTIVE ❌"
        fi
    done
}

build_project() {
    local repo=$1
    local profiles=$2
    local mvn_bin=$3
    cd "$repo"
    $mvn_bin clean install ${profiles:+-P $profiles} -DskipTests
}

deploy_war() {
    local war_path=$(find "$1" -name "*.war" -path "*/target/*" | head -n 1)
    [ -z "$war_path" ] && echo "Erro: .war nao encontrado" && exit 1
    local war_name=$(basename "$war_path")
    cp "$war_path" "$2/deployments/$war_name"
    touch "$2/deployments/$war_name.dodeploy"
    echo "$war_name"
}