#!/bin/bash

get_usage() {
    local type=$1
    local ver=$2
    local found=()
    for p_dir in "$SOURCE_DIR/projects"/*; do
        [ ! -d "$p_dir" ] && continue
        local env_file="$p_dir/.engine-versions"
        [ ! -f "$env_file" ] && continue
        local JAVA_HOME="" JAVA_VER="" MVN_PATH="" WF_SELECTED_VER=""
        source "$env_file" 2>/dev/null
        if [ "$type" == "maven" ]; then
            [[ "$MVN_PATH" == *"/maven-$ver/"* ]] && found+=($(basename "$p_dir"))
        elif [ "$type" == "wildfly" ]; then
            [[ "$WF_SELECTED_VER" == "$ver" ]] && found+=($(basename "$p_dir"))
        fi
    done
    if [ ${#found[@]} -gt 0 ]; then
        echo -e "\e[2m (usado por: $(IFS=,; echo "${found[*]}"))\e[0m"
    fi
}

list_engines() {
    echo -e "\n\e[1;34mMOTORES DISPONIVEIS (Engines):\e[0m"
    for type in "maven" "wildfly"; do
        echo -e "\n\e[1m${type^}:\e[0m"
        local list=($(ls -d $SOURCE_DIR/engines/${type}-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/${type}-||"))
        if [ ${#list[@]} -eq 0 ]; then
            echo "Nenhum motor encontrado."
        else
            for v in "${list[@]}"; do
                usage=$(get_usage "$type" "$v")
                echo -e "- $v$usage"
            done
        fi
    done
    echo ""
}

remove_engine() {
    local type=$1
    local version=$2
    if [ -z "$type" ]; then
        echo "Escolha o tipo de remocao:"
        echo "1) Maven"
        echo "2) WildFly"
        read -p "Opcao: " opt
        [ "$opt" == "1" ] && type="maven"
        [ "$opt" == "2" ] && type="wildfly"
        [ -z "$type" ] && echo "Opcao invalida." && return 1
    fi
    if [ -z "$version" ]; then
        local list=($(ls -d $SOURCE_DIR/engines/${type}-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/${type}-||"))
        if [ ${#list[@]} -eq 0 ]; then
            echo "Nenhum $type para remover."
            return 1
        fi
        echo -e "\nEscolha o $type para remover:"
        for i in "${!list[@]}"; do
            usage=$(get_usage "$type" "${list[$i]}")
            printf "  %2d) %s%s\n" "$((i+1))" "${list[$i]}" "$usage"
        done
        read -p "Opcao: " choice
        [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#list[@]}" ] && version="${list[$((choice-1))]}"
        [ -z "$version" ] && echo "Cancelado." && return 1
    fi
    local target_path="$SOURCE_DIR/engines/${type}-${version}"
    if [ ! -d "$target_path" ]; then
        echo "Erro: Motor $type $version nao encontrado."
        return 1
    fi
    read -p "Confirmar remocao de $(basename $target_path)? (s/N): " confirm
    if [[ "${confirm,,}" == "s" ]]; then
        rm -rf "$target_path"
        echo "Motor removido."
    fi
}

install_engine_generic() {
    local type=$1
    case "$type" in
        maven) install_mvn_standalone ;;
        wildfly) install_wf_standalone ;;
        *)
            echo "Escolha o tipo de instalacao:"
            echo "1) Maven"
            echo "2) WildFly"
            read -p "Opcao: " opt
            [ "$opt" == "1" ] && install_mvn_standalone
            [ "$opt" == "2" ] && install_wf_standalone
            ;;
    esac
}

install_mvn_standalone() {
    local sys_mvn=$(command -v mvn)
    if [ ! -z "$sys_mvn" ]; then
        local mvn_v_str=$($sys_mvn -version | head -n 1 | awk '{print $3}')
        if [ ! -d "$SOURCE_DIR/engines/maven-$mvn_v_str" ]; then
            read -p "Maven sistema detectado ($mvn_v_str). Copiar para engines? (S/n): " choice
            if [[ "${choice,,}" =~ ^(s|)$ ]]; then
                local sys_mvn_home=$(mvn -version | grep "Maven home" | awk -F': ' '{print $2}')
                cp -r "$sys_mvn_home" "$SOURCE_DIR/engines/maven-$mvn_v_str"
                echo "Maven $mvn_v_str copiado."
                return 0
            fi
        fi
    fi
    local mvn_list=($(curl -sL https://archive.apache.org/dist/maven/maven-3/ | grep -oP '(?<=href=")3\.[0-9]+\.[0-9]+(?=/")' | sort -uV -r | head -n 15))
    echo "Versões Maven disponíveis:"
    for i in "${!mvn_list[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${mvn_list[$i]}"; done
    read -p "Escolha a versão: " MVN_IN
    [[ "$MVN_IN" =~ ^[0-9]+$ ]] && [ "$MVN_IN" -le "${#mvn_list[@]}" ] && ver="${mvn_list[$((MVN_IN-1))]}" || ver=$MVN_IN
    if [ ! -d "$SOURCE_DIR/engines/maven-$ver" ]; then
        echo "Baixando Maven $ver..."
        curl -L -f --progress-bar "https://archive.apache.org/dist/maven/maven-3/$ver/binaries/apache-maven-$ver-bin.tar.gz" -o "/tmp/mvn-$ver.tar.gz"
        if [ $? -eq 0 ]; then
            mkdir -p "$SOURCE_DIR/engines/maven-$ver"
            tar -xzf "/tmp/mvn-$ver.tar.gz" -C "$SOURCE_DIR/engines/maven-$ver" --strip-components=1
            rm "/tmp/mvn-$ver.tar.gz"
            echo "Maven $ver instalado."
        else
            echo "Erro ao baixar Maven $ver."
        fi
    fi
}

install_wf_standalone() {
    read -p "Possui um WildFly customizado ou compactado? (S/n): " has_custom
    has_custom=${has_custom:-s}
    if [ "${has_custom,,}" == "s" ]; then
        read -p "Caminho (Pasta ou Arquivo): " custom_path
        read -p "Apelido para o WildFly: " custom_name
        local ver="${custom_name#wildfly-}"
        local target_dir="$SOURCE_DIR/engines/wildfly-$ver"
        if [ -d "$target_dir" ]; then
            echo "INFO: WildFly (apelido: $ver) já existe em engines."
        else
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
            echo "WildFly $ver instalado com sucesso."
        fi
    else
        local wf_list=($(curl -sL https://api.github.com/repos/wildfly/wildfly/releases | grep -oP '"tag_name": "\K[0-9]+\.[0-9]+\.[0-9]+\.Final' | sort -uV -r | head -n 15))
        echo "Versões WildFly sugeridas:"
        for i in "${!wf_list[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${wf_list[$i]}"; done
        read -p "Escolha a versão: " WF_IN
        [[ "$WF_IN" =~ ^[0-9]+$ ]] && [ "$WF_IN" -le "${#wf_list[@]}" ] && ver="${wf_list[$((WF_IN-1))]}" || ver=$WF_IN
        ver="${ver#wildfly-}"
        local target="$SOURCE_DIR/engines/wildfly-$ver"
        if [ ! -d "$target" ]; then
            echo "Baixando WildFly $ver..."
            local url="https://github.com/wildfly/wildfly/releases/download/$ver/wildfly-$ver.tar.gz"
            curl -L -f --progress-bar "$url" -o "/tmp/wf-$ver.tar.gz"
            if [ $? -ne 0 ]; then
                echo "Não encontrado no repositorio. Tentando mirror oficial..."
                url="https://download.jboss.org/wildfly/$ver/wildfly-$ver.tar.gz"
                curl -L -f --progress-bar "$url" -o "/tmp/wf-$ver.tar.gz"
            fi
            if [ $? -eq 0 ]; then
                mkdir -p "$target"
                tar -xzf "/tmp/wf-$ver.tar.gz" -C "$target" --strip-components=1
                rm "/tmp/wf-$ver.tar.gz"
                find "$target/bin" -name "*.sh" -exec chmod +x {} +
                echo "WildFly $ver instalado com sucesso."
            else
                echo -e "\e[31mErro: Não foi possível baixar a versão $ver de nenhuma das fontes.\e[0m"
                rm -f "/tmp/wf-$ver.tar.gz"
            fi
        fi
    fi
}