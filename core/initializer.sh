#!/bin/bash
wildfly_initializr() {
    local name=$1
    local base_path=$2
    local p_dir=$3
    local target_path="$base_path/$name"

    echo "================================================================"
    echo "       WILDFLY ULTIMATE INITIALIZR (Jakarta EE 8)"
    echo "================================================================"
    
    read -p "Group ID [org.wildfly.runner]: " group_id
    group_id=${group_id:-org.wildfly.runner}
    
    read -p "Versão do JDK (8, 11, 17, 21) [11]: " jdk_ver
    jdk_ver=${jdk_ver:-11}

    echo -e "\n--- Framework Web (Facelets/JSF) ---"
    echo "1) PrimeFaces (Padrão)"
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
            <version>8.0.0</version>
            <scope>provided</scope>
        </dependency>
EOF

    case $web_choice in
        1) echo "        <dependency><groupId>org.primefaces</groupId><artifactId>primefaces</artifactId><version>12.0.0</version></dependency>" >> "$target_path/pom.xml" ;;
        2) echo "        <dependency><groupId>net.bootsfaces</groupId><artifactId>bootsfaces</artifactId><version>1.5.0</version></dependency>" >> "$target_path/pom.xml" ;;
        3) echo "        <dependency><groupId>org.butterfaces</groupId><artifactId>components</artifactId><version>3.0.1</version></dependency>" >> "$target_path/pom.xml" ;;
    esac
    [ "${has_omni,,}" != "n" ] && echo "        <dependency><groupId>org.omnifaces</groupId><artifactId>omnifaces</artifactId><version>3.14</version></dependency>" >> "$target_path/pom.xml"
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
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee" version="4.0">
    <servlet><servlet-name>Faces</servlet-name><servlet-class>javax.faces.webapp.FacesServlet</servlet-class><load-on-startup>1</load-on-startup></servlet>
    <servlet-mapping><servlet-name>Faces</servlet-name><url-pattern>*.xhtml</url-pattern></servlet-mapping>
    <welcome-file-list><welcome-file>index.xhtml</welcome-file></welcome-file-list>
</web-app>
EOF

    cat <<EOF > "$target_path/src/main/webapp/index.xhtml"
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:h="http://xmlns.jcp.org/jsf/html" xmlns:p="http://primefaces.org/ui">
<h:head><title>$name</title></h:head>
<h:body>
    <h:form>
        <h1>Hello WildFly: $name</h1>
        <p>JDK: $jdk_ver | Tecnologia Web: Opção $web_choice</p>
        $( [ "$web_choice" == "1" ] && echo '<p:button value="Botão PrimeFaces" icon="pi pi-check" />' )
    </h:form>
</h:body>
</html>
EOF

    local ds_name="ExampleDS"
    [ "$db_choice" == "2" ] && ds_name="PostgresDS"
    [ "$db_choice" == "3" ] && ds_name="MySqlDS"

    cat <<EOF > "$target_path/src/main/resources/META-INF/persistence.xml"
<persistence xmlns="http://xmlns.jcp.org/xml/ns/persistence" version="2.2">
    <persistence-unit name="primary">
        <jta-data-source>java:jboss/datasources/$ds_name</jta-data-source>
        <properties><property name="hibernate.hbm2ddl.auto" value="update"/></properties>
    </persistence-unit>
</persistence>
EOF

    if [ "${has_rest,,}" != "n" ]; then
        cat <<EOF > "$target_path/$pkg_path/RestConfig.java"
package $group_id;
import javax.ws.rs.ApplicationPath;
import javax.ws.rs.core.Application;
@ApplicationPath("/api")
public class RestConfig extends Application {}
EOF
        cat <<EOF > "$target_path/$pkg_path/HelloResource.java"
package $group_id;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
@Path("/hello")
public class HelloResource {
    @GET
    public String sayHello() { return "API Ativa em $name!"; }
}
EOF
    fi
}