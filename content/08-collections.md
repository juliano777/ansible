# Collections no Ansible

Uma **collection** é o formato de distribuição de conteúdo do Ansible.   
Ela empacota, em um único pacote versionado, **módulos, plugins, roles,
playbooks e documentação**, que podem ser instalados e atualizados de forma
independente do Ansible em si.

---

## 1. Por que collections existem?

Antes do Ansible 2.10, todos os módulos (milhares) viviam dentro do mesmo
repositório do Ansible.   
Isso tornava as atualizações lentas e o projeto difícil de manter.   
A solução foi separar o conteúdo:

| Pacote | O que contém |
|---|---|
| **`ansible-core`** | O motor (CLI, linguagem de playbooks) e apenas a collection `ansible.builtin` |
| **`ansible`** (pacote da comunidade) | `ansible-core` + um conjunto grande de collections já selecionadas |
| **Collections avulsas** | Instaladas sob demanda via `ansible-galaxy` |

```
┌─────────────────────────────────────────┐
│  ansible (community package)            │
│  ┌───────────────────────────────────┐  │
│  │ ansible-core                      │  │
│  │  └── ansible.builtin              │  │
│  └───────────────────────────────────┘  │
│  + community.general                    │
│  + ansible.posix                        │
│  + amazon.aws, community.docker, ...    │
└─────────────────────────────────────────┘
```

**Benefícios:**

- Ciclos de release independentes para cada collection.
- Instalação apenas do que você realmente usa.
- Versionamento (você pode fixar versões para builds reproduzíveis).
- Possibilidade de criar e distribuir conteúdo próprio (interno ou público).

---

## 2. Nomenclatura: `namespace.collection`

Toda collection é identificada por dois componentes separados por ponto:

```
<namespace>.<collection_name>
```

| Collection | Namespace | Nome |
|---|---|---|
| `ansible.builtin` | `ansible` | `builtin` |
| `ansible.posix` | `ansible` | `posix` |
| `community.general` | `community` | `general` |
| `community.docker` | `community` | `docker` |
| `amazon.aws` | `amazon` | `aws` |
| `kubernetes.core` | `kubernetes` | `core` |

---

## 3. FQCN: Fully Qualified Collection Name

> **Nota sobre o termo:** o nome correto é **FQCN** (*Fully Qualified
> Collection Name*, nome de collection totalmente qualificado), e não "FQDN".
> O FQDN (*Fully Qualified Domain Name*) é um conceito de DNS, como
> `web01.example.com`.   
> Os dois têm a mesma ideia de "nome completo e sem ambiguidade", mas
> pertencem a contextos diferentes.

O **FQCN** é o nome completo de um módulo ou plugin, incluindo a collection
a que ele pertence:

```
<namespace>.<collection_name>.<plugin_name>
```

Em outras palavras: **`namespace.collection.module`**.

```
ansible.builtin.copy
│       │       │
│       │       └── Module (or plugin) name
│       └────────── Collection name
└────────────────── Namespace
```

### 3.1 Short name vs FQCN

```yaml
# Short name (legacy style, ambiguous)
- name: Copy a file
  copy:
    src: app.conf
    dest: /etc/app/app.conf

# FQCN (recommended)
- name: Copy a file
  ansible.builtin.copy:
    src: app.conf
    dest: /etc/app/app.conf
```

### 3.2 Por que usar FQCN?

- **Evita ambiguidade:** duas collections podem ter módulos com o mesmo
  nome.  
  O FQCN deixa claro qual está sendo usado.
- **Clareza:** quem lê o playbook sabe de onde vem cada módulo e qual
  collection precisa estar instalada.
- **Previsibilidade:** não depende de resolução implícita nem da ordem de
  busca.
- **Boas práticas e lint:** o `ansible-lint` sinaliza o uso de nomes curtos
  (regra `fqcn`).
- **Compatibilidade futura:** módulos que mudam de collection continuam
  funcionando via *redirects* declarados no `runtime.yml`.

### 3.3 Exemplos de FQCN

```yaml
tasks:
  # Collection: ansible.builtin (bundled with ansible-core)
  - name: Install a package
    ansible.builtin.package:
      name: nginx
      state: present

  # Collection: ansible.posix
  - name: Open an HTTP port in firewalld
    ansible.posix.firewalld:
      service: http
      permanent: true
      state: enabled
      immediate: true

  # Collection: community.general
  - name: Allow SSH through UFW
    community.general.ufw:
      rule: allow
      port: "22"
      proto: tcp

  # Collection: community.docker
  - name: Run a container
    community.docker.docker_container:
      name: web
      image: nginx:stable
      state: started
      ports:
        - "8080:80"
```

### 3.4 FQCN também vale para outros tipos de plugin

O padrão `namespace.collection.name` se aplica a **filtros, lookups, callbacks, inventory plugins, connection plugins**, entre outros:

```yaml
vars:
  # Lookup plugin with FQCN
  file_content: "{{ lookup('ansible.builtin.file', 'files/message.txt') }}"

  # Filter plugin with FQCN
  config_json: "{{ app_config | ansible.builtin.to_nice_json }}"

  # Filter from another collection
  network_valid: "{{ '192.168.1.10' | ansible.utils.ipaddr }}"
```

Em `ansible.cfg` e em arquivos de inventário:

```ini
[defaults]
callbacks_enabled = ansible.posix.profile_tasks

[inventory]
enable_plugins = amazon.aws.aws_ec2, ansible.builtin.yaml
```

```yaml
# inventory/aws_ec2.yml (inventory plugin referenced by FQCN)
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
```

### 3.5 FQCN para roles dentro de collections

Roles empacotadas em uma collection também são referenciadas pelo FQCN:

```yaml
- name: Use a role shipped in a collection
  hosts: webservers
  roles:
    - role: my_namespace.my_collection.web_server
      vars:
        http_port: 8080

  tasks:
    - name: Include the role dynamically
      ansible.builtin.include_role:
        name: my_namespace.my_collection.web_server
```

---

## 4. O que uma collection pode conter

| Conteúdo | Diretório | Descrição |
|---|---|---|
| **Módulos** | `plugins/modules/` | Unidades que executam ações nos hosts |
| **Filtros** | `plugins/filter/` | Funções Jinja2 (`\|`) |
| **Lookups** | `plugins/lookup/` | Busca de dados externos (`lookup()`) |
| **Inventory plugins** | `plugins/inventory/` | Inventário dinâmico |
| **Connection plugins** | `plugins/connection/` | Formas de conexão (SSH, WinRM, Docker...) |
| **Callbacks** | `plugins/callback/` | Personalização da saída e integrações |
| **Module utils** | `plugins/module_utils/` | Código compartilhado entre módulos |
| **Roles** | `roles/` | Roles reutilizáveis |
| **Playbooks** | `playbooks/` | Playbooks prontos |
| **Documentação** | `docs/` | Guias e exemplos |

---

## 5. Onde encontrar collections

| Fonte | Descrição |
|---|---|
| **Ansible Galaxy** (<https://galaxy.ansible.com>) | Repositório público e comunitário |
| **Red Hat Automation Hub** | Collections certificadas e suportadas (assinatura Red Hat) |
| **Private Automation Hub / Galaxy NG** | Repositório interno da organização |
| **Git** | Repositórios próprios, instalados diretamente |
| **Arquivo `.tar.gz`** | Instalação offline |

Para consultar a documentação de um módulo localmente:

```bash
# Show the documentation of a module using its FQCN
ansible-doc ansible.builtin.copy

# Show only usage examples
ansible-doc -s community.general.ufw

# List all plugins of a collection
ansible-doc -l community.general
```

---

## 6. Instalando collections

### 6.1 Comandos básicos

```bash
# Install the latest version
ansible-galaxy collection install community.general

# Install a specific version
ansible-galaxy collection install community.general:==9.0.0

# Install with a version range
ansible-galaxy collection install "community.general:>=8.0.0,<10.0.0"

# Upgrade to the latest version
ansible-galaxy collection install community.general --upgrade

# Install into a project-local directory
ansible-galaxy collection install community.docker -p ./collections

# Install from a local tarball (offline)
ansible-galaxy collection install ./my_namespace-my_collection-1.0.0.tar.gz

# Install from a Git repository
ansible-galaxy collection install git+https://github.com/my-org/my_collection.git,main

# List installed collections
ansible-galaxy collection list

# Show details of a specific collection
ansible-galaxy collection list community.general
```

### 6.2 Arquivo `requirements.yml` (recomendado)

Declarar as dependências em um arquivo garante que qualquer pessoa (ou pipeline de CI) reproduza o mesmo ambiente.

```yaml
---
# requirements.yml
collections:
  # Latest available version
  - name: ansible.posix

  # Pinned version
  - name: community.docker
    version: "3.10.3"

  # Version range
  - name: community.general
    version: ">=8.0.0,<10.0.0"

  # From a Git repository
  - name: https://github.com/my-org/my_collection.git
    type: git
    version: main

  # From a specific Galaxy server
  - name: my_namespace.internal_tools
    source: https://hub.example.com/api/galaxy/

# Roles can also be listed in the same file
roles:
  - name: geerlingguy.docker
```

```bash
# Install everything declared in the file
ansible-galaxy collection install -r requirements.yml

# Install collections and roles together
ansible-galaxy install -r requirements.yml
```

### 6.3 Onde as collections são instaladas

| Local | Caminho |
|---|---|
| Padrão do usuário | `~/.ansible/collections/ansible_collections/` |
| Sistema | `/usr/share/ansible/collections/ansible_collections/` |
| Projeto (configurável) | `./collections/ansible_collections/` |

Configurando o caminho no `ansible.cfg`:

```ini
[defaults]
collections_path = ./collections:~/.ansible/collections:/usr/share/ansible/collections
```

Configuração dos servidores do Galaxy:

```ini
[galaxy]
server_list = automation_hub, public_galaxy

[galaxy_server.automation_hub]
url = https://console.redhat.com/api/automation-hub/content/published/
auth_url = https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
token = <your_token_here>

[galaxy_server.public_galaxy]
url = https://galaxy.ansible.com/
```

---

## 7. Usando collections em playbooks

### 7.1 Forma recomendada: FQCN

```yaml
---
- name: Prepare a Docker host
  hosts: docker_hosts
  become: true

  tasks:
    - name: Install Docker packages
      ansible.builtin.apt:
        name:
          - docker.io
          - python3-docker
        state: present
        update_cache: true

    - name: Ensure the Docker service is running
      ansible.builtin.service:
        name: docker
        state: started
        enabled: true

    - name: Create a Docker network
      community.docker.docker_network:
        name: app_network
        state: present

    - name: Start the application container
      community.docker.docker_container:
        name: app
        image: nginx:stable
        networks:
          - name: app_network
        restart_policy: unless-stopped
        state: started
```

### 7.2 A palavra-chave `collections` (não recomendada)

É possível declarar uma lista de collections para que nomes curtos sejam resolvidos. Funciona, mas **não é recomendado**: reduz a clareza e reintroduz a ambiguidade.

```yaml
- name: Using the collections keyword (discouraged)
  hosts: all
  collections:
    - community.docker
    - ansible.posix

  tasks:
    # Resolved through the "collections" list above
    - name: Start a container
      docker_container:
        name: app
        image: nginx:stable
        state: started
```

> **Prefira sempre o FQCN.** Ele funciona em qualquer lugar, sem depender de configuração no play.

### 7.3 Verificando se a collection está instalada

Se o módulo não for encontrado, o Ansible exibe um erro como:

```
ERROR! couldn't resolve module/action 'community.docker.docker_container'.
This often indicates a misspelling, missing collection, or incorrect module path.
```

Solução:

```bash
ansible-galaxy collection list | grep community.docker
ansible-galaxy collection install community.docker
```

---

## 8. Collections mais utilizadas

| Collection | Uso principal |
|---|---|
| `ansible.builtin` | Módulos essenciais: `copy`, `template`, `file`, `apt`, `dnf`, `service`, `command`, `debug`, `uri`... |
| `ansible.posix` | `firewalld`, `selinux`, `mount`, `synchronize`, `authorized_key` |
| `ansible.windows` | Gerenciamento de hosts Windows |
| `ansible.utils` | Filtros e utilitários (IP, validação de dados) |
| `community.general` | Grande coleção diversa: `ufw`, `timezone`, `nmcli`, `ini_file`, `modprobe`... |
| `community.crypto` | Certificados, chaves privadas, CSRs |
| `community.docker` | Containers, imagens, redes e volumes Docker |
| `community.postgresql` | Bancos, usuários e extensões PostgreSQL |
| `community.mysql` | MySQL / MariaDB |
| `kubernetes.core` | Recursos Kubernetes e Helm |
| `amazon.aws` | Recursos AWS (EC2, S3, IAM...) |
| `azure.azcollection` | Recursos Azure |
| `google.cloud` | Recursos Google Cloud |

---

## 9. Estrutura de uma collection

```
ansible_collections/
└── my_namespace/
    └── my_collection/
        ├── galaxy.yml                # Collection metadata (required)
        ├── README.md
        ├── meta/
        │   └── runtime.yml           # Ansible version requirements, redirects
        ├── plugins/
        │   ├── modules/
        │   │   └── hello_world.py
        │   ├── filter/
        │   ├── lookup/
        │   ├── inventory/
        │   └── module_utils/
        ├── roles/
        │   └── web_server/
        │       ├── defaults/main.yml
        │       ├── tasks/main.yml
        │       └── handlers/main.yml
        ├── playbooks/
        │   └── site.yml
        ├── docs/
        └── tests/
            ├── unit/
            └── integration/
```

### 9.1 `galaxy.yml`

```yaml
---
namespace: my_namespace
name: my_collection
version: 1.0.0
readme: README.md
authors:
  - Your Name <you@example.com>
description: Internal automation content for web servers
license:
  - GPL-3.0-or-later
tags:
  - web
  - infrastructure
dependencies:
  ansible.posix: ">=1.5.0"
  community.general: ">=8.0.0"
repository: https://github.com/my-org/my_collection
```

### 9.2 `meta/runtime.yml`

```yaml
---
requires_ansible: ">=2.14.0"

plugin_routing:
  modules:
    old_module_name:
      redirect: my_namespace.my_collection.new_module_name
      deprecation:
        removal_version: 3.0.0
        warning_text: Use my_namespace.my_collection.new_module_name instead.
```

Esse mecanismo de `plugin_routing` é o que permite que módulos mudem de collection ou de nome sem quebrar playbooks existentes imediatamente.

---

## 10. Criando e publicando sua própria collection

```bash
# 1. Create the skeleton
ansible-galaxy collection init my_namespace.my_collection

# 2. Develop modules, roles and plugins inside the generated directory

# 3. Build the tarball (run in the collection root)
ansible-galaxy collection build
# Output: my_namespace-my_collection-1.0.0.tar.gz

# 4. Install locally to test
ansible-galaxy collection install ./my_namespace-my_collection-1.0.0.tar.gz --force

# 5. Publish to Galaxy or Automation Hub
ansible-galaxy collection publish ./my_namespace-my_collection-1.0.0.tar.gz --token <your_api_token>
```

### Exemplo de módulo simples (`plugins/modules/hello_world.py`)

```python
#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r"""
---
module: hello_world
short_description: Returns a greeting message
description:
  - Simple example module that returns a greeting.
options:
  name:
    description: Name of the person to greet.
    type: str
    required: true
author:
  - Your Name (@your_handle)
"""

EXAMPLES = r"""
- name: Greet someone
  my_namespace.my_collection.hello_world:
    name: Ansible
"""

RETURN = r"""
message:
  description: The greeting message.
  type: str
  returned: always
  sample: "Hello, Ansible!"
"""

from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            name=dict(type="str", required=True),
        ),
        supports_check_mode=True,
    )

    greeting = "Hello, {0}!".format(module.params["name"])
    module.exit_json(changed=False, message=greeting)


if __name__ == "__main__":
    main()
```

Uso no playbook:

```yaml
- name: Test the custom module
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Say hello
      my_namespace.my_collection.hello_world:
        name: Ansible
      register: greeting_result

    - name: Show the message
      ansible.builtin.debug:
        msg: "{{ greeting_result.message }}"
```

---

## 11. Estrutura de projeto com collections

```
ansible-project/
├── ansible.cfg
├── requirements.yml              # Collections and roles used by the project
├── collections/                  # Local install path (collections_path)
│   └── ansible_collections/
│       ├── ansible/
│       │   └── posix/
│       └── community/
│           └── docker/
├── inventory/
│   └── hosts.yml
├── playbooks/
│   └── site.yml
└── roles/
```

Fluxo típico em um projeto novo:

```bash
# 1. Clone the project
git clone https://github.com/my-org/ansible-project.git && cd ansible-project

# 2. Install the dependencies in the local directory
ansible-galaxy collection install -r requirements.yml -p ./collections

# 3. Run the playbook
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

---

## 12. Boas práticas

- **Use sempre o FQCN** (`namespace.collection.module`) em módulos, filtros, lookups e roles.
- **Declare as dependências em `requirements.yml`** e mantenha o arquivo versionado no Git.
- **Fixe versões** (ou faixas) em ambientes de produção para garantir reprodutibilidade.
- **Instale as collections no diretório do projeto** (`-p ./collections`) para isolar projetos diferentes.
- **Evite a palavra-chave `collections:`** nos plays; ela esconde a origem dos módulos.
- **Use `ansible-doc <FQCN>`** para consultar parâmetros e exemplos sem sair do terminal.
- **Valide com `ansible-lint`**, que identifica nomes curtos e módulos descontinuados.
- **Verifique as dependências do módulo** (por exemplo, `community.docker` exige bibliotecas Python no host de destino).
- **Para ambientes corporativos**, considere um *Private Automation Hub* ou *Galaxy NG* e Execution Environments (imagens de container com collections e dependências já instaladas).
- **Acompanhe avisos de depreciação**: módulos podem mudar de collection ou ser removidos.

---

## 13. Resumo rápido

```
Collection  →  pacote versionado (modules, plugins, roles, playbooks, docs)
Namespace   →  "dono" da collection            (ex.: community)
Collection  →  nome da collection              (ex.: docker)
FQCN        →  namespace.collection.plugin     (ex.: community.docker.docker_container)
Galaxy      →  repositório público de collections
requirements.yml → lista de dependências do projeto
```

| Tarefa | Comando |
|---|---|
| Instalar | `ansible-galaxy collection install <namespace>.<collection>` |
| Instalar via arquivo | `ansible-galaxy collection install -r requirements.yml` |
| Listar instaladas | `ansible-galaxy collection list` |
| Ver documentação | `ansible-doc <FQCN>` |
| Criar esqueleto | `ansible-galaxy collection init <namespace>.<collection>` |
| Empacotar | `ansible-galaxy collection build` |
| Publicar | `ansible-galaxy collection publish <tarball> --token <token>` |

## Referências

- Guia de uso de collections: <https://docs.ansible.com/ansible/latest/collections_guide/index.html>
- Guia de desenvolvimento de collections: <https://docs.ansible.com/ansible/latest/dev_guide/developing_collections.html>
- Ansible Galaxy: <https://galaxy.ansible.com>
- Índice de collections: <https://docs.ansible.com/ansible/latest/collections/index.html>
