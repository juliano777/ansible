# Capítulo: Ansible Galaxy

## 1. Introdução

### 1.1 O que é o Ansible Galaxy

O **Ansible Galaxy** é o ecossistema de **compartilhamento de conteúdo** do Ansible. Ele reúne duas coisas:

1. **O repositório público** em [galaxy.ansible.com](https://galaxy.ansible.com), onde a comunidade publica **roles** e **collections** prontas para uso.
2. **A ferramenta de linha de comando `ansible-galaxy`**, que vem com o `ansible-core` e serve para **instalar, criar, listar, construir e publicar** esse conteúdo (no Galaxy público ou em um servidor privado).

Em vez de escrever do zero a automação para o PostgreSQL, o Nginx ou o AWS, você instala o que alguém já publicou e testou. E o que **você** escreve também pode ser empacotado e compartilhado, com a sua equipe ou com o mundo.

### 1.2 Roles e collections

| | Role | Collection |
|---|---|---|
| O que é | Unidade de automação (tasks, handlers, variáveis, templates) | **Pacote** que distribui vários tipos de conteúdo |
| Contém | Uma automação (ex.: instalar o PostgreSQL) | Roles, **módulos**, **plugins** (filtros, lookups, inventários, callbacks), playbooks e documentação |
| Nome | `geerlingguy.postgresql` | `community.postgresql` |
| Nome completo (FQCN) | `namespace.role` | `namespace.collection.plugin` (ex.: `community.postgresql.postgresql_user`) |
| Versionamento | Opcional, via Git ou tags | **Obrigatório** (SemVer), com dependências declaradas |
| Estado atual | Continua suportada | **Formato recomendado** para distribuição |

Desde o Ansible 2.10, quase todos os módulos e plugins que não são do núcleo (*core*) foram movidos para **collections**. O `ansible-core` traz apenas a collection `ansible.builtin` (os módulos `copy`, `file`, `service`, `lineinfile`...). Todo o resto, como `community.general`, `community.postgresql` e `ansible.posix`, é instalado à parte.

> Quando você instala o pacote `ansible` (e não só o `ansible-core`), ele já vem com um conjunto grande de collections da comunidade. Com `ansible-core`, você instala somente as de que precisa.

### 1.3 Os tipos de collection

| Prefixo | Origem | Observação |
|---|---|---|
| `ansible.*` | Mantidas pelo projeto Ansible | Ex.: `ansible.builtin`, `ansible.posix`, `ansible.windows` |
| `community.*` | Mantidas pela comunidade | Ex.: `community.general`, `community.postgresql`, `community.docker` |
| Parceiros e Red Hat | Distribuídas, em geral, via **Automation Hub** | Certificadas e com suporte comercial |
| Da sua empresa | Publicadas em um servidor privado | Ex.: `minha_empresa.infra` |

### 1.4 Onde o conteúdo pode estar

| Fonte | Para quê |
|---|---|
| **Galaxy público** (`galaxy.ansible.com`) | Conteúdo da comunidade (padrão do `ansible-galaxy`) |
| **Automation Hub** (Red Hat) | Conteúdo certificado e com suporte |
| **Servidor privado** (Private Automation Hub, Galaxy NG) | Conteúdo interno da empresa |
| **Repositório Git** | Instalar direto do código-fonte |
| **Arquivo `.tar.gz` ou diretório local** | Ambientes sem acesso à internet |

### 1.5 Os comandos do `ansible-galaxy`

```bash
ansible-galaxy collection ...    # tudo sobre collections
ansible-galaxy role ...          # tudo sobre roles
```

| Subcomando | Collections | Roles |
|---|---|---|
| `init` | Cria o esqueleto | Cria o esqueleto |
| `install` | Instala | Instala |
| `list` | Lista as instaladas | Lista as instaladas |
| `build` | Gera o `.tar.gz` | (não se aplica) |
| `publish` | Publica no Galaxy ou no hub | (usa `import`) |
| `verify` | Verifica a integridade | (não se aplica) |
| `download` | Baixa para uso offline | (não se aplica) |
| `search` | (não se aplica) | Busca no Galaxy |
| `info` | (não se aplica) | Mostra detalhes |
| `remove` | (apague o diretório) | Remove |
| `import` | (não se aplica) | Importa do GitHub para o Galaxy |

### 1.6 Nomes completos (FQCN)

Todo conteúdo de uma collection é referenciado pelo **nome completo**:

```yaml
- name: Criar o usuário no PostgreSQL
  community.postgresql.postgresql_user:
    name: app
    password: "{{ postgresql_app_senha }}"
```

O formato é `namespace.collection.nome_do_plugin`. É a forma recomendada (e exigida pelo `ansible-lint`), pois elimina ambiguidades quando duas collections têm módulos com o mesmo nome.

---

## 2. Instalando collections

### 2.1 Instalação básica

```bash
ansible-galaxy collection install community.general
```

Instala a versão **mais recente** da collection (e as suas dependências) no diretório padrão do usuário: `~/.ansible/collections/ansible_collections/`.

Várias de uma vez:

```bash
ansible-galaxy collection install community.general community.postgresql ansible.posix
```

### 2.2 Escolhendo a versão

```bash
# Versão exata
ansible-galaxy collection install community.general:==9.5.0

# Intervalos
ansible-galaxy collection install "community.general:>=9.0.0,<10.0.0"

# Aceitar pré-lançamentos (alfa, beta, rc)
ansible-galaxy collection install community.general --pre
```

Operadores aceitos: `==`, `!=`, `>`, `>=`, `<`, `<=` e `*` (qualquer versão). Em intervalos, escreva entre aspas para o shell não interpretar o `<` e o `>`.

### 2.3 Atualizando e reinstalando

```bash
# Atualizar para a versão mais recente permitida
ansible-galaxy collection install community.general --upgrade

# Reinstalar, sobrescrevendo a versão instalada
ansible-galaxy collection install community.general --force
```

| Opção | Efeito |
|---|---|
| `--upgrade` ou `-U` | Atualiza as collections já instaladas |
| `--force` ou `-f` | Sobrescreve a instalação existente |
| `--force-with-deps` | Sobrescreve também as dependências |
| `--no-deps` | Não instala as dependências |
| `--pre` | Considera versões de pré-lançamento |

### 2.4 Listando e inspecionando

```bash
ansible-galaxy collection list
ansible-galaxy collection list community.general
```

A saída mostra onde cada collection está e qual versão está instalada:

```
# /home/tux/.ansible/collections/ansible_collections
Collection         Version
------------------ -------
community.general  9.5.0
community.postgresql 3.4.0
```

Para ver a documentação dos módulos e plugins de uma collection:

```bash
ansible-doc -l community.postgresql                 # lista o conteúdo
ansible-doc community.postgresql.postgresql_user    # documentação de um módulo
```

### 2.5 Verificando a integridade

```bash
ansible-galaxy collection verify community.general
```

Compara os arquivos instalados com os do servidor de origem e acusa diferenças (arquivos alterados ou corrompidos).

### 2.6 Onde as collections são instaladas

| Local | Uso |
|---|---|
| `~/.ansible/collections/ansible_collections/` | Padrão, por usuário |
| `/usr/share/ansible/collections/ansible_collections/` | Padrão, global do sistema |
| Pasta do projeto, definida em `collections_path` | **Recomendado** para projetos reproduzíveis |

**Instalar em uma pasta do projeto:**

```bash
ansible-galaxy collection install community.general -p ./collections
```

O Ansible cria a subpasta `ansible_collections/` por conta própria. Para que o projeto a encontre, configure o `ansible.cfg`:

```ini
[defaults]
collections_path = ./collections:~/.ansible/collections:/usr/share/ansible/collections
```

Também funciona por variável de ambiente: `ANSIBLE_COLLECTIONS_PATH`.

### 2.7 O arquivo `requirements.yml`

Em projetos, não instale uma por uma: **declare tudo** em `requirements.yml`, que fica no repositório e torna o ambiente reproduzível:

```yaml
---
collections:
  - name: community.general
    version: ">=9.0.0,<10.0.0"
  - name: community.postgresql
    version: ">=3.0.0"
  - name: ansible.posix
```

Instalação:

```bash
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection install -r requirements.yml -p ./collections
ansible-galaxy collection install -r requirements.yml --upgrade
```

Campos aceitos em cada item:

| Campo | Descrição |
|---|---|
| `name` | Nome (`namespace.collection`), URL, caminho de arquivo ou diretório |
| `version` | Versão ou intervalo |
| `source` | URL do servidor de onde baixar (em vez do padrão) |
| `type` | Tipo da origem: `galaxy`, `git`, `url`, `file`, `dir`, `subdirs` |

### 2.8 Instalando de outras origens

**De um repositório Git:**

```bash
# Branch, tag ou commit após a vírgula
ansible-galaxy collection install git+https://git.exemplo.com/infra/colecao-infra.git,main
ansible-galaxy collection install git+https://git.exemplo.com/infra/colecao-infra.git,v1.2.0
```

No `requirements.yml`:

```yaml
collections:
  - name: https://git.exemplo.com/infra/colecao-infra.git
    type: git
    version: v1.2.0
```

**De um arquivo `.tar.gz`** (gerado por `ansible-galaxy collection build`):

```bash
ansible-galaxy collection install ./minha_empresa-infra-1.0.0.tar.gz
```

**De um diretório local** (útil durante o desenvolvimento):

```bash
ansible-galaxy collection install /caminho/para/colecao/ -p ./collections
```

**De uma URL direta:**

```yaml
collections:
  - name: https://exemplo.com/pacotes/minha_empresa-infra-1.0.0.tar.gz
    type: url
```

### 2.9 Ambientes sem internet (offline)

Em uma máquina com acesso, baixe os pacotes:

```bash
ansible-galaxy collection download -r requirements.yml -p ./pacotes
```

Isso gera os `.tar.gz` (e um `requirements.yml` apontando para eles). Leve a pasta para o ambiente isolado e instale:

```bash
ansible-galaxy collection install -r pacotes/requirements.yml -p ./collections
```

### 2.10 Dependências de Python e de sistema

O `ansible-galaxy` instala as **dependências de collections**, mas **não** as bibliotecas Python que os módulos exigem. Por exemplo, os módulos `community.postgresql` precisam do `psycopg2`:

```bash
pip install psycopg2-binary
```

Em geral, a collection traz um `requirements.txt` ou descreve os requisitos na documentação de cada módulo (`ansible-doc ...`). Instale essas bibliotecas **onde o módulo roda** (no host gerenciado ou, em tasks delegadas a `localhost`, na máquina de controle).

### 2.11 Removendo

Não existe `ansible-galaxy collection remove`. Para remover uma collection, apague o diretório:

```bash
rm -rf ~/.ansible/collections/ansible_collections/community/general
```

---

## 3. Criando uma collection

Criar uma collection é a forma moderna de **empacotar e distribuir** as suas roles, módulos e plugins.

### 3.1 Passo 1: criar o esqueleto

```bash
ansible-galaxy collection init minha_empresa.infra
```

O comando cria o diretório `minha_empresa/infra/`:

```
minha_empresa/infra/
├── README.md
├── galaxy.yml            # metadados da collection (obrigatório)
├── docs/                 # documentação adicional
├── meta/
│   └── runtime.yml       # requisitos de versão do Ansible, redirecionamentos
├── plugins/
│   └── README.md         # módulos, filtros, lookups e outros plugins
└── roles/                # roles da collection
```

Para escolher onde criar:

```bash
ansible-galaxy collection init minha_empresa.infra --init-path ./collections/ansible_collections
```

**Regras de nome:** o nome da collection tem a forma `namespace.nome`. Ambos devem usar apenas letras minúsculas, números e *underscore*, e não podem começar com número ou *underscore*. Evite hífens.

### 3.2 Passo 2: preencher o `galaxy.yml`

```yaml
---
namespace: minha_empresa
name: infra
version: 1.0.0
readme: README.md
authors:
  - Sua Equipe <equipe@exemplo.com>
description: Roles e plugins de infraestrutura da Minha Empresa
license:
  - MIT
tags:
  - infrastructure
  - postgresql
dependencies:
  community.postgresql: "*"        # em projetos reais, fixe um intervalo de versões
repository: https://git.exemplo.com/infra/colecao-infra
documentation: https://git.exemplo.com/infra/colecao-infra/wiki
homepage: https://git.exemplo.com/infra/colecao-infra
issues: https://git.exemplo.com/infra/colecao-infra/issues
build_ignore:
  - .git
  - "*.tar.gz"
  - .vault_pass
  - molecule
```

| Campo | Descrição |
|---|---|
| `namespace` e `name` | Identificam a collection (`minha_empresa.infra`) |
| `version` | Versão em **SemVer** (`MAJOR.MINOR.PATCH`) |
| `authors` | Lista de autores |
| `description` | Resumo de uma linha |
| `license` | Identificadores de licença (SPDX) |
| `tags` | Palavras-chave para busca no Galaxy |
| `dependencies` | Outras collections necessárias (`nome: versão`) |
| `build_ignore` | Arquivos e pastas que **não** entram no pacote |
| `repository`, `documentation`, `homepage`, `issues` | Links do projeto |

### 3.3 Passo 3: definir os requisitos em `meta/runtime.yml`

```yaml
---
requires_ansible: ">=2.15.0"
```

Informa a versão mínima do `ansible-core` que a collection suporta.

### 3.4 Passo 4: adicionar conteúdo

**Roles.** Mova ou copie roles para `roles/`:

```
minha_empresa/infra/roles/
└── postgresql_remote/        # a role dos capítulos anteriores
    ├── defaults/
    ├── tasks/
    ├── handlers/
    ├── meta/
    └── ...
```

Dentro da collection, a role passa a ser chamada pelo **nome completo**:

```yaml
roles:
  - role: minha_empresa.infra.postgresql_remote
```

**Plugins.** Cada tipo tem a sua subpasta em `plugins/`:

| Pasta | Conteúdo |
|---|---|
| `plugins/modules/` | Módulos |
| `plugins/module_utils/` | Código compartilhado pelos módulos |
| `plugins/filter/` | Filtros Jinja2 |
| `plugins/lookup/` | Lookups |
| `plugins/inventory/` | Plugins de inventário |
| `plugins/callback/` | Plugins de saída e notificação |
| `plugins/action/` | Plugins de ação |
| `plugins/connection/` | Tipos de conexão |
| `plugins/test/` | Testes Jinja2 |
| `plugins/doc_fragments/` | Trechos de documentação reutilizáveis |

Exemplo de um filtro, `plugins/filter/memoria.py`:

```python
from __future__ import annotations

DOCUMENTATION = """
  name: para_gb
  short_description: Converte megabytes em gigabytes
  description:
    - Converte um valor em MB para GB, com uma casa decimal.
  options:
    _input:
      description: Valor em megabytes.
      type: int
      required: true
"""

EXAMPLES = """
- ansible.builtin.debug:
    msg: "{{ ansible_facts['memtotal_mb'] | minha_empresa.infra.para_gb }} GB"
"""

RETURN = """
  _value:
    description: Valor em gigabytes.
    type: float
"""


def para_gb(valor_mb):
    return round(int(valor_mb) / 1024, 1)


class FilterModule(object):
    def filters(self):
        return {"para_gb": para_gb}
```

Uso em um playbook:

```yaml
msg: "{{ ansible_facts['memtotal_mb'] | minha_empresa.infra.para_gb }} GB"
```

Os blocos `DOCUMENTATION`, `EXAMPLES` e `RETURN` alimentam o `ansible-doc` e são exigidos pelos testes de qualidade (`ansible-test sanity`).

### 3.5 Passo 5: estrutura completa de exemplo

```
minha_empresa/infra/
├── README.md
├── galaxy.yml
├── docs/
├── meta/
│   └── runtime.yml
├── plugins/
│   └── filter/
│       └── memoria.py
├── roles/
│   └── postgresql_remote/
│       ├── defaults/main.yml
│       ├── tasks/main.yml
│       ├── handlers/main.yml
│       ├── meta/main.yml
│       └── README.md
├── playbooks/
│   └── liberar_postgresql.yml
└── tests/
```

Um playbook dentro da collection (`playbooks/liberar_postgresql.yml`) pode ser executado depois pelo nome completo:

```bash
ansible-playbook minha_empresa.infra.liberar_postgresql
```

### 3.6 Passo 6: construir o pacote

Dentro do diretório da collection (onde está o `galaxy.yml`):

```bash
cd minha_empresa/infra
ansible-galaxy collection build
```

```
Created collection for minha_empresa.infra at /home/tux/minha_empresa/infra/minha_empresa-infra-1.0.0.tar.gz
```

Para escolher a pasta de saída:

```bash
ansible-galaxy collection build --output-path ./dist
```

O arquivo `minha_empresa-infra-1.0.0.tar.gz` é o pacote distribuível. O nome segue o padrão `namespace-nome-versão.tar.gz`.

### 3.7 Passo 7: testar localmente

Instale o pacote em uma pasta de teste e use-o em um playbook:

```bash
ansible-galaxy collection install ./minha_empresa-infra-1.0.0.tar.gz -p ./collections --force
```

```yaml
---
- name: Testar a collection
  hosts: db
  become: true

  roles:
    - role: minha_empresa.infra.postgresql_remote
      vars:
        postgresql_remote_redes_clientes:
          - 192.168.1.0/24

  tasks:
    - name: Mostrar a memória usando o filtro da collection
      ansible.builtin.debug:
        msg: "{{ ansible_facts['memtotal_mb'] | minha_empresa.infra.para_gb }} GB"
```

Ferramentas de qualidade:

| Ferramenta | Para quê |
|---|---|
| `ansible-lint` | Boas práticas nas roles e playbooks |
| `ansible-test sanity` | Verificações de qualidade e documentação (vem com o `ansible-core`) |
| `ansible-test units` e `integration` | Testes unitários e de integração de módulos e plugins |
| Molecule | Testes das roles (ver capítulo de testes) |
| `antsibull-changelog` | Geração do histórico de mudanças |

### 3.8 Passo 8: publicar

Veja a seção 6.3.

### 3.9 Versionamento

- Use **SemVer**: `MAJOR` quando quebra compatibilidade, `MINOR` quando adiciona recursos, `PATCH` para correções.
- Uma versão publicada **não pode ser sobrescrita**: para corrigir algo, publique uma versão nova.
- Para testes antes do lançamento, use pré-lançamentos (`1.1.0-rc.1`); eles só são instalados com `--pre` ou com a versão exata.
- Mantenha um **changelog** e use *tags* no Git que correspondam às versões.

---

## 4. Gerenciamento de roles com o `ansible-galaxy`

### 4.1 Criando uma role

```bash
ansible-galaxy role init roles/postgresql_remote
```

Cria o esqueleto completo (`tasks`, `handlers`, `defaults`, `vars`, `meta`, `templates`, `files`, `tests`, `README.md`). Detalhes de cada pasta estão no capítulo de roles.

### 4.2 Buscando roles

```bash
ansible-galaxy role search postgresql
ansible-galaxy role search postgresql --author geerlingguy
ansible-galaxy role search postgresql --platforms EL
ansible-galaxy role search --galaxy-tags database
```

A busca retorna o nome, o autor e uma descrição. Como no GitHub, a **popularidade** (estrelas, downloads) e a **data da última atualização** ajudam a escolher.

### 4.3 Vendo detalhes

```bash
ansible-galaxy role info geerlingguy.postgresql
```

Mostra descrição, plataformas suportadas, versões, dependências, tags e links.

### 4.4 Instalando roles

```bash
ansible-galaxy role install geerlingguy.postgresql
```

Instalação em uma pasta do projeto (recomendado):

```bash
ansible-galaxy role install geerlingguy.postgresql -p ./roles
```

Versão específica (após a vírgula):

```bash
ansible-galaxy role install geerlingguy.postgresql,<versão>
```

| Opção | Efeito |
|---|---|
| `-p` ou `--roles-path` | Pasta de instalação |
| `--force` ou `-f` | Reinstala, sobrescrevendo a existente |
| `--force-with-deps` | Reinstala também as dependências |
| `--no-deps` | Não instala as dependências |
| `-r requirements.yml` | Instala o que está listado no arquivo |

As **dependências** declaradas no `meta/main.yml` da role são instaladas automaticamente.

### 4.5 Onde as roles são instaladas

| Local | Uso |
|---|---|
| `~/.ansible/roles` | Padrão, por usuário |
| `/usr/share/ansible/roles` e `/etc/ansible/roles` | Locais do sistema |
| `./roles` (pasta do projeto) | **Recomendado** |

Configuração no `ansible.cfg`:

```ini
[defaults]
roles_path = ./roles:~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
```

### 4.6 Listando e removendo

```bash
ansible-galaxy role list
ansible-galaxy role list -p ./roles
ansible-galaxy role remove geerlingguy.postgresql
```

A listagem mostra o nome e a versão de cada role instalada.

### 4.7 Atualizando

Para roles, a atualização é feita reinstalando com `--force`:

```bash
ansible-galaxy role install geerlingguy.postgresql --force
```

### 4.8 O `requirements.yml` para roles

```yaml
---
roles:
  # Do Galaxy
  - name: geerlingguy.postgresql
    # fixe a versão com "version:" para resultados reproduzíveis

  # De um repositório Git
  - name: minha_role
    src: https://git.exemplo.com/infra/ansible-role-minha_role.git
    scm: git
    version: v1.2.0

  # De um arquivo .tar.gz
  - name: role_empacotada
    src: https://exemplo.com/roles/role_empacotada-1.0.tar.gz
```

Campos:

| Campo | Descrição |
|---|---|
| `name` | Nome com que a role será instalada (usado em `roles:`) |
| `src` | Origem: `namespace.role` (Galaxy), URL Git, URL de `.tar.gz` |
| `scm` | `git` ou `hg`, quando a origem é um repositório |
| `version` | Versão, *tag*, *branch* ou *commit* |

Instalação:

```bash
ansible-galaxy role install -r requirements.yml -p ./roles
```

### 4.9 Usando a role instalada

```yaml
---
- name: Configurar o banco
  hosts: db
  become: true

  roles:
    - role: geerlingguy.postgresql
      vars:
        postgresql_users:
          - name: app
            password: "{{ postgresql_app_senha }}"
```

### 4.10 Cuidados com roles de terceiros

- **Leia o código** antes de usar em produção: uma role executa tarefas com privilégios elevados nos seus servidores.
- **Fixe a versão** (`version:`), para que uma atualização do autor não mude o seu ambiente sem aviso.
- Confira a **data da última atualização** e o suporte às versões atuais do Ansible e do SO.
- Verifique as variáveis em `defaults/` e o `README.md`.
- Teste com `--check --diff` em um ambiente seguro.
- Se o projeto está parado, considere manter uma cópia (um *fork*) sob o seu controle.

---

## 5. Importando roles

No contexto do Ansible, "importar" uma role pode ter **dois sentidos**: trazer roles para dentro do seu projeto e publicar a sua role no Galaxy. As duas situações são tratadas aqui.

### 5.1 Importando roles para o seu projeto

**Passo 1: declarar em `requirements.yml`**

```yaml
---
roles:
  - name: geerlingguy.postgresql
  - name: minha_role
    src: https://git.exemplo.com/infra/ansible-role-minha_role.git
    scm: git
    version: v1.2.0
```

**Passo 2: instalar na pasta do projeto**

```bash
ansible-galaxy role install -r requirements.yml -p ./roles
```

**Passo 3: usar no playbook**

```yaml
# Seção roles: (estática)
- hosts: db
  become: true
  roles:
    - geerlingguy.postgresql
    - minha_role

# Ou no meio das tasks
- hosts: db
  tasks:
    - name: Aplicar a role importada
      ansible.builtin.import_role:
        name: minha_role

    - name: Aplicar a role de forma dinâmica
      ansible.builtin.include_role:
        name: geerlingguy.postgresql
      when: instalar_banco | default(false) | bool
```

(`import_role` é estático e `include_role` é dinâmico; veja o capítulo de roles.)

**Passo 4: manter o projeto reproduzível.** Faça commit do `requirements.yml`, e coloque as roles instaladas no `.gitignore`:

```
roles/geerlingguy.postgresql/
roles/minha_role/
```

Quem clona o repositório recria o ambiente com um único comando.

### 5.2 Importando uma role para o Galaxy

Para publicar **a sua** role no Galaxy, o fluxo parte de um **repositório no GitHub**.

> As telas e as exigências do Galaxy podem mudar com o tempo. Em caso de divergência, consulte a documentação oficial do Galaxy.

**Pré-requisitos**

1. Conta no **GitHub**, com a role em um repositório público, na **raiz** do repositório (`tasks/`, `meta/`, `defaults/` etc.).
2. Conta no Galaxy, autenticada com o GitHub, e o seu *namespace* (em geral, o seu usuário do GitHub).
3. `meta/main.yml` completo, principalmente `galaxy_info`:

```yaml
---
galaxy_info:
  author: seu_usuario
  description: Libera o PostgreSQL para conexões remotas
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: Debian
      versions: [all]
    - name: EL
      versions: ["8", "9"]
  galaxy_tags:
    - postgresql
    - database

dependencies: []
```

4. Um **token de API** do Galaxy (gerado nas preferências da sua conta em galaxy.ansible.com).

**Importação pela linha de comando**

```bash
ansible-galaxy role import --token "$GALAXY_TOKEN" seu_usuario nome_do_repositorio
```

| Opção | Efeito |
|---|---|
| `--token` | Token de API do Galaxy |
| `--branch` | Importa de uma *branch* específica |
| `--role-name` | Define o nome da role (por padrão, deriva do nome do repositório) |
| `--no-wait` | Não aguarda o término da importação |
| `--status` | Consulta o andamento de importações |

O nome da role costuma derivar do repositório, retirando o prefixo `ansible-role-`: o repositório `ansible-role-postgresql_remote` vira a role `seu_usuario.postgresql_remote`.

**Importação pela interface web**

Também é possível adicionar o repositório pela página do Galaxy (área de conteúdo do usuário), escolhendo o repositório do GitHub na lista.

**Versões da role**

O Galaxy usa as **tags do Git** para as versões. Para lançar a versão 1.0.0:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Depois, reimporte para que o Galaxy registre a versão.

**Estado atual das roles**

O formato recomendado para **novas** distribuições é a **collection** (seção 3). Roles continuam funcionando e podem ser publicadas, mas o ecossistema caminha em direção às collections, que têm versionamento, dependências e conteúdo mais completos.

---

## 6. Importando collections

Do mesmo modo, "importar" collections tem dois sentidos: usá-las no seu projeto e publicar a sua no Galaxy (ou em um servidor privado).

### 6.1 Importando collections para o seu projeto

**Passo 1: declarar em `requirements.yml`**

```yaml
---
collections:
  - name: community.general
    version: ">=9.0.0,<10.0.0"
  - name: community.postgresql
  - name: ansible.posix
```

**Passo 2: instalar na pasta do projeto**

```bash
ansible-galaxy collection install -r requirements.yml -p ./collections
```

**Passo 3: configurar o projeto para encontrá-las** (`ansible.cfg`):

```ini
[defaults]
collections_path = ./collections:~/.ansible/collections:/usr/share/ansible/collections
```

**Passo 4: usar no playbook**

**Com o nome completo (FQCN), a forma recomendada:**

```yaml
- name: Criar o usuário no PostgreSQL
  community.postgresql.postgresql_user:
    name: app
    password: "{{ postgresql_app_senha }}"
  become: true
  become_user: postgres
  no_log: true
```

**Com a diretiva `collections:` (uma forma "abreviada", desencorajada):**

```yaml
- hosts: db
  collections:
    - community.postgresql
  tasks:
    - name: Criar o usuário
      postgresql_user:                 # sem o prefixo
        name: app
```

Essa forma evita digitar o prefixo, mas deixa o código ambíguo (de que collection vem `postgresql_user`?) e **não é herdada** de forma previsível em roles e includes. Prefira sempre o FQCN.

**Passo 5: instalar as dependências de Python**

```bash
pip install psycopg2-binary
```

**Passo 6: versionar o projeto**

- Faça commit do `requirements.yml` e do `ansible.cfg`.
- Coloque a pasta `collections/` no `.gitignore`.
- Quem clonar o repositório recria tudo com `ansible-galaxy collection install -r requirements.yml -p ./collections`.

**Coleções e roles no mesmo arquivo**

Um único `requirements.yml` pode ter as duas seções, e um único comando instala tudo:

```yaml
---
roles:
  - name: geerlingguy.postgresql
  - name: minha_role
    src: https://git.exemplo.com/infra/ansible-role-minha_role.git
    scm: git
    version: v1.2.0

collections:
  - name: community.general
    version: ">=9.0.0"
  - name: community.postgresql
  - name: ansible.posix
```

```bash
ansible-galaxy install -r requirements.yml
```

(Sem `role` ou `collection` no comando, o `ansible-galaxy` instala as duas seções. Com `-p`, a pasta se aplica às roles; para collections em pasta própria, use o comando `collection install` separadamente ou o `collections_path` configurado.)

### 6.2 Importando collections de arquivos e de Git

Útil em ambientes sem acesso ao Galaxy, para collections internas e para testar mudanças:

```bash
# De um arquivo gerado por "build"
ansible-galaxy collection install ./dist/minha_empresa-infra-1.0.0.tar.gz -p ./collections

# De um diretório em desenvolvimento
ansible-galaxy collection install /caminho/para/colecao -p ./collections --force

# De um repositório Git
ansible-galaxy collection install git+https://git.exemplo.com/infra/colecao-infra.git,main -p ./collections
```

### 6.3 Importando (publicando) uma collection no Galaxy ou em um hub

**Pré-requisitos**

1. Uma conta no destino (Galaxy público, Automation Hub ou servidor privado).
2. Um **namespace** no destino, do qual você seja proprietário. No Galaxy público, o namespace precisa estar criado e associado à sua conta antes da publicação.
3. Um **token de API** (no Galaxy público, nas preferências da conta).
4. O pacote gerado com `ansible-galaxy collection build`.

**Configurar o servidor no `ansible.cfg`**

```ini
[galaxy]
server_list = release_galaxy, hub_privado

[galaxy_server.release_galaxy]
url = https://galaxy.ansible.com/
# o token vem de variável de ambiente (veja abaixo)

[galaxy_server.hub_privado]
url = https://hub.exemplo.com/api/galaxy/content/published/
# o token vem de variável de ambiente (veja abaixo)
```

**Nunca grave tokens no `ansible.cfg` versionado.** Use variáveis de ambiente, no formato `ANSIBLE_GALAXY_SERVER_<ID>_TOKEN`, com o id em maiúsculas:

```bash
export ANSIBLE_GALAXY_SERVER_RELEASE_GALAXY_TOKEN="seu_token"
export ANSIBLE_GALAXY_SERVER_HUB_PRIVADO_TOKEN="outro_token"
```

**Publicar**

```bash
# No servidor configurado
ansible-galaxy collection publish ./dist/minha_empresa-infra-1.0.0.tar.gz --server hub_privado

# Ou informando o token diretamente
ansible-galaxy collection publish ./dist/minha_empresa-infra-1.0.0.tar.gz --token "$GALAXY_TOKEN"
```

Por padrão, o comando **aguarda** o resultado da importação (validação feita pelo servidor). Use `--no-wait` para não aguardar.

**O que acontece depois**

1. O servidor recebe o pacote e executa a **importação**: valida o `galaxy.yml`, a estrutura e a documentação.
2. Se houver erros, a importação falha, e você corrige e publica **uma versão nova** (uma versão não pode ser reenviada).
3. Se der certo, a collection fica disponível para instalação:

```bash
ansible-galaxy collection install minha_empresa.infra
ansible-galaxy collection install minha_empresa.infra --server hub_privado
```

**Servidores privados com certificado próprio**

Se o servidor usa um certificado interno que o sistema não reconhece, o ideal é instalar a autoridade certificadora na máquina. A opção `--ignore-certs` (`-c`) desativa a validação e **não deve** ser usada em produção, pois elimina a proteção contra interceptação.

### 6.4 Checklist antes de publicar

- [ ] `galaxy.yml` completo e com a versão correta (SemVer)
- [ ] `meta/runtime.yml` com `requires_ansible`
- [ ] `README.md` e documentação dos plugins (`DOCUMENTATION`, `EXAMPLES`, `RETURN`)
- [ ] `build_ignore` excluindo arquivos desnecessários e **sensíveis** (senhas, `.vault_pass`, `.git`)
- [ ] `ansible-lint` e `ansible-test sanity` sem erros
- [ ] Testes (Molecule, `ansible-test`) passando
- [ ] Licença definida
- [ ] Changelog e tag do Git correspondentes à versão
- [ ] Pacote instalado localmente e testado em um playbook
- [ ] Token em variável de ambiente, nunca no repositório

---

## 7. Configuração dos servidores do Galaxy

Em ambientes corporativos, é comum usar mais de uma fonte (o Galaxy público e um hub privado). O `ansible-galaxy` consulta a lista **na ordem** declarada em `server_list`, e usa o primeiro servidor que tiver o conteúdo.

```ini
[galaxy]
server_list = hub_privado, release_galaxy

[galaxy_server.hub_privado]
url = https://hub.exemplo.com/api/galaxy/content/published/

[galaxy_server.release_galaxy]
url = https://galaxy.ansible.com/
```

Com essa ordem, as collections internas e as aprovadas pela empresa vêm do hub privado, e o resto é buscado no Galaxy público.

Também é possível escolher o servidor em um único comando:

```bash
ansible-galaxy collection install community.general --server hub_privado
```

Alguns servidores usam autenticação por SSO (por exemplo, o Automation Hub da Red Hat), configurada com `auth_url` e `token`. Consulte a documentação do seu hub para os valores corretos.

---

## 8. Exemplo completo

Um projeto que usa roles e collections do Galaxy para configurar o PostgreSQL (o cenário dos capítulos anteriores), com ambiente reproduzível.

### 8.1 Estrutura

```
projeto/
├── ansible.cfg
├── requirements.yml
├── requirements.txt              # dependências de Python
├── .gitignore
├── hosts
├── pg.yml
├── group_vars/
│   └── db/
│       ├── vars.yml
│       └── vault.yml             # criptografado
├── roles/                        # roles instaladas (ignoradas pelo Git)
└── collections/                  # collections instaladas (ignoradas pelo Git)
```

### 8.2 `ansible.cfg`

```ini
[defaults]
inventory = ./hosts
roles_path = ./roles
collections_path = ./collections
vault_password_file = ~/.vault_pass
```

### 8.3 `requirements.yml`

```yaml
---
roles:
  - name: minha_role
    src: https://git.exemplo.com/infra/ansible-role-postgresql_remote.git
    scm: git
    version: v1.0.0

collections:
  - name: community.postgresql
    version: ">=3.0.0"
  - name: community.general
    version: ">=9.0.0"
  - name: ansible.posix
```

### 8.4 `requirements.txt`

```
psycopg2-binary
```

### 8.5 `.gitignore`

```
roles/
collections/
.vault_pass
```

### 8.6 Preparando o ambiente

```bash
# 1. Dependências de Python
pip install -r requirements.txt

# 2. Roles
ansible-galaxy role install -r requirements.yml -p ./roles

# 3. Collections
ansible-galaxy collection install -r requirements.yml -p ./collections

# 4. Conferir
ansible-galaxy role list
ansible-galaxy collection list
```

Qualquer pessoa que clone o repositório recria o mesmo ambiente com esses comandos.

### 8.7 `pg.yml`

```yaml
---
- name: Configurar o PostgreSQL
  hosts: db
  gather_facts: true
  become: true
  force_handlers: true

  roles:
    - role: minha_role
      vars:
        postgresql_remote_redes_clientes:
          - 192.168.1.0/24

  tasks:
    - name: Criar o usuário da aplicação
      community.postgresql.postgresql_user:
        name: "{{ postgresql_app_usuario }}"
        password: "{{ postgresql_app_senha }}"
        state: present
      become_user: postgres
      no_log: true
      tags: usuario
```

### 8.8 Execução

```bash
ansible-playbook pg.yml -K
ansible-playbook pg.yml -K --tags usuario --limit deb00,deb02
```

### 8.9 Atualizando as dependências

```bash
# Collections: atualizar dentro dos intervalos do requirements.yml
ansible-galaxy collection install -r requirements.yml -p ./collections --upgrade

# Roles: reinstalar
ansible-galaxy role install -r requirements.yml -p ./roles --force
```

Depois, rode os testes e faça commit do `requirements.yml` atualizado.

---

## 9. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `couldn't resolve module/action 'x'` | A collection do módulo não está instalada, ou não está no `collections_path` | `ansible-galaxy collection install ...` e conferir o `ansible.cfg` |
| Módulo não é encontrado mesmo instalado | Instalada em outro caminho que o Ansible não usa | `ansible-galaxy collection list` e ajustar `collections_path` |
| `ModuleNotFoundError: No module named 'psycopg2'` (ou similar) | Falta a biblioteca Python do módulo | `pip install` onde o módulo roda |
| Erro de resolução de versões ao instalar | Intervalos incompatíveis entre dependências | Ajustar as versões no `requirements.yml` |
| `--force` não atualiza as dependências | `--force` só afeta o item pedido | `--force-with-deps` |
| Erro de certificado em servidor privado | Certificado interno não confiável | Instalar a CA na máquina (evite `--ignore-certs`) |
| `HTTP Error 401` ou `403` | Token ausente, inválido ou sem permissão | Gerar novo token e conferir a variável `ANSIBLE_GALAXY_SERVER_<ID>_TOKEN` |
| `HTTP Error 404` ao publicar | O namespace não existe ou não é seu | Criar ou solicitar o namespace no servidor |
| Publicação rejeitada: versão já existe | Versões publicadas são imutáveis | Subir o `version` no `galaxy.yml` e republicar |
| Importação falha por documentação ausente | Faltam `DOCUMENTATION`, `EXAMPLES`, `RETURN` nos plugins | Completar e rodar `ansible-test sanity` |
| A role instalada não é encontrada | Instalada fora do `roles_path` | `-p ./roles` e `roles_path` no `ansible.cfg` |
| A role Git instala com o nome errado | Falta o campo `name` no `requirements.yml` | Declarar `name:` explicitamente |
| `ansible-galaxy install -r` ignora as collections | Arquivo sem a seção `collections:` ou comando de role | Usar `ansible-galaxy collection install -r` |
| Uma role de terceiros quebrou após atualizar | Versão não fixada | Fixar `version:` no `requirements.yml` |
| Projeto funciona só na minha máquina | Dependências instaladas globalmente | Instalar em `./roles` e `./collections` e versionar o `requirements.yml` |
| FQCN do filtro da collection não é reconhecido | A collection não está instalada, ou o nome está errado | Conferir com `ansible-doc -t filter -l` e o namespace |
| O pacote inclui arquivos indevidos | `build_ignore` incompleto | Ajustar `build_ignore` e reconstruir |
| `ansible-galaxy collection init` rejeita o nome | Caracteres inválidos (hífen, maiúsculas) | Usar minúsculas, números e *underscore* |

---

## 10. Boas práticas

1. **Use collections para distribuir** conteúdo novo; mantenha roles para uso interno simples ou legado.
2. **Declare tudo em `requirements.yml`** e versione esse arquivo.
3. **Fixe versões ou intervalos** de roles e collections, para que o ambiente seja reproduzível.
4. **Instale em pastas do projeto** (`./roles`, `./collections`), e não globalmente, e ignore-as no Git.
5. **Use sempre o FQCN** nos playbooks e roles.
6. **Documente as dependências de Python** (`requirements.txt`) junto com as do Ansible.
7. **Leia e avalie o código de terceiros** antes de usar em produção; prefira conteúdo mantido e com atualizações recentes.
8. **Considere um servidor privado** (Private Automation Hub, Galaxy NG) para conteúdo interno e para ter controle sobre o que a empresa usa.
9. **Nunca grave tokens ou senhas** em arquivos versionados; use variáveis de ambiente ou o Vault.
10. **Siga o SemVer** e nunca tente republicar a mesma versão; mantenha changelog e *tags* no Git.
11. **Teste antes de publicar:** `ansible-lint`, `ansible-test sanity`, Molecule e uma instalação local do pacote.
12. **Use `build_ignore`** para evitar que arquivos sensíveis ou irrelevantes entrem no pacote.
13. **Atualize as dependências de forma planejada** (em uma branch, com testes), e não de forma automática em produção.
14. **Verifique a integridade** com `ansible-galaxy collection verify` em ambientes críticos.
15. **Mantenha documentação** (README, exemplos, `ansible-doc`) em tudo que você publicar.

---

## Resumo

| Necessidade | Comando ou recurso |
|---|---|
| Instalar uma collection | `ansible-galaxy collection install namespace.nome` |
| Versão ou intervalo | `namespace.nome:==1.2.3` ou `"namespace.nome:>=1.0.0,<2.0.0"` |
| Atualizar collections | `--upgrade` |
| Instalar na pasta do projeto | `-p ./collections` e `collections_path` no `ansible.cfg` |
| Listar collections | `ansible-galaxy collection list` |
| Verificar integridade | `ansible-galaxy collection verify` |
| Ver a documentação de um módulo | `ansible-doc namespace.nome.modulo` |
| Instalar tudo de uma vez | `requirements.yml` + `-r` |
| Instalar de Git ou arquivo | `git+https://...,tag` ou `./pacote.tar.gz` |
| Uso offline | `ansible-galaxy collection download` |
| Criar uma collection | `ansible-galaxy collection init namespace.nome` |
| Metadados | `galaxy.yml` e `meta/runtime.yml` |
| Gerar o pacote | `ansible-galaxy collection build` |
| Publicar | `ansible-galaxy collection publish pacote.tar.gz` |
| Criar uma role | `ansible-galaxy role init` |
| Buscar e inspecionar roles | `ansible-galaxy role search` e `role info` |
| Instalar uma role | `ansible-galaxy role install autor.role -p ./roles` |
| Listar e remover roles | `ansible-galaxy role list` e `role remove` |
| Roles em `requirements.yml` | Seção `roles:` com `name`, `src`, `scm`, `version` |
| Importar uma role para o Galaxy | `ansible-galaxy role import usuario repositorio` |
| Servidores do Galaxy | `[galaxy]` e `[galaxy_server.<id>]` no `ansible.cfg` |
| Token de API | Variável `ANSIBLE_GALAXY_SERVER_<ID>_TOKEN` |
| Nome completo | `namespace.collection.plugin` (FQCN) |
