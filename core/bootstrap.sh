#!/bin/bash
setup_structure() {
    mkdir -p "$SOURCE_DIR"/{bin,core,engines,projects,templates}
    [ ! -f "$SOURCE_DIR/global.jvm" ] && echo "-Xms2048m -Xmx2048m -Dfile.encoding=UTF-8" > "$SOURCE_DIR/global.jvm"
    [ ! -f "$SOURCE_DIR/templates/.env.example" ] && echo "VAR_NAME=value" > "$SOURCE_DIR/templates/.env.example"
    [ ! -f "$SOURCE_DIR/templates/.profiles.example" ] && echo "default" > "$SOURCE_DIR/templates/.profiles.example"
    if [ ! -f "$SOURCE_DIR/templates/standalone-h2.xml" ]; then
        cat <<EOF > "$SOURCE_DIR/templates/standalone-h2.xml"
<server xmlns="urn:jboss:domain:10.0"><interfaces><interface name="public"><inet-address value="127.0.0.1"/></interface></interfaces><socket-binding-group name="standard-sockets" default-interface="public" port-offset="\${jboss.socket.binding.port-offset:0}"><socket-binding name="http" port="\${jboss.http.port:8080}"/><socket-binding name="management-http" interface="management" port="\${jboss.management.http.port:9990}"/></socket-binding-group><profile><subsystem xmlns="urn:jboss:domain:datasources:5.0"><datasources><datasource jndi-name="java:jboss/datasources/ExampleDS" pool-name="ExampleDS" enabled="true"><connection-url>jdbc:h2:mem:test;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE</connection-url><driver>h2</driver></datasource><drivers><driver name="h2" module="com.h2database.h2"/></drivers></datasources></subsystem></profile></server>
EOF
    fi
}

install_engines() {
    local name=$1
    local p_dir="$SOURCE_DIR/projects/$name"
    local java_path="" java_ver="" mvn_path="" WF_SELECTED_VER=""

    local current_java_bin=$(which java)
    local current_java_ver=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
    local current_java_home=$(readlink -f "$current_java_bin" | sed 's|/bin/java||')

    echo -e "\nConfiguracao de Java:"
    echo "Java detectado no sistema: $current_java_home (Versao: $current_java_ver)"
    read -p "Usar este Java para o projeto? (S/n): " choice
    choice=${choice:-s}

    if [[ "${choice,,}" == "s" ]]; then
        java_path="$current_java_home"
        java_ver="$current_java_ver"
    else
        read -p "Informe o caminho completo do JAVA_HOME (Caminho base antes do /bin): " java_path
        java_path="${java_path%/}"
        if [ ! -f "$java_path/bin/java" ]; then
            echo -e "\e[31mErro: Binario java nao encontrado em $java_path/bin/java. Abortando.\e[0m"
            exit 1
        fi
        java_ver=$("$java_path/bin/java" -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
    fi

    while true; do
        local existing_mvns=($(ls -d $SOURCE_DIR/engines/maven-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/maven-||"))
        if [ ${#existing_mvns[@]} -gt 0 ]; then
            echo -e "\nMavens encontrados em engines/:"
            for i in "${!existing_mvns[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${existing_mvns[$i]}"; done
            read -p "Escolha um Maven configurado ou 'n' para novo (1): " m_choice
            m_choice=${m_choice:-1}
            if [[ "$m_choice" =~ ^[0-9]+$ ]] && [ "$m_choice" -le "${#existing_mvns[@]}" ]; then
                local MVN_SELECTED_VER="${existing_mvns[$((m_choice-1))]}"
                mvn_path="$SOURCE_DIR/engines/maven-$MVN_SELECTED_VER/bin/mvn"
                break
            fi
        fi
        install_mvn_standalone
    done

    while true; do
        local existing_wfs=($(ls -d $SOURCE_DIR/engines/wildfly-* 2>/dev/null | sed "s|$SOURCE_DIR/engines/wildfly-||"))
        if [ ${#existing_wfs[@]} -gt 0 ]; then
            echo -e "\nWildFlys encontrados em engines/:"
            for i in "${!existing_wfs[@]}"; do printf "  %2d) %s\n" "$((i+1))" "${existing_wfs[$i]}"; done
            read -p "Escolha um WildFly configurado ou 'n' para novo (1): " w_choice
            w_choice=${w_choice:-1}
            if [[ "$w_choice" =~ ^[0-9]+$ ]] && [ "$w_choice" -le "${#existing_wfs[@]}" ]; then
                WF_SELECTED_VER="${existing_wfs[$((w_choice-1))]}"
                break
            fi
        fi
        install_wf_standalone
    done

    echo "JAVA_HOME=\"$java_path\"" > "$p_dir/.engine-versions"
    echo "JAVA_VER=\"$java_ver\"" >> "$p_dir/.engine-versions"
    echo "MVN_PATH=\"$mvn_path\"" >> "$p_dir/.engine-versions"
    echo "WF_SELECTED_VER=\"$WF_SELECTED_VER\"" >> "$p_dir/.engine-versions"

    echo -e "\nEngines configurados para o projeto $name:"
    echo "  - Java: $java_ver"
    echo "  - Maven: $(echo $mvn_path | grep -oP 'maven-\K[0-9.]+')"
    echo "  - WildFly: $WF_SELECTED_VER"
    echo ""
}

setup_repository() {
    local name=$1
    local p_dir=$2
    echo "================================================================"
    echo "1) Usar repositório existente"
    echo "2) Criar novo código fonte (WildFly Runner Initializr)"
    read -p "Escolha (1/2): " repo_choice
    if [ "$repo_choice" == "2" ]; then
        read -p "Caminho base para o código: " base
        wildfly_initializr "$name" "$base" "$p_dir"
        echo "$base/$name" > "$p_dir/.repo-path"
        return 2
    else
        read -p "Caminho completo do repositório (onde está o pom.xml): " ext_repo_path
        if [ ! -f "$ext_repo_path/pom.xml" ]; then
            echo "Erro: pom.xml não encontrado em $ext_repo_path. Cancelando."
            rm -rf "$p_dir"
            exit 1
        fi
        echo "$ext_repo_path" > "$p_dir/.repo-path"
        return 1
    fi
}