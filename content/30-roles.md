# Capítulo: Roles no Ansible

## 1. O que são roles

Uma **role** é uma forma padronizada de **empacotar e reutilizar** automação. Em vez de um playbook enorme com dezenas de tasks, variáveis e handlers misturados, você separa cada responsabilidade (instalar o PostgreSQL, configurar o SSH, ajustar o sistema) em um diretório com estrutura conhecida pelo Ansible.

O que uma role agrupa:

- **tasks** (o que fazer);
- **handlers** (o que reiniciar ou recarregar quando algo mudar);
- **variáveis** com valores padrão e valores internos;
- **arquivos** estáticos e **templates** Jinja2;
- **metadados** (dependências, plataformas suportadas, validação de parâmetros).

Por que usar:

| Benefício | Explicação |
|---|---|
| **Reuso** | A mesma role serve a vários playbooks, projetos e equipes |
| **Organização** | Cada role tem uma finalidade e um lugar para cada coisa |
| **Playbooks curtos** | O playbook vira uma lista de roles, fácil de ler |
| **Manutenção** | Corrigir a role corrige todos os usos |
| **Compartilhamento** | Roles podem ser publicadas e instaladas via Ansible Galaxy |
| **Testabilidade** | Cada role pode ser testada isoladamente |

Playbook sem roles, longo e misturado:

```yaml
- hosts: db
  become: true
  vars: [...]
  tasks:
    - [dezenas de tasks]
  handlers:
    - [vários handlers]
```

Playbook com roles:

```yaml
- hosts: db
  become: true
  roles:
    - common
    - postgresql_remote
```

---

## 2. A estrutura de uma role

```
roles/
└── postgresql_remote/
    ├── defaults/
    │   └── main.yml            # variáveis padrão (menor precedência, fáceis de sobrescrever)
    ├── vars/
    │   ├── Debian.yml          # variáveis internas por sistema operacional
    │   └── RedHat.yml
    ├── tasks/
    │   ├── main.yml            # ponto de entrada (obrigatório para ser útil)
    │   ├── validar.yml
    │   ├── configurar.yml
    │   └── verificar.yml
    ├── handlers/
    │   └── main.yml            # handlers da role
    ├── templates/              # arquivos .j2 (módulo template)
    ├── files/                  # arquivos estáticos (módulo copy)
    ├── meta/
    │   ├── main.yml            # metadados e dependências
    │   └── argument_specs.yml  # validação dos parâmetros da role
    ├── library/                # módulos personalizados (opcional)
    ├── filter_plugins/         # filtros personalizados (opcional)
    └── README.md               # documentação
```

### 2.1 Para que serve cada diretório

| Diretório | Arquivo de entrada | Conteúdo |
|---|---|---|
| `tasks/` | `main.yml` | Lista de tasks da role |
| `handlers/` | `main.yml` | Handlers notificados pelas tasks |
| `defaults/` | `main.yml` | Variáveis padrão (**menor precedência**) |
| `vars/` | `main.yml` (ou outros arquivos) | Variáveis internas (**alta precedência**) |
| `files/` | (qualquer) | Arquivos copiados com `copy` |
| `templates/` | (qualquer `.j2`) | Modelos usados com `template` |
| `meta/` | `main.yml` | Dependências, plataformas, autoria |
| `meta/` | `argument_specs.yml` | Especificação e validação dos parâmetros |
| `library/`, `*_plugins/` | (qualquer) | Módulos e plugins próprios da role |

Todos são **opcionais**. Uma role só precisa dos diretórios que usa; o mais comum é ter `tasks/`, `defaults/` e `handlers/`.

### 2.2 Criando o esqueleto

```bash
ansible-galaxy role init roles/postgresql_remote
```

O comando cria a árvore completa, com um `main.yml` em cada pasta, o `README.md` e uma pasta `tests/`. Você pode apagar o que não for usar.

### 2.3 Resolução automática de caminhos

Dentro de uma role, o Ansible procura os arquivos nos lugares certos **sem caminhos completos**:

```yaml
- name: Copiar um arquivo estático
  ansible.builtin.copy:
    src: aviso.txt            # procura em roles/<role>/files/aviso.txt
    dest: /etc/aviso.txt

- name: Gerar a partir de um template
  ansible.builtin.template:
    src: app.conf.j2          # procura em roles/<role>/templates/app.conf.j2
    dest: /etc/app.conf
```

---

## 3. Usando roles em um playbook

Existem três formas, com comportamentos diferentes.

### 3.1 A seção `roles:` (a mais comum)

```yaml
---
- name: Configurar os servidores de banco
  hosts: db
  become: true

  roles:
    - common
    - postgresql_remote
```

As roles são carregadas de forma **estática**, antes do bloco `tasks:` do play.

### 3.2 `import_role` (estático, em qualquer ponto das tasks)

```yaml
  tasks:
    - name: Preparar o sistema
      ansible.builtin.debug:
        msg: "Antes da role"

    - name: Aplicar a role no meio das tasks
      ansible.builtin.import_role:
        name: postgresql_remote
```

### 3.3 `include_role` (dinâmico, aceita `when` e `loop`)

```yaml
  tasks:
    - name: Aplicar a role só em Debian
      ansible.builtin.include_role:
        name: postgresql_remote
      when: ansible_facts['os_family'] == "Debian"
```

### 3.4 Comparação

| Característica | `roles:` | `import_role` | `include_role` |
|---|---|---|---|
| Natureza | Estática | Estática | **Dinâmica** |
| Quando é carregada | Início do play | Início do play | Durante a execução |
| Posição no play | Antes de `tasks:` | Onde estiver escrita | Onde estiver escrita |
| `loop` | Não | Não | **Sim** |
| `when` | Aplicado a cada task | Aplicado a cada task | Vale só para o include |
| Aparece em `--list-tasks` | Sim | Sim | Não |
| Tags | Herdadas por todas as tasks | Herdadas | Só na task de include; use `apply` |
| Nome da role pode ser variável | Não | Não | **Sim** |

Regra prática: use `roles:` no dia a dia; use `include_role` quando precisar de condição, loop ou nome dinâmico; use `import_role` para posicionar uma role no meio das tasks.

### 3.5 Ordem de execução de um play

```yaml
- hosts: db
  pre_tasks:     # 1º
    - [...]
  roles:         # 2º
    - [...]
  tasks:         # 3º
    - [...]
  post_tasks:    # 4º
    - [...]
```

Ordem: `pre_tasks` → `roles` → `tasks` → `post_tasks`. Os handlers notificados em cada etapa são executados **ao fim dela** (antes de passar para a seguinte).

### 3.6 Escolhendo apenas parte da role: `tasks_from`

```yaml
- name: Executar só as verificações da role
  ansible.builtin.include_role:
    name: postgresql_remote
    tasks_from: verificar.yml
```

Também existem `vars_from` e `defaults_from` para escolher outros arquivos de variáveis.

---

## 4. Passando parâmetros para a role

### 4.1 Na seção `roles:`

```yaml
  roles:
    - role: postgresql_remote
      vars:
        postgresql_remote_redes_clientes:
          - 192.168.1.0/24
          - 10.0.0.0/16
        postgresql_remote_porta: 5432
```

Também é aceita a forma antiga, com as variáveis no mesmo nível de `role:`:

```yaml
  roles:
    - role: postgresql_remote
      postgresql_remote_porta: 5432
```

### 4.2 Em `include_role` e `import_role`

```yaml
    - name: Aplicar a role com parâmetros
      ansible.builtin.include_role:
        name: postgresql_remote
      vars:
        postgresql_remote_porta: 5433
```

### 4.3 Por inventário, `group_vars` e `-e`

Qualquer variável de **defaults** pode ser sobrescrita fora da role:

```yaml
# group_vars/db.yml
postgresql_remote_redes_clientes:
  - 192.168.1.0/24
```

```bash
ansible-playbook -i hosts pg.yml -K -e "postgresql_remote_porta=5433"
```

### 4.4 Aplicando a mesma role várias vezes

Por padrão, a mesma role executa **uma única vez** por play, mesmo se citada mais de uma vez, a menos que os **parâmetros sejam diferentes** ou a role tenha `allow_duplicates: true` em `meta/main.yml`.

```yaml
  roles:
    - role: postgresql_remote
      vars: { postgresql_remote_porta: 5432 }
    - role: postgresql_remote
      vars: { postgresql_remote_porta: 5433 }    # parâmetros diferentes: executa de novo
```

---

## 5. `defaults` × `vars`: a escolha mais importante

| | `defaults/main.yml` | `vars/main.yml` (e `include_vars`) |
|---|---|---|
| Precedência | **Menor de todas** | Alta (vence `group_vars`, `host_vars` e variáveis do play) |
| Pode ser sobrescrita por quem usa a role? | **Sim**, de qualquer lugar | Praticamente não (só com extra vars ou parâmetros da role) |
| Para que serve | Opções configuráveis, com valor padrão | Constantes internas (caminhos, nomes de pacote por SO) |
| Exemplo | `porta: 5432` | `servico: postgresql-16` |

Regras práticas:

1. **Tudo o que o usuário da role pode querer mudar** vai em `defaults/`.
2. **Valores internos que não devem ser alterados** (caminhos por SO, nomes de serviços) vão em `vars/`.
3. Na dúvida, escolha `defaults/`: é mais flexível.

### 5.1 Precedência resumida (do menor para o maior)

1. `defaults/main.yml` da role
2. `group_vars` e `host_vars`
3. Variáveis do play (`vars`, `vars_files`)
4. `vars/main.yml` da role e `include_vars`
5. Variáveis de bloco e de task
6. **Parâmetros da role** (`vars:` em `roles:`, `include_role`, `import_role`)
7. **Extra vars (`-e`)**

Isso explica por que defaults são "sugestões" e parâmetros e `-e` são "ordens".

---

## 6. Convenções de nomes

Roles compartilham o mesmo espaço de variáveis do play. Sem cuidado, duas roles podem usar uma variável chamada `porta` e se atrapalhar. Por isso:

### 6.1 Prefixe as variáveis com o nome da role

```yaml
# Ruim
porta: 5432
versao: 16

# Bom
postgresql_remote_porta: 5432
postgresql_remote_versao: 16
```

### 6.2 Prefixe os nomes dos handlers

```yaml
- name: postgresql_remote | Reiniciar o PostgreSQL
  ansible.builtin.service:
    name: "{{ postgresql_remote_servico }}"
    state: restarted
```

Assim, não há colisão com handlers de outras roles, e a saída mostra de onde veio a ação.

### 6.3 Use `loop_var` com prefixo nos loops internos

```yaml
loop: "{{ postgresql_remote_redes_clientes }}"
loop_control:
  loop_var: postgresql_remote_rede
```

Evita colisão com o `item` de quem inclui a role (ver capítulos de loops).

### 6.4 Nomes de roles

Use letras minúsculas, números e underscore; descreva a finalidade (`postgresql_remote`, `ssh_hardening`, `common`).

---

## 7. Exemplo completo: a role `postgresql_remote`

Vamos transformar o exemplo do capítulo de handlers (liberar o PostgreSQL para conexões remotas) em uma role reutilizável, funcionando em Debian e Red Hat.

### 7.1 Estrutura final

```
ansible/
├── hosts
├── pg.yml                              # playbook
├── group_vars/
│   └── db.yml
└── roles/
    └── postgresql_remote/
        ├── defaults/main.yml
        ├── vars/
        │   ├── Debian.yml
        │   └── RedHat.yml
        ├── tasks/
        │   ├── main.yml
        │   ├── validar.yml
        │   ├── configurar.yml
        │   └── verificar.yml
        ├── handlers/main.yml
        ├── meta/
        │   ├── main.yml
        │   └── argument_specs.yml
        └── README.md
```

### 7.2 `defaults/main.yml`: o que o usuário pode ajustar

```yaml
---
# Versão principal do PostgreSQL instalado
postgresql_remote_versao: 16

# Valor do parâmetro listen_addresses
postgresql_remote_listen_addresses: "*"

# Porta do PostgreSQL
postgresql_remote_porta: 5432

# Redes de clientes liberadas no pg_hba.conf (lista de CIDRs)
postgresql_remote_redes_clientes: []

# Método de autenticação das regras do pg_hba.conf
postgresql_remote_auth: scram-sha-256

# Verificar se a porta está ouvindo após aplicar
postgresql_remote_verificar: true
```

### 7.3 `vars/Debian.yml` e `vars/RedHat.yml`: o que é interno

`vars/Debian.yml`:

```yaml
---
postgresql_remote_conf: "/etc/postgresql/{{ postgresql_remote_versao }}/main/postgresql.conf"
postgresql_remote_hba: "/etc/postgresql/{{ postgresql_remote_versao }}/main/pg_hba.conf"
postgresql_remote_servico: postgresql
```

`vars/RedHat.yml`:

```yaml
---
postgresql_remote_conf: "/var/lib/pgsql/{{ postgresql_remote_versao }}/data/postgresql.conf"
postgresql_remote_hba: "/var/lib/pgsql/{{ postgresql_remote_versao }}/data/pg_hba.conf"
postgresql_remote_servico: "postgresql-{{ postgresql_remote_versao }}"
```

> Os caminhos do Red Hat assumem os pacotes do repositório PGDG. Se você usa o módulo AppStream do RHEL, ajuste para `/var/lib/pgsql/data/...` e o serviço `postgresql`.

Como essas variáveis ficam em `vars/`, têm precedência alta e o usuário da role normalmente não precisa (nem deve) alterá-las. Se for preferível permitir a troca de caminhos, mova-as para `defaults/`.

### 7.4 `tasks/main.yml`: o ponto de entrada

```yaml
---
- name: Carregar as variáveis do sistema operacional
  ansible.builtin.include_vars: "{{ ansible_facts['os_family'] }}.yml"
  tags: always

- name: Validar os pré-requisitos
  ansible.builtin.import_tasks: validar.yml
  tags: always

- name: Configurar o PostgreSQL
  ansible.builtin.import_tasks: configurar.yml
  tags:
    - config
    - acesso

- name: Verificar o resultado
  ansible.builtin.import_tasks: verificar.yml
  when: postgresql_remote_verificar | bool
  tags:
    - verificar
```

O `main.yml` funciona como um "índice": cada etapa fica em um arquivo próprio, e as tags e condições são aplicadas ao arquivo inteiro (por ser `import_tasks`, estático, as tags são herdadas por todas as tasks internas).

A primeira task falha com uma mensagem do próprio Ansible se `vars/<família>.yml` não existir, o que acontece para sistemas não suportados. A validação a seguir cobre esse caso de forma mais amigável.

### 7.5 `tasks/validar.yml`

```yaml
---
- name: Verificar se o sistema é suportado
  ansible.builtin.assert:
    that:
      - ansible_facts['os_family'] in ['Debian', 'RedHat']
    fail_msg: "Sistema não suportado: {{ ansible_facts['os_family'] }}"

- name: Verificar os arquivos de configuração
  ansible.builtin.stat:
    path: "{{ item }}"
    get_checksum: false
    get_mime: false
  loop:
    - "{{ postgresql_remote_conf }}"
    - "{{ postgresql_remote_hba }}"
  register: postgresql_remote_arquivos
  loop_control:
    label: "{{ item }}"

- name: Falhar cedo se faltar algum arquivo
  ansible.builtin.assert:
    that: postgresql_remote_arquivos.results | map(attribute='stat.exists') | min
    fail_msg: >-
      Arquivos de configuração do PostgreSQL ausentes em {{ inventory_hostname }}
      (o PostgreSQL {{ postgresql_remote_versao }} está instalado e inicializado?)
```

### 7.6 `tasks/configurar.yml`

```yaml
---
- name: Configurar listen_addresses (exige reinício)
  ansible.builtin.lineinfile:
    path: "{{ postgresql_remote_conf }}"
    regexp: '^\s*#?\s*listen_addresses\s*='
    line: "listen_addresses = '{{ postgresql_remote_listen_addresses }}'"
    backup: true
  notify: postgresql_remote | Reiniciar o PostgreSQL

- name: Configurar a porta
  ansible.builtin.lineinfile:
    path: "{{ postgresql_remote_conf }}"
    regexp: '^\s*#?\s*port\s*='
    line: "port = {{ postgresql_remote_porta }}"
    backup: true
  notify: postgresql_remote | Reiniciar o PostgreSQL

- name: Permitir as redes dos clientes no pg_hba.conf (basta recarregar)
  ansible.builtin.lineinfile:
    path: "{{ postgresql_remote_hba }}"
    regexp: '^host\s+all\s+all\s+{{ postgresql_remote_rede | regex_escape }}\s'
    line: "host    all    all    {{ postgresql_remote_rede }}    {{ postgresql_remote_auth }}"
    insertafter: EOF
    backup: true
  loop: "{{ postgresql_remote_redes_clientes }}"
  loop_control:
    loop_var: postgresql_remote_rede
  notify: postgresql_remote | Recarregar o PostgreSQL
```

Pontos a observar:

- Uma lista vazia em `postgresql_remote_redes_clientes` (o padrão) faz a última task ser pulada sem erro.
- O `loop_var` com prefixo evita colisão com o `item` de quem usa a role.
- Os dois reinícios (listen e porta) disparam o **mesmo** handler, que executa uma única vez.

### 7.7 `tasks/verificar.yml`

```yaml
---
- name: Aplicar as alterações pendentes agora
  ansible.builtin.meta: flush_handlers

- name: Confirmar que o PostgreSQL ouve no IP do servidor
  ansible.builtin.wait_for:
    host: "{{ ansible_facts['default_ipv4']['address'] }}"
    port: "{{ postgresql_remote_porta }}"
    timeout: 30
```

### 7.8 `handlers/main.yml`

```yaml
---
- name: postgresql_remote | Reiniciar o PostgreSQL
  ansible.builtin.service:
    name: "{{ postgresql_remote_servico }}"
    state: restarted

- name: postgresql_remote | Recarregar o PostgreSQL
  ansible.builtin.service:
    name: "{{ postgresql_remote_servico }}"
    state: reloaded
```

### 7.9 `meta/main.yml`

```yaml
---
galaxy_info:
  author: sua-equipe
  description: Libera o PostgreSQL para conexões remotas (listen_addresses e pg_hba.conf)
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

### 7.10 `meta/argument_specs.yml`: validando os parâmetros

Esse arquivo descreve os parâmetros aceitos. O Ansible valida os valores **antes** de executar a role e dá erros claros, além de documentar a role:

```yaml
---
argument_specs:
  main:
    short_description: Libera o PostgreSQL para conexões remotas
    options:
      postgresql_remote_versao:
        type: int
        default: 16
        description: Versão principal do PostgreSQL instalado.
      postgresql_remote_listen_addresses:
        type: str
        default: "*"
        description: Valor de listen_addresses no postgresql.conf.
      postgresql_remote_porta:
        type: int
        default: 5432
        description: Porta do PostgreSQL.
      postgresql_remote_redes_clientes:
        type: list
        elements: str
        default: []
        description: Redes (CIDR) liberadas no pg_hba.conf.
      postgresql_remote_auth:
        type: str
        default: scram-sha-256
        choices:
          - scram-sha-256
          - md5
          - cert
        description: Método de autenticação das regras criadas.
      postgresql_remote_verificar:
        type: bool
        default: true
        description: Verificar se a porta está ouvindo após aplicar.
```

Com isso, passar `postgresql_remote_porta: "abc"` ou `postgresql_remote_auth: trust2` falha logo no início, com uma mensagem explicando o problema.

### 7.11 `README.md`

Documente a role: finalidade, requisitos, variáveis e exemplo de uso.

````markdown
# postgresql_remote

Libera o PostgreSQL para conexões remotas (listen_addresses e pg_hba.conf).

## Requisitos
- PostgreSQL já instalado e inicializado (Debian/Ubuntu ou Red Hat com PGDG).

## Variáveis principais
| Variável | Padrão | Descrição |
|---|---|---|
| postgresql_remote_versao | 16 | Versão principal |
| postgresql_remote_listen_addresses | "*" | Valor de listen_addresses |
| postgresql_remote_porta | 5432 | Porta |
| postgresql_remote_redes_clientes | [] | Redes (CIDR) liberadas |

## Exemplo
```yaml
- hosts: db
  become: true
  roles:
    - role: postgresql_remote
      vars:
        postgresql_remote_redes_clientes: [192.168.1.0/24]
```
````

### 7.12 O playbook que usa a role: `pg.yml`

```yaml
---
- name: Configurar os servidores de banco
  hosts: db
  gather_facts: true
  become: true
  force_handlers: true

  roles:
    - role: postgresql_remote
      vars:
        postgresql_remote_redes_clientes:
          - 192.168.1.0/24
      tags: postgres
```

E o ajuste por inventário, em `group_vars/db.yml`:

```yaml
---
postgresql_remote_versao: 16
postgresql_remote_auth: scram-sha-256
```

### 7.13 Execuções

```bash
# Simular, vendo as diferenças nos arquivos
ansible-playbook -i hosts pg.yml -K --check --diff

# Aplicar em dois hosts
ansible-playbook -i hosts pg.yml -K --limit deb00,deb02

# Só a configuração (tags herdadas dos imports)
ansible-playbook -i hosts pg.yml -K --tags config

# Só a verificação
ansible-playbook -i hosts pg.yml -K --tags verificar

# Tudo da role, pela tag da role
ansible-playbook -i hosts pg.yml -K --tags postgres

# Listar as tasks (roles estáticas aparecem na lista)
ansible-playbook -i hosts pg.yml --list-tasks

# Mudando um parâmetro na hora
ansible-playbook -i hosts pg.yml -K -e "postgresql_remote_porta=5433"
```

---

## 8. Templates e arquivos na role

### 8.1 Template Jinja2

`roles/ssh_banner/templates/banner.j2`:

```
{{ ansible_managed }}
Servidor: {{ inventory_hostname }} ({{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }})
Ambiente: {{ ssh_banner_ambiente }}
{% for linha in ssh_banner_avisos %}
{{ linha }}
{% endfor %}
```

`roles/ssh_banner/tasks/main.yml`:

```yaml
---
- name: Gerar o banner
  ansible.builtin.template:
    src: banner.j2
    dest: /etc/issue.net
    owner: root
    group: root
    mode: "0644"
```

Recursos úteis:

- `{{ ansible_managed }}` insere um aviso de que o arquivo é gerenciado pelo Ansible.
- `{% for %}`, `{% if %}` e os filtros (capítulo de filtros) funcionam nos templates.
- O parâmetro `validate` do `template` (e do `copy`) testa o arquivo gerado antes de gravá-lo: `validate: "/usr/sbin/sshd -t -f %s"`.

### 8.2 Arquivos estáticos

Arquivos em `roles/<role>/files/` são copiados com `copy`, sem caminho completo. Use `files/` para conteúdo fixo e `templates/` para conteúdo que depende de variáveis.

---

## 9. Dependências entre roles

Em `meta/main.yml`, a lista `dependencies` define roles que devem executar **antes**:

```yaml
---
dependencies:
  - role: common
  - role: postgresql_install
    vars:
      postgresql_install_versao: "{{ postgresql_remote_versao }}"
```

Regras:

- As dependências rodam **antes** da role, na ordem listada, e podem receber parâmetros.
- Cada dependência executa **uma vez** por play, mesmo que várias roles dependam dela, a menos que os parâmetros sejam diferentes ou `allow_duplicates: true` esteja definido no `meta/main.yml` da role dependente.
- Dependências em cadeia (A depende de B, que depende de C) são resolvidas automaticamente.

Em muitos projetos, prefira **listar as roles no playbook** em vez de esconder dependências nos metadados: o fluxo fica explícito e mais fácil de entender.

```yaml
  roles:
    - common
    - postgresql_install
    - postgresql_remote
```

---

## 10. Roles com `include_role` e loops

Aplicar uma role para cada item de uma lista (veja o capítulo de loops internos):

```yaml
- name: Configurar um servidor web para cada site
  ansible.builtin.include_role:
    name: web_site
  vars:
    web_site_dados: "{{ site }}"
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
    label: "{{ site.nome }}"
```

Dentro da role, use a variável `web_site_dados` (o parâmetro recebido), e não `site`, para manter a role independente de quem a chama.

### 10.1 Tags em `include_role`: `apply`

```yaml
- name: Aplicar a role web_site
  ansible.builtin.include_role:
    name: web_site
    apply:
      tags: web
  tags: web
```

### 10.2 `public: true`

Por padrão, as variáveis de uma role incluída com `include_role` **não** ficam visíveis para as tasks seguintes do play. Para expô-las:

```yaml
- ansible.builtin.include_role:
    name: web_site
    public: true
```

---

## 11. Onde o Ansible procura as roles

Principais locais de busca (a ordem exata pode variar conforme a versão do `ansible-core`; consulte a documentação da sua versão em caso de roles com o mesmo nome em lugares diferentes):

- Pasta `roles/` ao lado do playbook.
- Pastas definidas em `roles_path` (no `ansible.cfg` ou na variável de ambiente `ANSIBLE_ROLES_PATH`).
- Roles instaladas por coleções (chamadas pelo nome completo, FQCN).
- Diretórios padrão do sistema (como `~/.ansible/roles` e `/usr/share/ansible/roles`).

Evite ter duas roles com o mesmo nome em lugares diferentes; isso causa confusão sobre qual será usada.

Exemplo de configuração em `ansible.cfg`:

```ini
[defaults]
roles_path = ./roles:~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
```

---

## 12. Roles do Ansible Galaxy e coleções

### 12.1 Instalando roles públicas

```bash
ansible-galaxy role install geerlingguy.postgresql
ansible-galaxy role list
```

Para projetos, declare as dependências em um arquivo `requirements.yml`, assim o ambiente é reproduzível:

```yaml
---
roles:
  - name: geerlingguy.postgresql
    # fixe a versão com "version:" para resultados reproduzíveis

collections:
  - name: community.postgresql
```

```bash
ansible-galaxy install -r requirements.yml
```

### 12.2 Roles dentro de coleções

Coleções podem conter roles, chamadas pelo nome completo (FQCN):

```yaml
roles:
  - role: minha_empresa.infra.postgresql_remote
```

### 12.3 Cuidados com roles de terceiros

- **Leia o código** antes de usar em produção.
- **Fixe a versão** (`version:` no `requirements.yml`) para evitar mudanças inesperadas.
- Confira as variáveis `defaults/` e o `README.md` antes de aplicar.
- Teste com `--check --diff` em um ambiente seguro.

---

## 13. Testando roles

| Ferramenta ou comando | Para quê |
|---|---|
| `ansible-playbook --syntax-check pg.yml` | Verificar a sintaxe |
| `ansible-playbook --list-tasks pg.yml` | Ver as tasks que serão executadas |
| `ansible-playbook --check --diff pg.yml` | Simular, vendo as diferenças |
| `ansible-lint` | Verificar boas práticas e erros comuns |
| **Molecule** | Testes automatizados da role em contêineres ou VMs, com verificação de idempotência |

Um teste simples e valioso: **rodar a role duas vezes**. Na segunda execução, o resultado deve ser `changed=0` (idempotência) e nenhum handler deve rodar.

---

## 14. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `the role 'x' was not found` | Role fora do `roles_path` | Conferir a pasta `roles/` e o `ansible.cfg` |
| Variável da role "não muda" | Está em `vars/` (alta precedência) | Mover para `defaults/` |
| Defaults da role sobrescritos sem querer | Mesmo nome de variável em `group_vars` | Prefixar com o nome da role |
| Uma role "atrapalha" outra | Variáveis ou handlers com o mesmo nome | Prefixos nas variáveis e nos handlers |
| A role executa só uma vez | Citada mais de uma vez com os mesmos parâmetros | Parâmetros diferentes ou `allow_duplicates: true` |
| `src` do `template` ou `copy` não encontrado | Arquivo fora de `templates/` ou `files/` da role | Colocar no diretório correto ou usar caminho completo |
| Handler não executa | Nome em `notify` diferente do handler | Copiar o nome exatamente (incluindo o prefixo) |
| `loop` em `roles:` ou `import_role` dá erro | Estáticos não aceitam `loop` | `include_role` com `loop` |
| Tags não executam a role incluída | `include_role` é dinâmico | `apply: tags:` e a tag também no include |
| `--list-tasks` não mostra a role | Foi incluída com `include_role` | Comportamento esperado |
| Variáveis de `include_role` não existem depois | Não são públicas por padrão | `public: true` |
| Erro de validação dos parâmetros | `argument_specs.yml` rejeitou o valor | Corrigir o valor, conforme a mensagem |
| `include_vars` falha em sistema não previsto | Falta o arquivo `vars/<família>.yml` | Validar o SO antes ou usar `first_found` com fallback |
| Dependência executa mais de uma vez | Parâmetros diferentes entre os usos | Padronizar os parâmetros |
| Role funciona só no seu ambiente | Dependência de caminhos, pacotes ou facts locais | Documentar requisitos e validar no início |

---

## 15. Boas práticas

1. **Uma role, uma responsabilidade.** `postgresql_remote` faz uma coisa; instalar o PostgreSQL é outra role.
2. **`defaults/` para o que é configurável, `vars/` para o que é interno.** Na dúvida, `defaults/`.
3. **Prefixe tudo com o nome da role:** variáveis, handlers e `loop_var`.
4. **Divida `tasks/main.yml` em arquivos por etapa** (`validar`, `configurar`, `verificar`) com `import_tasks`.
5. **Valide cedo:** SO suportado, arquivos existentes, parâmetros corretos (`assert` e `argument_specs.yml`).
6. **Escreva um `README.md`** com requisitos, variáveis e exemplo de uso.
7. **Preencha `meta/main.yml`** com plataformas e versão mínima do Ansible.
8. **Use `argument_specs.yml`** para validar e documentar os parâmetros.
9. **Garanta idempotência:** a segunda execução deve resultar em `changed=0`.
10. **Evite dependências escondidas;** liste as roles no playbook sempre que possível.
11. **Não dependa de variáveis do play que a role não declara.** Declare tudo em `defaults/`.
12. **Use `--check --diff`** antes de aplicar em produção.
13. **Mantenha roles pequenas e testáveis** (ansible-lint e, quando possível, Molecule).
14. **Fixe versões** de roles e coleções de terceiros no `requirements.yml`.
15. **Controle de versão:** mantenha cada role (ou o conjunto delas) em um repositório Git, com etiquetas (tags) de versão.

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Criar o esqueleto | `ansible-galaxy role init roles/nome` |
| Tasks da role | `tasks/main.yml` |
| Handlers da role | `handlers/main.yml` |
| Valores padrão sobrescrevíveis | `defaults/main.yml` |
| Constantes internas | `vars/` |
| Valores por sistema operacional | `vars/<os_family>.yml` + `include_vars` |
| Arquivos estáticos e templates | `files/` e `templates/` |
| Usar a role no play | `roles:` |
| Usar a role no meio das tasks | `import_role` |
| Role com condição, loop ou nome dinâmico | `include_role` |
| Executar só parte da role | `tasks_from` |
| Passar parâmetros | `vars:` na role |
| Dependências | `meta/main.yml` → `dependencies` |
| Validar parâmetros | `meta/argument_specs.yml` |
| Executar a role de novo com os mesmos parâmetros | `allow_duplicates: true` |
| Ordem de execução do play | `pre_tasks` → `roles` → `tasks` → `post_tasks` |
| Instalar roles de terceiros | `ansible-galaxy install -r requirements.yml` |
| Testar | `--syntax-check`, `--check --diff`, `ansible-lint`, Molecule |
| Evitar colisões de nomes | Prefixo do nome da role em variáveis e handlers |
