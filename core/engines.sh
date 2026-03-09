#!/bin/bash

list_engines() {
    echo -e "\n\e[1;34mMOTORES DISPONIVEIS (Engines):\e[0m"
    echo -e "\n\e[1mMaven:\e[0m"
    ls -d $SOURCE_DIR/engines/maven-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/maven-|- |" || echo "Nenhum Maven encontrado."
    echo -e "\n\e[1mWildFly:\e[0m"
    ls -d $SOURCE_DIR/engines/wildfly-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/wildfly-|- |" || echo "Nenhum WildFly encontrado."
    echo ""
}

remove_engine() {
    local type=$1
    local version=$2
    local target_path=""

    if [ -z "$type" ]; then
        echo "Escolha o tipo de remocao:"
        echo "1) Maven"
        echo "2) WildFly"
        read -p "Opcao: " opt
        [ "$opt" == "1" ] && type="maven"
        [ "$opt" == "2" ] && type="wildfly"
        [ -z "$type" ] && echo "Opcao invalida." && return 1
    fi
    if [ "$type" == "engines" ]; then
        echo -e "\e[31mErro: Operação negada. Especifique o motor.\e[0m"
        return 1
    fi
    if [ -n "$type" ] && [ -n "$version" ]; then
        target_path="$SOURCE_DIR/engines/${type}-${version}"
    elif [[ "$type" =~ ^(maven|wildfly)$ ]] && [ -z "$version" ]; then
        local list=($(ls -d $SOURCE_DIR/engines/${type}-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/${type}-||"))
        if [ ${#list[@]} -eq 0 ]; then
            echo "Nenhum motor do tipo $type encontrado."
            return 1
        fi
        echo "Escolha o $type para remover:"
        for i in "${!list[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${list[$i]}"; done
        read -p "Opcao: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#list[@]}" ]; then
            target_path="$SOURCE_DIR/engines/${type}-${list[$((choice-1))]}"
        else
            echo "Opcao invalida." && return 1
        fi
    else
        if [ -d "$SOURCE_DIR/engines/wildfly-$type" ]; then
            target_path="$SOURCE_DIR/engines/wildfly-$type"
        elif [ -d "$SOURCE_DIR/engines/maven-$type" ]; then
            target_path="$SOURCE_DIR/engines/maven-$type"
        elif [ -d "$SOURCE_DIR/engines/$type" ]; then
            target_path="$SOURCE_DIR/engines/$type"
        else
            echo "Erro: Motor $type nao encontrado em engines/"
            return 1
        fi
    fi
    if [ -z "$target_path" ] || [ "$target_path" == "$SOURCE_DIR/engines" ] || [ "$target_path" == "$SOURCE_DIR/engines/" ]; then
        echo -e "\e[31mErro Critico: Caminho de remocao invalido ou protegido. Operacao abortada.\e[0m"
        return 1
    fi
    if [ -d "$target_path" ]; then
        local motor_name=$(basename "$target_path")
        read -p "Tem certeza que deseja remover o motor $motor_name? (s/N): " confirm
        if [[ "${confirm,,}" == "s" ]]; then
            rm -rf "$target_path"
            echo "Motor $motor_name removido com sucesso."
        else
            echo "Remocao cancelada."
        fi
    else
        echo "Erro: Motor nao encontrado."
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
    local mvn_list=($(curl -sL https://archive.apache.org/dist/maven/maven-3/ | grep -oP '(?<=href=")3\.[0-9]+\.[0-9]+(?=/")' | sort -uV -r | head -n 15))
    echo "Versões Maven sugeridas:"
    for i in "${!mvn_list[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${mvn_list[$i]}"; done
    read -p "Escolha a versão: " MVN_IN
    [[ "$MVN_IN" =~ ^[0-9]+$ ]] && [ "$MVN_IN" -le "${#mvn_list[@]}" ] && ver="${mvn_list[$((MVN_IN-1))]}" || ver=$MVN_IN
    if [ ! -d "$SOURCE_DIR/engines/maven-$ver" ]; then
        echo "Baixando Maven $ver..."
        curl -L --progress-bar "https://archive.apache.org/dist/maven/maven-3/$ver/binaries/apache-maven-$ver-bin.tar.gz" | tar -xz -C "$SOURCE_DIR/engines/"
        [ -d "$SOURCE_DIR/engines/apache-maven-$ver" ] && mv "$SOURCE_DIR/engines/apache-maven-$ver" "$SOURCE_DIR/engines/maven-$ver"
        echo "Maven $ver instalado."
    fi
}

install_wf_standalone() {
    local wf_list=($(curl -sL https://api.github.com/repos/wildfly/wildfly/releases | grep -oP '"tag_name": "\K[0-9]+\.[0-9]+\.[0-9]+\.Final' | sort -uV -r | head -n 15))
    echo "Versões WildFly sugeridas:"
    for i in "${!wf_list[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${wf_list[$i]}"; done
    read -p "Escolha a versão: " WF_IN
    [[ "$WF_IN" =~ ^[0-9]+$ ]] && [ "$WF_IN" -le "${#wf_list[@]}" ] && ver="${wf_list[$((WF_IN-1))]}" || ver=$WF_IN
    if [ ! -d "$SOURCE_DIR/engines/wildfly-$ver" ]; then
        echo "Baixando WildFly $ver..."
        curl -L --progress-bar "https://github.com/wildfly/wildfly/releases/download/$ver/wildfly-$ver.tar.gz" | tar -xz -C "$SOURCE_DIR/engines/"
        echo "WildFly $ver instalado."
    fi
}