#!/bin/bash
setup_structure() {
    mkdir -p "$SOURCE_DIR"/{bin,core,engines,projects,templates}
    [ ! -f "$SOURCE_DIR/global.jvm" ] && echo "-Xms2048m -Xmx2048m -Dfile.encoding=UTF-8" > "$SOURCE_DIR/global.jvm"
    [ ! -f "$SOURCE_DIR/templates/.env.example" ] && echo "VAR_NAME=value" > "$SOURCE_DIR/templates/.env.example"
    [ ! -f "$SOURCE_DIR/templates/.profiles.example" ] && echo "default" > "$SOURCE_DIR/templates/.profiles.example"
}

install_engines() {
    local name=$1
    local p_dir="$SOURCE_DIR/projects/$name"
    local mvn_path=""
    local WF_SELECTED_VER=""

    local existing_mvns=($(ls -d $SOURCE_DIR/engines/maven-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/maven-||"))
    if [ ${#existing_mvns[@]} -gt 0 ]; then
        echo "Mavens encontrados em engines/:"
        for i in "${!existing_mvns[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${existing_mvns[$i]}"; done
        read -p "Escolha um Maven da engine ou 'n' para novo (1): " choice
        choice=${choice:-1}
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#existing_mvns[@]}" ]; then
            MVN_SELECTED_VER="${existing_mvns[$((choice-1))]}"
            mvn_path="$SOURCE_DIR/engines/maven-$MVN_SELECTED_VER/bin/mvn"
        fi
    fi

    if [ -z "$mvn_path" ]; then
        local sys_mvn=$(command -v mvn)
        if [ ! -z "$sys_mvn" ]; then
            local mvn_v_str=$($sys_mvn -version | head -n 1)
            read -p "Maven sistema detectado: ($mvn_v_str). Usar? (S/n): " choice
            choice=${choice:-s}
            [ "${choice,,}" == "s" ] && mvn_path="$sys_mvn"
        fi
    fi

    if [ -z "$mvn_path" ]; then
        local mvn_list=($(curl -sL https://archive.apache.org/dist/maven/maven-3/ | grep -oP '(?<=href=")3\.[0-9]+\.[0-9]+(?=/")' | sort -uV -r | head -n 15))
        echo "Versões Maven sugeridas:"
        for i in "${!mvn_list[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${mvn_list[$i]}"; done
        read -p "Escolha o número ou digite a versão: " MVN_IN
        [[ "$MVN_IN" =~ ^[0-9]+$ ]] && [ "$MVN_IN" -le "${#mvn_list[@]}" ] && MVN_SELECTED_VER="${mvn_list[$((MVN_IN-1))]}" || MVN_SELECTED_VER=$MVN_IN
        mvn_path="$SOURCE_DIR/engines/maven-$MVN_SELECTED_VER/bin/mvn"
        if [ ! -d "$SOURCE_DIR/engines/maven-$MVN_SELECTED_VER" ]; then
            echo "Baixando Maven $MVN_SELECTED_VER..."
            curl -L --progress-bar "https://archive.apache.org/dist/maven/maven-3/$MVN_SELECTED_VER/binaries/apache-maven-$MVN_SELECTED_VER-bin.tar.gz" | tar -xz -C "$SOURCE_DIR/engines/" || exit 1
            [ -d "$SOURCE_DIR/engines/apache-maven-$MVN_SELECTED_VER" ] && mv "$SOURCE_DIR/engines/apache-maven-$MVN_SELECTED_VER" "$SOURCE_DIR/engines/maven-$MVN_SELECTED_VER"
            chmod +x "$mvn_path"
        fi
    fi

    local existing_wfs=($(ls -d $SOURCE_DIR/engines/wildfly-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/wildfly-||"))
    if [ ${#existing_wfs[@]} -gt 0 ]; then
        echo "WildFlys encontrados em engines/:"
        for i in "${!existing_wfs[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${existing_wfs[$i]}"; done
        read -p "Escolha um WildFly da engine ou 'n' para novo (1): " choice
        choice=${choice:-1}
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#existing_wfs[@]}" ]; then
            WF_SELECTED_VER="${existing_wfs[$((choice-1))]}"
        fi
    fi

    if [ -z "$WF_SELECTED_VER" ]; then
        read -p "Possui um WildFly customizado ou compactado? (S/n): " has_custom
        has_custom=${has_custom:-s}
        if [ "${has_custom,,}" == "s" ]; then
            read -p "Caminho (Pasta ou Arquivo): " custom_path
            read -p "Apelido para este motor: " custom_name
            WF_SELECTED_VER="${custom_name#wildfly-}"
            local target_dir="$SOURCE_DIR/engines/wildfly-$WF_SELECTED_VER"
            if [ ! -d "$target_dir" ]; then
                if [ -d "$custom_path" ]; then
                    echo "Copiando WildFly customizado..."
                    cp -r "$custom_path" "$target_dir"
                else
                    echo "Extraindo WildFly customizado..."
                    mkdir -p "$target_dir"
                    case "$custom_path" in
                        *.tar.gz|*.tgz) tar -xzf "$custom_path" -C "$target_dir" --strip-components=1 ;;
                        *.zip) unzip -q "$custom_path" -d "$target_dir" && [ $(ls -1 "$target_dir" | wc -l) -eq 1 ] && mv "$target_dir"/*/* "$target_dir/" 2>/dev/null ;;
                    esac
                fi
                find "$target_dir/bin" -name "*.sh" -exec chmod +x {} +
            fi
        else
            local wf_list=($(curl -sL https://api.github.com/repos/wildfly/wildfly/releases | grep -oP '"tag_name": "\K[0-9]+\.[0-9]+\.[0-9]+\.Final' | sort -uV -r | head -n 15))
            echo "Versões WildFly sugeridas:"
            for i in "${!wf_list[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${wf_list[$i]}"; done
            read -p "Escolha o número ou digite a versão: " WF_IN
            [[ "$WF_IN" =~ ^[0-9]+$ ]] && [ "$WF_IN" -le "${#wf_list[@]}" ] && WF_SELECTED_VER="${wf_list[$((WF_IN-1))]}" || WF_SELECTED_VER=$WF_IN
            WF_SELECTED_VER="${WF_SELECTED_VER#wildfly-}"
            local target_dir="$SOURCE_DIR/engines/wildfly-$WF_SELECTED_VER"
            if [ ! -d "$target_dir" ]; then
                echo "Baixando WildFly $WF_SELECTED_VER..."
                curl -L --progress-bar "https://github.com/wildfly/wildfly/releases/download/$WF_SELECTED_VER/wildfly-$WF_SELECTED_VER.tar.gz" | tar -xz -C "$SOURCE_DIR/engines/" || exit 1
                [ ! -d "$target_dir" ] && mv "$SOURCE_DIR/engines/wildfly-"[0-9]* "$target_dir"
                find "$target_dir/bin" -name "*.sh" -exec chmod +x {} +
            fi
        fi
    fi
    echo "MVN_PATH=\"$mvn_path\"" > "$p_dir/.engine-versions"
    echo "WF_SELECTED_VER=\"$WF_SELECTED_VER\"" >> "$p_dir/.engine-versions"
}

setup_repository() {
    local name=$1
    local p_dir=$2
    echo "================================================================"
    echo "1) Usar repositório existente"
    echo "2) Criar novo código fonte (WildFly Ultimate Initializr)"
    read -p "Escolha (1/2): " repo_choice
    if [ "$repo_choice" == "2" ]; then
        read -p "Caminho base para o código: " base
        wildfly_initializr "$name" "$base" "$p_dir"
        echo "$base/$name" > "$p_dir/.repo-path"
    else
        read -p "Caminho completo do repositório (onde está o pom.xml): " ext_repo_path
        if [ ! -f "$ext_repo_path/pom.xml" ]; then
            echo "Erro: pom.xml não encontrado em $ext_repo_path. Cancelando."
            rm -rf "$p_dir"
            exit 1
        fi
        echo "$ext_repo_path" > "$p_dir/.repo-path"
    fi
}