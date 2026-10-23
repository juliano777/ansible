# Ferramentas de linha de comando do Ansible

O Ansible não é formado apenas pelo comando `ansible-playbook`. O
`ansible-core` fornece um conjunto de ferramentas de linha de comando para
executar tarefas, consultar documentação, inspecionar inventários, trabalhar
com Collections e Roles, proteger segredos e testar conteúdo de automação.

As principais ferramentas são:

| Comando | Finalidade principal |
|---|---|
| `ansible` | Executar comandos *ad hoc* |
| `ansible-config` | Consultar e analisar configurações |
| `ansible-console` | Executar tarefas interativamente |
| `ansible-doc` | Consultar documentação local de plugins e módulos |
| `ansible-galaxy` | Gerenciar Roles e Collections |
| `ansible-inventory` | Inspecionar e validar inventários |
| `ansible-playbook` | Executar Playbooks |
| `ansible-pull` | Usar Ansible no modelo *pull* |
| `ansible-test` | Testar módulos, plugins e Collections |
| `ansible-vault` | Criptografar dados sensíveis |

> **Nota:** a documentação de comandos de uso geral do Ansible lista
> `ansible`, `ansible-config`, `ansible-console`, `ansible-doc`,
> `ansible-galaxy`, `ansible-inventory`, `ansible-playbook`, `ansible-pull`
> e `ansible-vault`. O `ansible-test` também é fornecido pelo
> `ansible-core`, mas é voltado principalmente ao desenvolvimento e aos
> testes do próprio Ansible e de Collections.

---

## 1. `ansible`

O comando `ansible` é utilizado principalmente para executar tarefas
**ad hoc**, ou seja, tarefas pontuais sem a necessidade de criar um
Playbook.

A estrutura básica é:

```bash
ansible <hosts> -i <inventory> -m <module> -a "<arguments>"
```

### Testando a comunicação

```bash
ansible all -i inventory.ini -m ansible.builtin.ping
```

O módulo `ping` não envia um ICMP Echo Request. Ele testa se o Ansible
consegue se conectar ao host e executar Python no sistema remoto.

### Verificando o tempo de atividade

```bash
ansible all -i inventory.ini \
  -m ansible.builtin.command \
  -a "uptime"
```

### Executando apenas em um grupo

```bash
ansible webservers -i inventory.ini \
  -m ansible.builtin.command \
  -a "hostname"
```

### Usando privilégio administrativo

```bash
ansible webservers -i inventory.ini \
  -b \
  -m ansible.builtin.package \
  -a "name=vim state=present"
```

A opção `-b` ativa o mecanismo de **become**, normalmente utilizando
`sudo`.

### Quando utilizar

O `ansible` é muito útil para:

- testes rápidos;
- diagnóstico;
- validação de conectividade;
- coleta pontual de informações;
- execução de uma tarefa simples em vários hosts.

Para automações repetíveis e mais complexas, normalmente é melhor criar um
Playbook.

---

## 2. `ansible-config`

O `ansible-config` permite consultar as configurações reconhecidas pelo
Ansible e identificar de onde determinados valores estão sendo obtidos.

O Ansible pode receber configurações de várias fontes, como:

- arquivo `ansible.cfg`;
- variáveis de ambiente;
- opções de linha de comando;
- valores padrão do próprio Ansible.

### Mostrando as configurações efetivas

```bash
ansible-config dump
```

A saída pode ser extensa.

Para mostrar apenas configurações alteradas em relação aos valores padrão:

```bash
ansible-config dump --only-changed
```

Esse é um dos comandos mais úteis para troubleshooting.

### Visualizando o arquivo de configuração utilizado

```bash
ansible-config view
```

### Descobrindo qual arquivo está sendo usado

Outra forma simples é:

```bash
ansible --version
```

A saída informa, entre outros dados, o arquivo de configuração carregado.

### Gerando um arquivo de configuração de referência

```bash
ansible-config init --disabled > ansible.cfg
```

Isso gera um arquivo com diversas opções comentadas, útil como referência
para a criação de um `ansible.cfg`.

### Quando utilizar

O `ansible-config` é especialmente útil para responder perguntas como:

- qual inventário está configurado?
- qual é o número de `forks`?
- qual usuário remoto está sendo utilizado?
- qual configuração sobrescreveu o valor padrão?
- qual arquivo `ansible.cfg` está ativo?

---

## 3. `ansible-console`

O `ansible-console` disponibiliza um ambiente interativo, no estilo
**REPL** (*Read-Eval-Print Loop*), para executar tarefas Ansible.

Em vez de executar um novo comando `ansible` a cada operação, é possível
abrir uma sessão e trabalhar interativamente.

### Abrindo o console

```bash
ansible-console -i inventory.ini webservers
```

Dentro do console:

```text
ping
```

É equivalente, conceitualmente, a executar o módulo
`ansible.builtin.ping` contra o grupo selecionado.

Outro exemplo:

```text
command uptime
```

Também é possível consultar ajuda:

```text
help
```

Ou ajuda relacionada a um módulo:

```text
help copy
```

Para sair:

```text
exit
```

### Quando utilizar

É útil para:

- troubleshooting;
- testes interativos;
- exploração de módulos;
- execução de várias operações consecutivas no mesmo conjunto de hosts.

---

## 4. `ansible-doc`

O `ansible-doc` permite consultar a documentação dos módulos, plugins,
filtros, testes e outros componentes instalados localmente.

Isso é particularmente útil porque a documentação consultada corresponde
ao conteúdo efetivamente disponível naquele ambiente.

### Consultando um módulo

```bash
ansible-doc ansible.builtin.copy
```

### Obtendo um resumo do módulo

```bash
ansible-doc -s ansible.builtin.copy
```

### Listando módulos disponíveis

```bash
ansible-doc -t module -l
```

### Listando filtros disponíveis

```bash
ansible-doc -t filter -l
```

### Consultando um filtro

```bash
ansible-doc -t filter ansible.builtin.default
```

### Quando utilizar

O `ansible-doc` é útil para descobrir:

- quais parâmetros um módulo aceita;
- exemplos de utilização;
- valores obrigatórios;
- tipos dos parâmetros;
- módulos e plugins instalados;
- filtros e testes disponíveis.

Antes de procurar a documentação de um módulo na Internet, muitas vezes
vale executar:

```bash
ansible-doc <nome_do_modulo>
```

---

## 5. `ansible-galaxy`

O `ansible-galaxy` gerencia conteúdo reutilizável do Ansible,
principalmente:

- **Roles**;
- **Collections**.

Uma Collection pode conter módulos, plugins, Roles, Playbooks e outros
componentes de automação.

### Listando Collections instaladas

```bash
ansible-galaxy collection list
```

### Instalando uma Collection

```bash
ansible-galaxy collection install community.general
```

### Instalando Collections a partir de um arquivo

Exemplo de `requirements.yml`:

```yaml
---
collections:
  - name: community.general
  - name: ansible.posix
...
```

Instalação:

```bash
ansible-galaxy collection install -r requirements.yml
```

### Criando a estrutura de uma Role

```bash
ansible-galaxy role init webserver
```

Será criada uma estrutura semelhante a:

```text
webserver/
├── defaults/
├── files/
├── handlers/
├── meta/
├── tasks/
├── templates/
├── tests/
├── vars/
└── README.md
```

### Criando uma Collection

```bash
ansible-galaxy collection init empresa.linux
```

### Quando utilizar

O `ansible-galaxy` é utilizado para:

- instalar Collections;
- instalar Roles;
- criar a estrutura inicial de Roles;
- criar Collections;
- listar conteúdo instalado;
- construir e publicar Collections.

---

## 6. `ansible-inventory`

O `ansible-inventory` permite visualizar o inventário exatamente como o
Ansible o interpretou.

Isso é especialmente importante quando são utilizados:

- grupos;
- grupos filhos;
- variáveis;
- inventários YAML;
- inventários dinâmicos;
- plugins de inventário.

### Exibindo o inventário como árvore

```bash
ansible-inventory -i inventory.ini --graph
```

Exemplo de saída:

```text
@all:
  |--@ungrouped:
  |--@webservers:
  |  |--web01
  |  |--web02
  |--@databases:
  |  |--db01
```

### Exibindo todo o inventário

```bash
ansible-inventory -i inventory.ini --list
```

Por padrão, a saída é apresentada em JSON.

Para visualizar em YAML:

```bash
ansible-inventory -i inventory.ini --list --yaml
```

### Exibindo informações de um host

```bash
ansible-inventory -i inventory.ini --host web01
```

### Exibindo variáveis no gráfico

```bash
ansible-inventory -i inventory.ini --graph --vars
```

### Quando utilizar

É uma ferramenta importante para:

- validar inventários;
- verificar se um host pertence ao grupo correto;
- diagnosticar variáveis de inventário;
- testar inventários dinâmicos;
- entender como o Ansible está enxergando a infraestrutura.

---

## 7. `ansible-playbook`

O `ansible-playbook` é uma das ferramentas mais utilizadas no Ansible.

Ele executa **Playbooks**, que descrevem conjuntos de tarefas de automação
em YAML.

Considere o seguinte arquivo `webserver.yml`:

```yaml
---
- name: Configure web servers
  hosts: webservers
  become: true

  tasks:
    - name: Install nginx
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Start nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
...
```

Execução:

```bash
ansible-playbook -i inventory.ini webserver.yml
```

### Verificando apenas a sintaxe

```bash
ansible-playbook --syntax-check webserver.yml
```

### Simulando a execução

```bash
ansible-playbook -i inventory.ini webserver.yml --check
```

O **check mode** tenta prever as mudanças sem aplicá-las.

Nem todos os módulos conseguem representar perfeitamente uma execução em
`--check`.

### Mostrando diferenças

```bash
ansible-playbook -i inventory.ini webserver.yml --check --diff
```

### Limitando a execução a um host

```bash
ansible-playbook -i inventory.ini webserver.yml \
  --limit web01
```

### Executando apenas determinadas tags

```bash
ansible-playbook -i inventory.ini site.yml \
  --tags packages
```

### Quando utilizar

Use `ansible-playbook` quando a automação precisar ser:

- documentada;
- repetível;
- versionada;
- idempotente;
- composta por várias tarefas;
- compartilhada com outras pessoas.

---

## 8. `ansible-pull`

Normalmente o Ansible trabalha no modelo **push**:

```text
Control Node
     |
     | SSH / WinRM / API
     v
Managed Nodes
```

O Control Node inicia a automação e envia as tarefas aos Managed Nodes.

O `ansible-pull` permite inverter esse modelo.

No modelo **pull**, cada máquina obtém sua própria configuração de um
repositório de versionamento e executa o Playbook localmente:

```text
          Git Repository
               ^
               |
        git clone / pull
               |
    +----------+----------+
    |          |          |
   host1      host2      host3
```

### Exemplo

```bash
ansible-pull \
  -U https://github.com/example/ansible-config.git \
  local.yml
```

O host:

1. acessa o repositório;
2. obtém o conteúdo;
3. localiza o Playbook;
4. executa a automação localmente.

É comum combinar `ansible-pull` com um agendador, como `cron` ou
`systemd timer`.

### Executando somente quando houver alterações no repositório

```bash
ansible-pull \
  -U https://github.com/example/ansible-config.git \
  --only-if-changed \
  local.yml
```

### Quando utilizar

Pode ser interessante em:

- ambientes com grande quantidade de hosts;
- máquinas que precisam se autocorrigir periodicamente;
- estações ou servidores que consultam uma configuração central;
- ambientes em que o Control Node não consegue iniciar conexão com todos
  os hosts.

---

## 9. `ansible-test`

O `ansible-test` é voltado principalmente ao **desenvolvimento e teste de
conteúdo Ansible**.

Ele é utilizado por desenvolvedores de:

- módulos;
- plugins;
- Collections;
- componentes do `ansible-core`.

Não é uma ferramenta normalmente necessária para simplesmente executar
Playbooks.

### Executando testes de sanidade

Dentro da estrutura de uma Collection:

```bash
ansible-test sanity
```

Esses testes executam verificações estáticas e validam diversos padrões
esperados pelo projeto Ansible.

Também é possível executá-los em um container:

```bash
ansible-test sanity --docker
```

### Executando testes unitários

```bash
ansible-test units
```

Ou em ambiente isolado:

```bash
ansible-test units --docker
```

### Executando testes de integração

```bash
ansible-test integration
```

Um alvo específico pode ser informado:

```bash
ansible-test integration ping
```

### Estrutura de Collection

Para testar uma Collection, normalmente ela deve estar em uma estrutura
compatível com:

```text
ansible_collections/
└── namespace/
    └── collection/
```

Por exemplo:

```text
~/ansible_collections/empresa/linux/
```

### Quando utilizar

Use `ansible-test` quando estiver:

- desenvolvendo módulos;
- escrevendo plugins;
- criando Collections;
- preparando conteúdo para publicação;
- construindo pipelines de CI para conteúdo Ansible.

Para validar Playbooks comuns, outras ferramentas também são importantes,
como `ansible-playbook --syntax-check` e ferramentas externas como
`ansible-lint`.

---

## 10. `ansible-vault`

O `ansible-vault` permite criptografar informações sensíveis utilizadas
pelo Ansible.

Exemplos:

- senhas;
- tokens;
- chaves;
- credenciais de banco de dados;
- variáveis sensíveis.

### Criando um novo arquivo criptografado

```bash
ansible-vault create secrets.yml
```

O Ansible solicitará uma senha e abrirá um editor.

Ao salvar o arquivo, o conteúdo será armazenado criptografado.

### Criptografando um arquivo existente

```bash
ansible-vault encrypt secrets.yml
```

### Visualizando um arquivo criptografado

```bash
ansible-vault view secrets.yml
```

### Editando um arquivo criptografado

```bash
ansible-vault edit secrets.yml
```

### Descriptografando permanentemente

```bash
ansible-vault decrypt secrets.yml
```

Esse comando deixa novamente o arquivo em texto claro, portanto deve ser
utilizado com cuidado.

### Criptografando apenas uma variável

Uma alternativa é criptografar somente o valor sensível:

```bash
ansible-vault encrypt_string \
  --ask-vault-pass \
  --name db_password
```

O comando solicitará o valor e produzirá uma estrutura semelhante a:

```yaml
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...
```

Assim, um arquivo pode possuir variáveis normais e apenas determinados
valores criptografados.

### Executando um Playbook que usa Vault

```bash
ansible-playbook site.yml --ask-vault-pass
```

Também é possível trabalhar com arquivos de senha ou **Vault IDs**, quando
há necessidade de separar diferentes grupos de segredos.

### Atenção

O Ansible Vault protege os dados **em repouso**.

Depois que a informação é descriptografada durante a execução, é
responsabilidade do Playbook evitar sua exposição em logs e saídas.

Para tarefas que lidam com segredos, pode ser necessário utilizar:

```yaml
no_log: true
```

---

# Fluxo de trabalho típico

Essas ferramentas costumam ser utilizadas em conjunto.

Por exemplo:

### 1. Inspecionar o ambiente

```bash
ansible --version
ansible-config dump --only-changed
```

### 2. Verificar o inventário

```bash
ansible-inventory -i inventory.ini --graph
```

### 3. Testar conectividade

```bash
ansible all -i inventory.ini -m ansible.builtin.ping
```

### 4. Consultar a documentação de um módulo

```bash
ansible-doc ansible.builtin.package
```

### 5. Verificar a sintaxe do Playbook

```bash
ansible-playbook --syntax-check site.yml
```

### 6. Simular alterações

```bash
ansible-playbook -i inventory.ini site.yml --check --diff
```

### 7. Executar

```bash
ansible-playbook -i inventory.ini site.yml
```

### 8. Proteger variáveis sensíveis

```bash
ansible-vault encrypt group_vars/all/secrets.yml
```

---

# Resumo

Uma forma simples de memorizar a função de cada ferramenta é:

```text
ansible
    Executa tarefas rápidas e ad hoc.

ansible-config
    Mostra como o Ansible está configurado.

ansible-console
    Permite trabalhar interativamente.

ansible-doc
    Consulta a documentação instalada.

ansible-galaxy
    Gerencia Roles e Collections.

ansible-inventory
    Mostra como o Ansible interpreta o inventário.

ansible-playbook
    Executa automações descritas em Playbooks.

ansible-pull
    Inverte o modelo tradicional e executa a automação a partir do host.

ansible-test
    Testa código e conteúdo desenvolvido para o ecossistema Ansible.

ansible-vault
    Protege informações sensíveis.
```

# Referências

- Ansible Community Documentation — Using Ansible command line tools:
  <https://docs.ansible.com/projects/ansible/latest/command_guide/>
- Ansible Community Documentation — CLI tools:
  <https://docs.ansible.com/projects/ansible/latest/cli/>
- Ansible Community Documentation — Testing Ansible and Collections:
  <https://docs.ansible.com/projects/ansible/latest/dev_guide/testing_running_locally.html>
- Ansible Community Documentation — Ansible Vault:
  <https://docs.ansible.com/projects/ansible/latest/vault_guide/vault.html>
