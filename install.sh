#!/bin/bash

GREEN='\e[32m'
BLUE='\e[34m'
NC='\e[0m'

INSTALL_DEST="$HOME/.wildfly-runner"
mkdir -p "$INSTALL_DEST"/{bin,core,engines,projects,templates}

cp -r bin core templates global.jvm "$INSTALL_DEST/"
chmod +x "$INSTALL_DEST/bin/wf"
find "$INSTALL_DEST" -name "*.sh" -exec chmod +x {} +

CURRENT_SHELL=$(basename "$SHELL")
if [ "$CURRENT_SHELL" == "zsh" ]; then
    CONF_FILE="$HOME/.zshrc"
else
    CONF_FILE="$HOME/.bashrc"
fi

if ! grep -q "$INSTALL_DEST/bin" "$CONF_FILE" 2>/dev/null; then
    echo -e "\n# WildFly Runner CLI" >> "$CONF_FILE"
    echo "export PATH=\"\$PATH:$INSTALL_DEST/bin\"" >> "$CONF_FILE"
fi

export PATH="$PATH:$INSTALL_DEST/bin"

echo -e "${BLUE}Instalado em: ${INSTALL_DEST}${NC}"
echo -e "${GREEN}O comando 'wf' ja esta disponivel.${NC}"