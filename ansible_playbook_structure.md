# Estrutura de um Playbook Ansible

Um **playbook** é um arquivo YAML que descreve o *estado desejado* de um conjunto de máquinas. Ele responde a três perguntas: **onde** executar (hosts), **como** executar (usuário, privilégios, variáveis) e **o que** executar (tasks, roles).

---

## 1. Hierarquia geral

```
Playbook (arquivo .yml)
└── Play (1 ou mais)
    ├── Configurações do play (hosts, become, vars, ...)
    ├── pre_tasks
    ├── roles
    ├── tasks
    │   └── Task (chama 1 módulo)
    ├── post_tasks
    └── handlers
```

| Nível | O que é |
|---|---|
| **Playbook** | Arquivo YAML que contém uma lista de plays |
| **Play** | Mapeia um grupo de hosts para um conjunto de tasks/roles |
| **Task** | Uma ação única, que chama um módulo (ex.: instalar um pacote) |
| **Module** | Unidade de código que executa o trabalho (`ansible.builtin.apt`, `ansible.builtin.copy`, ...) |
| **Handler** | Task especial, executada apenas quando notificada por outra task |
| **Role** | Conjunto reutilizável de tasks, variáveis, templates e handlers |

---

## 2. Anatomia básica

Um playbook é uma **lista de plays**. Cada play começa com um hífen (`-`) e é um dicionário YAML.

```yaml
---
# Playbook: install and configure Nginx
- name: Configure web servers          # Play name (free text, shown in the output)
  hosts: webservers                    # Target group from the inventory
  become: true                         # Run tasks with privilege escalation (sudo)
  gather_facts: true                   # Collect system information before running

  vars:                                # Play-level variables
    http_port: 80
    nginx_packages:
      - nginx
      - curl

  tasks:                               # List of tasks (executed in order)
    - name: Install required packages
      ansible.builtin.apt:
        name: "{{ nginx_packages }}"
        state: present
        update_cache: true

    - name: Deploy Nginx configuration
      ansible.builtin.template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: "0644"
      notify: Restart Nginx            # Triggers the handler below

    - name: Ensure Nginx is running and enabled
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

  handlers:                            # Only run when notified
    - name: Restart Nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
```

### Pontos importantes de sintaxe YAML

- O arquivo normalmente começa com `---` (opcional, mas é uma convenção).
- **Indentação com espaços** (nunca tabs). O padrão é 2 espaços.
- Listas usam `-`; dicionários usam `chave: valor`.
- Valores com `{{ }}` (Jinja2) **precisam de aspas** quando aparecem no início do valor: `"{{ variable }}"`.
- Booleanos recomendados: `true` / `false`.
- Comentários começam com `#`.

---

## 3. Palavras-chave do Play

Estas são as diretivas mais comuns no nível do play:

```yaml
- name: Example play with common keywords
  hosts: databases                 # Required: host pattern or group
  remote_user: deploy              # SSH user
  become: true                     # Enable privilege escalation
  become_user: root                # User to become (default: root)
  gather_facts: true               # Run the setup module automatically
  serial: 2                        # Run on 2 hosts at a time (rolling update)
  strategy: linear                 # linear (default), free, debug
  environment:                     # Environment variables for all tasks
    http_proxy: http://proxy.example.com:3128
  tags:
    - database

  vars:                            # Inline variables
    db_port: 5432

  vars_files:                      # Load variables from external files
    - vars/common.yml
    - vars/secrets.yml

  vars_prompt:                     # Ask the user for a value at runtime
    - name: db_password
      prompt: "Enter the database password"
      private: true

  pre_tasks: []                    # Run before roles
  roles: []                        # Roles to apply
  tasks: []                        # Main task list
  post_tasks: []                   # Run after tasks
  handlers: []                     # Notified tasks
```

| Palavra-chave | Função |
|---|---|
| `name` | Descrição legível do play |
| `hosts` | Hosts ou grupos do inventário (`all`, `webservers`, `web*`, `db:&prod`) |
| `become` / `become_user` | Escalonamento de privilégio |
| `remote_user` | Usuário da conexão SSH |
| `gather_facts` | Coleta (ou não) de *facts* do host |
| `vars` / `vars_files` / `vars_prompt` | Fontes de variáveis |
| `serial` | Quantidade de hosts por lote (deploys graduais) |
| `strategy` | Estratégia de execução |
| `environment` | Variáveis de ambiente para as tasks |
| `tags` | Etiquetas para execução seletiva |

---

## 4. Ordem de execução dentro de um play

1. `pre_tasks`
2. Handlers notificados por `pre_tasks`
3. `roles`
4. `tasks`
5. Handlers notificados por `roles` e `tasks`
6. `post_tasks`
7. Handlers notificados por `post_tasks`

```yaml
- name: Execution order demo
  hosts: all
  pre_tasks:
    - name: Runs first
      ansible.builtin.debug:
        msg: "pre_tasks"
  roles:
    - common
  tasks:
    - name: Runs after roles
      ansible.builtin.debug:
        msg: "tasks"
  post_tasks:
    - name: Runs last
      ansible.builtin.debug:
        msg: "post_tasks"
```

> **Dica:** mesmo que você escreva `tasks` antes de `roles` no arquivo, os roles são executados primeiro.

---

## 5. Anatomia de uma Task

```yaml
- name: Create application directory       # Always name your tasks
  ansible.builtin.file:                    # Module (use the FQCN)
    path: /opt/app                         # Module arguments
    state: directory
    mode: "0755"
  register: app_dir_result                 # Save the result in a variable
  when: ansible_os_family == "Debian"      # Conditional
  tags:
    - setup
  notify: Reload app                       # Notify a handler
  ignore_errors: false                     # Continue even if it fails?
  changed_when: false                      # Override the "changed" status
  failed_when: app_dir_result.rc != 0      # Override the "failed" status
  delegate_to: localhost                   # Run on another host
  become: true                             # Task-level privilege escalation
```

### Palavras-chave comuns de task

| Palavra-chave | Descrição |
|---|---|
| `name` | Descrição da task (aparece na saída) |
| *módulo* | O módulo e seus argumentos |
| `register` | Armazena o retorno do módulo em uma variável |
| `when` | Executa somente se a condição for verdadeira |
| `loop` | Repete a task para cada item de uma lista |
| `notify` | Aciona um ou mais handlers (apenas se houver mudança) |
| `tags` | Permite executar/pular tasks seletivamente |
| `ignore_errors` | Segue em frente mesmo com falha |
| `changed_when` / `failed_when` | Redefinem quando a task é considerada alterada/falha |
| `delegate_to` | Executa a task em outro host |
| `until` / `retries` / `delay` | Repete a task até que uma condição seja atendida |

### Exemplo com `loop` e `when`

```yaml
- name: Create system users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    state: present
  loop:
    - { name: alice, groups: sudo }
    - { name: bob,   groups: developers }
  when: create_users | default(true)
```

### Exemplo com `register` e `debug`

```yaml
- name: Check disk usage
  ansible.builtin.command: df -h /
  register: disk_usage
  changed_when: false

- name: Show the result
  ansible.builtin.debug:
    var: disk_usage.stdout_lines
```

---

## 6. Variáveis

### 6.1 Onde definir variáveis

```yaml
# 1. Inline in the play
vars:
  app_name: myapp

# 2. External file
vars_files:
  - vars/main.yml

# 3. At runtime (command line)
# ansible-playbook site.yml -e "app_name=myapp"

# 4. From a task result
- name: Get hostname
  ansible.builtin.command: hostname
  register: current_hostname

# 5. Defined during execution
- name: Define a variable dynamically
  ansible.builtin.set_fact:
    deploy_path: "/opt/{{ app_name }}"
```

Outros locais comuns: `inventory`, `group_vars/`, `host_vars/` e `defaults/` / `vars/` dentro de roles.

### 6.2 Usando variáveis (Jinja2)

```yaml
- name: Print a message
  ansible.builtin.debug:
    msg: "Deploying {{ app_name }} on {{ inventory_hostname }}"

- name: Use a default value
  ansible.builtin.debug:
    msg: "Port: {{ http_port | default(8080) }}"

- name: Access a dictionary
  ansible.builtin.debug:
    msg: "{{ database.host }}:{{ database.port }}"
  vars:
    database:
      host: db01.example.com
      port: 5432
```

### 6.3 Facts

*Facts* são informações coletadas automaticamente sobre cada host quando `gather_facts: true`.

```yaml
- name: Show some facts
  ansible.builtin.debug:
    msg: >-
      OS: {{ ansible_distribution }} {{ ansible_distribution_version }},
      CPUs: {{ ansible_processor_vcpus }},
      Memory (MB): {{ ansible_memtotal_mb }}
```

### 6.4 Precedência de variáveis (simplificada)

Da **menor** para a **maior** prioridade:

1. `defaults/main.yml` do role
2. Variáveis de inventário / `group_vars` / `host_vars`
3. Facts e variáveis registradas
4. `vars` do play e `vars_files`
5. `vars/main.yml` do role
6. `set_fact` / `register`
7. Variáveis de task (`vars` na task)
8. **Extra vars** (`-e`) — sempre vencem

---

## 7. Handlers

Handlers são tasks que só executam **quando notificadas** por uma task que provocou mudança (`changed`). Executam **uma única vez**, ao final do bloco de tasks, mesmo que sejam notificados várias vezes.

```yaml
tasks:
  - name: Update the SSH configuration
    ansible.builtin.template:
      src: sshd_config.j2
      dest: /etc/ssh/sshd_config
    notify:
      - Validate SSH config
      - Restart SSH

handlers:
  - name: Validate SSH config
    ansible.builtin.command: sshd -t
    changed_when: false

  - name: Restart SSH
    ansible.builtin.service:
      name: sshd
      state: restarted
```

Para forçar a execução imediata dos handlers pendentes:

```yaml
- name: Flush handlers now
  ansible.builtin.meta: flush_handlers
```

---

## 8. Blocos e tratamento de erros

`block` agrupa tasks; `rescue` executa em caso de falha; `always` executa sempre.

```yaml
tasks:
  - name: Deploy the application with error handling
    block:
      - name: Download the artifact
        ansible.builtin.get_url:
          url: "https://example.com/app-{{ app_version }}.tar.gz"
          dest: /tmp/app.tar.gz

      - name: Extract the artifact
        ansible.builtin.unarchive:
          src: /tmp/app.tar.gz
          dest: /opt/app
          remote_src: true
    rescue:
      - name: Log the failure
        ansible.builtin.debug:
          msg: "Deployment failed on {{ inventory_hostname }}"
    always:
      - name: Remove the temporary file
        ansible.builtin.file:
          path: /tmp/app.tar.gz
          state: absent
    when: deploy_enabled | default(true)
```

---

## 9. Vários plays em um mesmo playbook

Um playbook pode orquestrar diferentes grupos de hosts em sequência.

```yaml
---
- name: Configure database servers
  hosts: databases
  become: true
  tasks:
    - name: Install PostgreSQL
      ansible.builtin.apt:
        name: postgresql
        state: present

- name: Configure application servers
  hosts: appservers
  become: true
  tasks:
    - name: Install the runtime
      ansible.builtin.apt:
        name: openjdk-17-jre
        state: present

- name: Run smoke tests from the control node
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Check the application endpoint
      ansible.builtin.uri:
        url: "http://{{ groups['appservers'][0] }}:8080/health"
        status_code: 200
```

---

## 10. Roles, `import_*` e `include_*`

### 10.1 Usando roles

```yaml
- name: Apply roles to web servers
  hosts: webservers
  become: true
  roles:
    - common
    - role: nginx
      vars:
        http_port: 8080
    - role: app
      tags: [app]
```

### 10.2 Estrutura de um role

```
roles/
└── nginx/
    ├── defaults/main.yml     # Default variables (lowest precedence)
    ├── vars/main.yml         # Role variables (high precedence)
    ├── tasks/main.yml        # Task list
    ├── handlers/main.yml     # Handlers
    ├── templates/            # Jinja2 templates (.j2)
    ├── files/                # Static files
    ├── meta/main.yml         # Metadata and dependencies
    └── README.md
```

### 10.3 Reaproveitando arquivos de tasks e playbooks

```yaml
tasks:
  # Static: processed when the playbook is parsed
  - name: Import common tasks
    ansible.builtin.import_tasks: tasks/common.yml

  # Dynamic: processed when execution reaches this point
  - name: Include OS-specific tasks
    ansible.builtin.include_tasks: "tasks/{{ ansible_os_family | lower }}.yml"

# Import another playbook (top level)
- ansible.builtin.import_playbook: database.yml
```

| | `import_*` | `include_*` |
|---|---|---|
| Processamento | Estático (parse time) | Dinâmico (runtime) |
| Aceita `loop` | Não | Sim |
| Tags / `when` | Aplicados a todas as tasks importadas | Aplicados apenas à própria inclusão |
| Uso típico | Estrutura fixa | Nome de arquivo variável ou condicional |

---

## 11. Estrutura de diretórios recomendada

```
ansible-project/
├── ansible.cfg                 # Project configuration
├── inventory/
│   ├── production/
│   │   ├── hosts.yml
│   │   ├── group_vars/
│   │   │   ├── all.yml
│   │   │   └── webservers.yml
│   │   └── host_vars/
│   │       └── web01.yml
│   └── staging/
│       └── hosts.yml
├── playbooks/
│   ├── site.yml                # Main entry point
│   ├── webservers.yml
│   └── databases.yml
├── roles/
│   ├── common/
│   ├── nginx/
│   └── postgresql/
├── templates/
├── files/
└── requirements.yml            # Collections and roles from Galaxy
```

Exemplo de inventário em YAML:

```yaml
all:
  children:
    webservers:
      hosts:
        web01.example.com:
        web02.example.com:
    databases:
      hosts:
        db01.example.com:
          ansible_user: admin
```

---

## 12. Executando um playbook

```bash
# Basic execution
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml

# Validate syntax only
ansible-playbook playbooks/site.yml --syntax-check

# Dry run (no changes applied) showing the differences
ansible-playbook playbooks/site.yml --check --diff

# Limit the execution to a subset of hosts
ansible-playbook playbooks/site.yml --limit web01.example.com

# Run only specific tags (or skip them)
ansible-playbook playbooks/site.yml --tags "setup,config"
ansible-playbook playbooks/site.yml --skip-tags "slow"

# Pass extra variables
ansible-playbook playbooks/site.yml -e "app_version=1.2.3"

# Ask for the sudo password / vault password
ansible-playbook playbooks/site.yml --ask-become-pass --ask-vault-pass

# Increase verbosity (-v, -vv, -vvv)
ansible-playbook playbooks/site.yml -vvv

# List tasks / hosts without running
ansible-playbook playbooks/site.yml --list-tasks
ansible-playbook playbooks/site.yml --list-hosts
```

### Interpretando o resultado

Ao final da execução, o Ansible exibe o **PLAY RECAP**:

```
PLAY RECAP *********************************************************
web01.example.com : ok=6  changed=2  unreachable=0  failed=0  skipped=1  rescued=0  ignored=0
```

| Campo | Significado |
|---|---|
| `ok` | Tasks executadas com sucesso (incluindo as sem mudança) |
| `changed` | Tasks que alteraram o estado do host |
| `unreachable` | Host inacessível (SSH/conexão) |
| `failed` | Tasks que falharam |
| `skipped` | Tasks ignoradas por causa de `when` |
| `rescued` | Falhas tratadas por `rescue` |
| `ignored` | Falhas ignoradas por `ignore_errors` |

---

## 13. Idempotência

Um playbook bem escrito é **idempotente**: executá-lo várias vezes produz o mesmo resultado, e a partir da segunda execução o esperado é `changed=0`.

```yaml
# Idempotent: declares the desired state
- name: Ensure the package is installed
  ansible.builtin.apt:
    name: nginx
    state: present

# Not idempotent: runs every time
- name: Install the package with a raw command
  ansible.builtin.command: apt-get install -y nginx
```

Quando precisar usar `command` / `shell`, use `creates`, `removes` ou `changed_when` para controlar o estado:

```yaml
- name: Initialize the database only once
  ansible.builtin.command: /opt/app/bin/init-db.sh
  args:
    creates: /opt/app/.db_initialized
```

---

## 14. Boas práticas

- **Dê nome a todas as tasks e plays**: facilita a leitura da saída e a depuração.
- **Use FQCN** (`ansible.builtin.copy` em vez de `copy`) para evitar ambiguidade entre coleções.
- **Prefira módulos específicos** a `command` / `shell`.
- **Mantenha a idempotência** e teste com `--check --diff`.
- **Separe variáveis do código**: use `group_vars`, `host_vars` e `defaults/`.
- **Proteja segredos com Ansible Vault** (`ansible-vault encrypt_string`, `ansible-vault encrypt`).
- **Organize em roles** quando houver reuso ou o playbook crescer.
- **Use `tags`** para execuções parciais.
- **Valide com `ansible-lint`** e `--syntax-check` antes de executar em produção.
- **Evite lógica complexa em Jinja2**; prefira filtros simples e `set_fact` para clareza.
- **Versione tudo no Git**, incluindo o inventário (sem segredos em texto puro).

---

## 15. Exemplo completo: `site.yml`

```yaml
---
- name: Provision web servers
  hosts: webservers
  become: true
  gather_facts: true
  serial: 1

  vars_files:
    - vars/common.yml

  vars:
    app_name: myapp
    http_port: 80

  pre_tasks:
    - name: Update the apt cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

  roles:
    - role: common
    - role: nginx
      vars:
        nginx_listen_port: "{{ http_port }}"

  tasks:
    - name: Create the application directory
      ansible.builtin.file:
        path: "/opt/{{ app_name }}"
        state: directory
        owner: www-data
        group: www-data
        mode: "0755"

    - name: Deploy the index page
      ansible.builtin.template:
        src: index.html.j2
        dest: "/var/www/html/index.html"
        mode: "0644"
      notify: Reload Nginx

    - name: Verify the service responds
      ansible.builtin.uri:
        url: "http://{{ inventory_hostname }}:{{ http_port }}"
        status_code: 200
      register: health_check
      retries: 5
      delay: 3
      until: health_check.status == 200

  post_tasks:
    - name: Print a final message
      ansible.builtin.debug:
        msg: "{{ app_name }} deployed on {{ inventory_hostname }}"

  handlers:
    - name: Reload Nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

---

## Resumo rápido

```
Playbook  →  lista de Plays
Play      →  hosts + configurações + (pre_tasks, roles, tasks, post_tasks, handlers)
Task      →  name + módulo + argumentos + (when, loop, register, notify, tags...)
Handler   →  task executada somente quando notificada
Role      →  pacote reutilizável (tasks, vars, templates, handlers, defaults)
```

## Referências

- Documentação oficial de playbooks: <https://docs.ansible.com/ansible/latest/playbook_guide/index.html>
- Referência de palavras-chave: <https://docs.ansible.com/ansible/latest/reference_appendices/playbooks_keywords.html>
- Índice de módulos builtin: <https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html>
