# wildfly-runner

architeture:

wf-run/
├── bin/
│   └── wf              <-- O executável principal (CLI)
├── core/
│   ├── bootstrap.sh    <-- Instala Maven/WildFly se não existirem
│   ├── network.sh      <-- Lógica de portas e offsets
│   └── instance.sh     <-- Criação da pasta de runtime isolada
├── engines/            <-- Onde os binários "limpos" são baixados
│   ├── wildfly-26.x/
│   └── maven-3.9/
├── storage/            <-- Onde o estado é salvo
│   └── profiles.db     <-- Guarda os perfis "fixados"
└── templates/          <-- Arquivos .env e .java-args padrão
