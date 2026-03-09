#!/bin/bash
wildfly_initializr() {
    local name=$1
    local base_path=$2
    local p_dir=$3
    local target_path="$base_path/$name"

    source "$p_dir/.engine-versions"
    local engine_path="$SOURCE_DIR/engines/wildfly-$WF_SELECTED_VER"

    echo "================================================================"
    echo "       WILDFLY RUNNER INITIALIZR"
    echo "================================================================"
    
    read -p "Group ID [org.wildfly.runner]: " group_id
    group_id=${group_id:-org.wildfly.runner}
    
    local current_java_ver=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    [ "$current_java_ver" == "1" ] && current_java_ver="8"
    
    read -p "Versão do JDK alvo (8, 11, 17, 21) [$current_java_ver]: " jdk_ver
    jdk_ver=${jdk_ver:-$current_java_ver}

    local ee_ns="jakarta"
    local ee_version="10.0.0"
    local web_schema="6.0"
    local web_uri="https://jakarta.ee/xml/ns/jakartaee"
    local persist_uri="https://jakarta.ee/xml/ns/persistence"
    local persist_ver="3.0"
    local omni_ver="4.3"
    local pf_classifier="<classifier>jakarta</classifier>"

    if [ "$jdk_ver" -le 8 ]; then
        ee_ns="javax"
        ee_version="8.0.0"
        web_schema="4.0"
        web_uri="http://xmlns.jcp.org/xml/ns/javaee"
        persist_uri="http://xmlns.jcp.org/xml/ns/persistence"
        persist_ver="2.2"
        omni_ver="3.14.1"
        pf_classifier=""
    fi

    echo -e "\n--- Framework Web (Facelets/JSF) ---"
    echo "1) PrimeFaces (Recomendado)"
    echo "2) BootsFaces"
    echo "3) ButterFaces"
    echo "4) JSF Puro"
    read -p "Escolha [1]: " web_choice
    web_choice=${web_choice:-1}

    echo -e "\n--- Banco de Dados (JPA/Hibernate) ---"
    echo "1) H2 (Zero Config)"
    echo "2) PostgreSQL"
    echo "3) MySQL"
    read -p "Escolha [1]: " db_choice
    db_choice=${db_choice:-1}

    echo -e "\n--- Recursos Adicionais (S/n) ---"
    read -p "  - Adicionar JAX-RS (REST API)? [S]: " has_rest
    read -p "  - Adicionar OmniFaces? [S]: " has_omni
    
    local pkg_path="src/main/java/$(echo $group_id | tr '.' '/')"
    mkdir -p "$target_path/$pkg_path"
    mkdir -p "$target_path/src/main/resources/META-INF"
    mkdir -p "$target_path/src/main/webapp/WEB-INF"

    cat <<EOF > "$target_path/pom.xml"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>$group_id</groupId>
    <artifactId>$name</artifactId>
    <packaging>war</packaging>
    <version>1.0-SNAPSHOT</version>
    <properties>
        <maven.compiler.source>$jdk_ver</maven.compiler.source>
        <maven.compiler.target>$jdk_ver</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    <dependencies>
        <dependency>
            <groupId>jakarta.platform</groupId>
            <artifactId>jakarta.jakartaee-api</artifactId>
            <version>$ee_version</version>
            <scope>provided</scope>
        </dependency>
EOF

    case $web_choice in
        1) echo "        <dependency><groupId>org.primefaces</groupId><artifactId>primefaces</artifactId><version>12.0.0</version>$pf_classifier</dependency>" >> "$target_path/pom.xml" ;;
        2) echo "        <dependency><groupId>net.bootsfaces</groupId><artifactId>bootsfaces</artifactId><version>1.5.0</version></dependency>" >> "$target_path/pom.xml" ;;
        3) echo "        <dependency><groupId>org.butterfaces</groupId><artifactId>components</artifactId><version>3.0.1</version></dependency>" >> "$target_path/pom.xml" ;;
    esac

    if [ "${has_omni,,}" != "n" ]; then
        echo "        <dependency><groupId>org.omnifaces</groupId><artifactId>omnifaces</artifactId><version>$omni_ver</version></dependency>" >> "$target_path/pom.xml"
    fi

    case $db_choice in
        2) echo "        <dependency><groupId>org.postgresql</groupId><artifactId>postgresql</artifactId><version>42.6.0</version><scope>provided</scope></dependency>" >> "$target_path/pom.xml" ;;
        3) echo "        <dependency><groupId>com.mysql</groupId><artifactId>mysql-connector-j</artifactId><version>8.0.33</version><scope>provided</scope></dependency>" >> "$target_path/pom.xml" ;;
    esac

    cat <<EOF >> "$target_path/pom.xml"
    </dependencies>
    <build>
        <finalName>$name</finalName>
        <plugins>
            <plugin>
                <artifactId>maven-war-plugin</artifactId>
                <version>3.3.2</version>
                <configuration><failOnMissingWebXml>false</failOnMissingWebXml></configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

    touch "$target_path/src/main/webapp/WEB-INF/beans.xml"
    cat <<EOF > "$target_path/src/main/webapp/WEB-INF/web.xml"
<web-app xmlns="$web_uri" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="$web_uri $web_uri/web-app_${web_schema//./_}.xsd" version="$web_schema">
    <servlet><servlet-name>Faces</servlet-name><servlet-class>$ee_ns.faces.webapp.FacesServlet</servlet-class><load-on-startup>1</load-on-startup></servlet>
    <servlet-mapping><servlet-name>Faces</servlet-name><url-pattern>*.xhtml</url-pattern></servlet-mapping>
    <welcome-file-list><welcome-file>index.xhtml</welcome-file></welcome-file-list>
</web-app>
EOF

    local faces_ns="http://xmlns.jcp.org/jsf/html"
    [ "$ee_ns" == "jakarta" ] && faces_ns="jakarta.faces.html"

    cat <<EOF > "$target_path/src/main/webapp/index.xhtml"
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:h="$faces_ns" xmlns:p="http://primefaces.org/ui">
<h:head><title>$name</title></h:head>
<h:body>
    <h:form>
        <h1>Hello WildFly: $name</h1>
        <p>Namespace: $ee_ns | JDK Alvo: $jdk_ver</p>
        $( [ "$web_choice" == "1" ] && echo '<p:button value="Botão PrimeFaces" icon="pi pi-check" />' )
    </h:form>
</h:body>
</html>
EOF

    cp "$engine_path/standalone/configuration/standalone.xml" "$p_dir/standalone.xml"

    sed -i '/<interfaces>/,/<\/interfaces>/c\
    <interfaces>\
        <interface name="management"><inet-address value="${jboss.bind.address.management:127.0.0.1}"/></interface>\
        <interface name="public"><inet-address value="${jboss.bind.address:0.0.0.0}"/></interface>\
        <interface name="unsecure"><inet-address value="${jboss.bind.address.unsecure:127.0.0.1}"/></interface>\
    </interfaces>' "$p_dir/standalone.xml"

    sed -i '/<socket-binding-group/,/<\/socket-binding-group>/c\
    <socket-binding-group name="standard-sockets" default-interface="public" port-offset="${jboss.socket.binding.port-offset:0}">\
        <socket-binding name="ajp" port="${jboss.ajp.port:8009}"/>\
        <socket-binding name="http" port="${jboss.http.port:8080}"/>\
        <socket-binding name="https" port="${jboss.https.port:8443}"/>\
        <socket-binding name="iiop" interface="unsecure" port="3528"/>\
        <socket-binding name="iiop-ssl" interface="unsecure" port="3529"/>\
        <socket-binding name="management-http" interface="management" port="${jboss.management.http.port:9990}"/>\
        <socket-binding name="management-https" interface="management" port="${jboss.management.https.port:9993}"/>\
        <socket-binding name="txn-recovery-environment" port="4712"/>\
        <socket-binding name="txn-status-manager" port="4713"/>\
        <outbound-socket-binding name="mail-smtp">\
            <remote-destination host="localhost" port="25"/>\
        </outbound-socket-binding>\
    </socket-binding-group>' "$p_dir/standalone.xml"

    local ds_name="ExampleDS"
    [ "$db_choice" == "2" ] && ds_name="PostgresDS"
    [ "$db_choice" == "3" ] && ds_name="MySqlDS"

    cat <<EOF > "$target_path/src/main/resources/META-INF/persistence.xml"
<persistence xmlns="$persist_uri" version="$persist_ver">
    <persistence-unit name="primary">
        <jta-data-source>java:jboss/datasources/$ds_name</jta-data-source>
        <properties><property name="hibernate.hbm2ddl.auto" value="update"/></properties>
    </persistence-unit>
</persistence>
EOF

    if [ "${has_rest,,}" != "n" ]; then
        cat <<EOF > "$target_path/$pkg_path/RestConfig.java"
package $group_id;
import $ee_ns.ws.rs.ApplicationPath;
import $ee_ns.ws.rs.core.Application;
@ApplicationPath("/api")
public class RestConfig extends Application {}
EOF
        cat <<EOF > "$target_path/$pkg_path/HelloResource.java"
package $group_id;
import $ee_ns.ws.rs.GET;
import $ee_ns.ws.rs.Path;
@Path("/hello")
public class HelloResource {
    @GET
    public String sayHello() { return "API Ativa ($ee_ns) em $name!"; }
}
EOF
    fi
}