#!/bin/bash

GREEN='\033[32m'
BLUE='\033[34m'
NC='\033[0m'

INSTALL_DEST="$HOME/.wildfly-runner"
mkdir -p "$INSTALL_DEST"/{bin,core,engines,projects,templates}

cp -r bin core templates global.jvm "$INSTALL_DEST/"
chmod +x "$INSTALL_DEST/bin/wf"
find "$INSTALL_DEST" -name "*.sh" -exec chmod +x {} +

case "$SHELL" in
    */zsh)
        CONF_FILE="$HOME/.zshrc"
        ;;
    */bash)
        CONF_FILE="$HOME/.bashrc"
        ;;
    *)
        [ -f "$HOME/.zshrc" ] && CONF_FILE="$HOME/.zshrc" || CONF_FILE="$HOME/.bashrc"
        ;;
esac

if [ -f "$CONF_FILE" ]; then
    if ! grep -q "$INSTALL_DEST/bin" "$CONF_FILE" 2>/dev/null; then
        printf "\n# WildFly Runner CLI\n" >> "$CONF_FILE"
        printf "export PATH=\"\$PATH:$INSTALL_DEST/bin\"\n" >> "$CONF_FILE"
        printf "${BLUE}Configuração aplicada em: $CONF_FILE${NC}\n"
    fi
fi

export PATH="$PATH:$INSTALL_DEST/bin"

printf "${BLUE}Instalado em: ${INSTALL_DEST}${NC}\n"
printf "${BLUE}Seu gerenciamento de projetos fica em: ${INSTALL_DEST}/projects${NC}\n"
printf "${GREEN}O comando 'wf' ja esta disponivel.${NC}\n"
printf "${GREEN}Use 'wf init' para configurar seu primeiro projeto.${NC}\n"