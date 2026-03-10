# WildFly Runner

O **WildFly Runner** é uma ferramenta CLI (Command Line Interface) desenvolvida para simplificar o gerenciamento e execução de projetos baseados no WildFly, o servidor de aplicações Java EE/Jakarta EE. Ele automatiza tarefas como compilação com Maven, configuração de ambientes, inicialização de servidores e monitoramento de mudanças em tempo real.

## Funcionalidades Principais

- **Gerenciamento de Projetos**: Inicialize, configure e execute múltiplos projetos WildFly com configurações isoladas.
- **Integração com Maven**: Compilação automática, gerenciamento de perfis e deploy de aplicações.
- **Motores (Engines)**: Suporte a múltiplas versões do WildFly e Maven, instaladas automaticamente.
- **Monitoramento em Tempo Real**: Modo "watch" para hot reload de Java e hot sync de UI.
- **Configurações Personalizáveis**: Variáveis de ambiente, perfis Maven, opções JVM e configurações standalone.xml por projeto.
- **Sandbox Isolada**: Cada projeto roda em um ambiente temporário isolado (/tmp), evitando conflitos.

## Instalação

### Pré-requisitos

- **Java**: JDK 8 ou superior instalado e configurado (JAVA_HOME definido).
- **Bash**: Shell compatível (Linux/macOS).
- **Git**: Para clonar repositórios de projetos (opcional, mas recomendado).

### Passos de Instalação

1. **Clone ou baixe o repositório**:
   ```bash
   git clone https://github.com/wesleybritovlk/wildfly-runner.git
   cd wildfly-runner
   ```

2. **Execute o script de instalação**:
   ```bash
   ./install.sh
   ```

   Este script:
   - Copia os arquivos para `~/.wildfly-runner/`.
   - Define permissões executáveis nos scripts.
   - Adiciona o comando `wf` ao seu PATH (em `~/.bashrc` ou `~/.zshrc`).
   - Exibe a confirmação de instalação.

3. **Verifique a instalação**:
   ```bash
   wf --help
   ```
   Ou simplesmente:
   ```bash
   wf
   ```

   Você deve ver a ajuda do CLI.

### Desinstalação

Para remover o WildFly Runner:
```bash
rm -rf ~/.wildfly-runner
```
E remova manualmente a linha `export PATH="$PATH:$HOME/.wildfly-runner/bin"` do seu arquivo de configuração de shell (`~/.bashrc` ou `~/.zshrc`).

## Como Usar

### Inicializando um Novo Projeto

Para criar um novo projeto:
```bash
wf init [nome-do-projeto]
```

Exemplo:
```bash
wf init meu-projeto
```

Isso irá:
- Criar a pasta `projects/meu-projeto/`.
- Instalar/configurar engines (Java, Maven, WildFly).
- Solicitar o caminho do repositório Git do projeto.
- Copiar templates de configuração (`.env`, `.profiles`).
- Gerar ou copiar o `standalone.xml`.

### Executando um Projeto

Para compilar e executar o servidor:
```bash
wf run [opções] [nome-do-projeto]
```

Opções:
- `-d`: Ativa o modo debug (porta 8687).
- `-t`: Executa testes durante a compilação.
- `-f`: Modo FAST (pula recompilação).

Exemplo:
```bash
wf run -d meu-projeto
```

### Modo de Monitoramento (Watch)

Para desenvolvimento com hot reload:
```bash
wf watch [-d] [nome-do-projeto]
```

Isso monitora mudanças em arquivos Java (hot reload) e UI (hot sync), reiniciando apenas o necessário.

### Fazendo Deploy

Para compilar e gerar o pacote:
```bash
wf deploy [-t] [-P perfis] [nome-do-projeto]
```

Exemplo:
```bash
wf deploy -t -P dev,postgres meu-projeto
```

### Outros Comandos

- **Listar projetos**: `wf list`
- **Status de execução**: `wf status [nome]`
- **Atualizar projeto**: `wf update [nome]`
- **Remover projeto**: `wf remove [nome]`
- **Configurar perfis Maven**: `wf profiles [nome]`

### Gerenciamento de Engines

- **Listar engines**: `wf engine list`
- **Instalar novo engine**: `wf engine install [maven|wildfly] [versão]`
- **Remover engine**: `wf engine remove [maven|wildfly] [versão]`

## Estrutura do Projeto

```
wildfly-runner/
├── bin/wf                    # Comando principal CLI
├── core/                     # Scripts internos
│   ├── bootstrap.sh          # Configuração inicial e estrutura
│   ├── engines.sh            # Gerenciamento de engines
│   ├── initializer.sh        # Inicialização de projetos
│   ├── instance.sh           # Preparação de runtime
│   ├── maven.sh              # Integração com Maven
│   ├── network.sh            # Verificação de portas
│   └── projects.sh           # Gerenciamento de projetos
├── engines/                  # Motores instalados (Maven e WildFly)
│   ├── maven-3.9.12/         # Exemplo de Maven
│   └── wildfly-31.0.0.Final/ # Exemplo de WildFly
├── projects/                 # Configurações por projeto
│   └── meu-projeto/          # Pasta do projeto
│       ├── .repo-path        # Caminho do código fonte
│       ├── .env              # Variáveis de ambiente
│       ├── .profiles         # Perfis Maven ativos
│       ├── java-opts         # Opções JVM customizadas
│       ├── standalone.xml    # Configuração WildFly
│       └── .engine-versions  # Versões dos engines
├── templates/                # Templates de configuração
│   ├── .env.example          # Exemplo de .env
│   ├── .profiles.example     # Exemplo de .profiles
│   └── standalone-h2.xml     # Template standalone.xml com H2
└── global.jvm                # Configurações JVM globais
```

## Configuração de Projetos

Cada projeto tem arquivos de configuração na pasta `projects/[nome]/`:

- **`.repo-path`**: Caminho absoluto para o repositório Git do projeto.
- **`.env`**: Variáveis de ambiente (ex: `DB_URL=jdbc:postgresql://localhost:5432/mydb`).
- **`.profiles`**: Perfis Maven ativos (ex: `dev postgres`).
- **`java-opts`**: Opções JVM customizadas (ex: `-Xms1024m -Xmx4096m`).
- **`standalone.xml`**: Configuração do WildFly (datasources, security, etc.).

### Exemplo de .env
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp
RABBITMQ_HOST=localhost
```

### Exemplo de .profiles
```
dev postgres
```

## Engines Suportados

O WildFly Runner suporta múltiplas versões do Maven e WildFly, baixadas automaticamente da internet.

- **Maven**: Versões como 3.5.4, 3.9.12, 3.9.13.
- **WildFly**: Versões como 31.0.0.Final, wildfly-custom (customizado).

Para instalar uma nova versão:
```bash
wf engine install maven 3.9.13
wf engine install wildfly 30.0.0.Final
```

## Exemplos de Uso

### 1. Inicializar e Executar um Projeto Existente

```bash
# Inicializar
wf init meu-app

# Durante a configuração, informe o caminho do repo: /path/to/meu-app-repo

# Executar
wf run meu-app
```

### 2. Desenvolvimento com Debug

```bash
wf watch -d meu-app
```

### 3. Deploy para Produção

```bash
wf deploy -P prod meu-app
```

### 4. Gerenciar Múltiplos Projetos

```bash
wf init app1
wf init app2
wf list
wf run app1
wf run app2
```

## Solução de Problemas

- **Erro de porta ocupada**: O WildFly Runner verifica portas automaticamente. Use `wf status` para ver portas em uso.
- **Problemas com Maven**: Verifique se o perfil Maven está correto em `.profiles`.
- **Engines não encontrados**: Execute `wf engine list` e instale se necessário.
- **Permissões**: Certifique-se de que os scripts em `bin/` e `core/` são executáveis (`chmod +x`).

## Contribuição

Contribuições são bem-vindas! Para contribuir:

1. Fork o repositório.
2. Crie uma branch para sua feature: `git checkout -b minha-feature`.
3. Commit suas mudanças: `git commit -am 'Adiciona minha feature'`.
4. Push para a branch: `git push origin minha-feature`.
5. Abra um Pull Request.

## Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE).

---

**Desenvolvido por Wesley Brito** - [GitHub](https://github.com/wesleybritovlk)
