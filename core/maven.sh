#!/bin/bash

configure_profiles_cmd() {
    local name=$1
    if [ -z "$name" ]; then
        projects=($(ls -d $SOURCE_DIR/projects/*/ 2>/dev/null | xargs -n1 basename))
        if [ ${#projects[@]} -eq 0 ]; then
            echo "Erro: Nenhum projeto configurado." && exit 1
        fi
        echo "Selecione o projeto:"
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
    local goal=$4
    local skip_tests=$5
    shift 5
    local extra_args="$@"
    cd "$repo"
    echo "Executando: mvn clean $goal ${profiles:+-P $profiles} $skip_tests $extra_args"
    $mvn_bin clean $goal ${profiles:+-P $profiles} $skip_tests $extra_args
}

deploy_war() {
    local repo=$1; local runtime_dir=$2
    if [ -z "$repo" ] || [ "$repo" == "/" ]; then echo "Erro: Caminho invalido"; exit 1; fi
    local war_path=$(find "$repo" -name "*.war" -path "*/target/*" -not -path "*/.*" 2>/dev/null | head -n 1)
    [ -z "$war_path" ] && echo "Erro: .war nao encontrado em modules target" && exit 1
    local war_name=$(basename "$war_path")
    cp "$war_path" "$runtime_dir/deployments/$war_name"
    touch "$runtime_dir/deployments/$war_name.dodeploy"
    echo "$war_name"
}

deploy_exploded() {
    local repo=$1; local runtime_dir=$2
    if [ -z "$repo" ] || [ "$repo" == "/" ]; then echo "Erro: Caminho invalido"; exit 1; fi
    local target_dir=$(find "$repo" -maxdepth 4 -type d -name "WEB-INF" -path "*/target/*" 2>/dev/null | sed 's|/WEB-INF||' | head -n 1)
    if [ -z "$target_dir" ] || [[ "$target_dir" != "$repo"* ]]; then
        echo -e "\e[31mErro: Nao foi possivel localizar a pasta explodida do WAR em $repo\e[0m"; exit 1
    fi
    local artifact_name=$(basename "$target_dir")
    local deploy_path="$runtime_dir/deployments/$artifact_name.war"
    mkdir -p "$deploy_path"
    echo "Sincronizando artifactId [$artifact_name] para o runtime..."
    cp -r "$target_dir/"* "$deploy_path/"
    touch "$deploy_path.dodeploy"
}

watch_sync_logic() {
    local repo=$1; local mvn=$2; local run_dir=$3; local name=$4; local profs=$5
    local deploy_path=$(ls -d "$run_dir/deployments"/*.war 2>/dev/null | head -n 1)
    [ -z "$deploy_path" ] && return
    local marker="/tmp/wf-watch-marker-$(id -u)-$name"
    [ ! -f "$marker" ] && touch -d "5 seconds ago" "$marker"
    local changes=$(find "$repo" -type f -newer "$marker" -not -path '*/.*' -not -path "*/target/*" 2>/dev/null)
    touch "$marker"
    [ -z "$changes" ] && return
    local need_redeploy=false
    for file in $changes; do
        if [[ "$file" == *.java ]]; then
            need_redeploy=true
        elif [[ "$file" == *.xhtml ]] || [[ "$file" == *.js ]] || [[ "$file" == *.css ]] || [[ "$file" == *.xml ]]; then
            local rel_path=$(echo "$file" | sed 's|.*/src/main/webapp/||')
            if [ "$file" != "$rel_path" ]; then
                mkdir -p "$(dirname "$deploy_path/$rel_path")"
                cp "$file" "$deploy_path/$rel_path"
                echo -e "  \e[32m[HOT SYNC]\e[0m $rel_path"
            fi
        fi
    done
    if [ "$need_redeploy" = true ]; then
        echo -e "  \e[34m[HOT RELOAD] Recompilando...\e[0m"
        $mvn compile ${profs:+-P $profs} -DskipTests
        find "$repo" -type d -path "*/target/classes" 2>/dev/null | while read classes_dir; do
            cp -r "$classes_dir/"* "$deploy_path/WEB-INF/classes/" 2>/dev/null
        done
        touch "$deploy_path.dodeploy"
    fi
}

watch_loop() {
    local repo=$1; local mvn=$2; local run=$3; local name=$4; local profs=$5
    rm -f "/tmp/wf-watch-marker-$(id -u)-$name"
    while true; do
        sleep 4
        watch_sync_logic "$repo" "$mvn" "$run" "$name" "$profs"
    done
}