# wildfly-runner

architeture:

wf-run/
├── bin/wf               <-- O CLI (Ponto de entrada)
├── core/                <-- Funções internas (Bootstrap, Rede, Sandbox)
├── engines/             <-- Onde ficam o WildFly e o Maven (Auto-instalados)
├── projects/            <-- Configurações de Ambiente (Onde você joga o XML)
│   └── project-name/         <-- Pasta do Ambiente
│       ├── .repo-path   <-- Arquivo oculto que guarda o caminho do código fonte
│       ├── .env         <-- Variáveis de ambiente (URLs, RabbitMQ)
│       ├── .profiles    <-- Perfis do Maven (dev, postgres)
│       ├── java-args    <-- Customização de memória/debug (Opcional)
│       └── standalone.xml <-- Único XML do projeto
├── templates/           <-- Modelos .example para o comando 'init'
└── global.jvm           <-- Configurações de JVM padrão para todos
