# Capítulo: Variáveis e Arquivos de Variáveis no Ansible

## Parte 1: Variáveis

### 1.1 O que são variáveis

Variáveis guardam valores que podem ser reutilizados e alterados sem mexer na lógica do playbook. Com elas, o mesmo código serve para ambientes diferentes (desenvolvimento, produção), sistemas diferentes (Debian, Red Hat) e hosts diferentes.

O Ansible usa o motor de templates **Jinja2**, e as variáveis são referenciadas com chaves duplas: `{{ nome_da_variavel }}`.

### 1.2 Regras para nomes

- Podem conter letras, números e underscore (`_`).
- Devem começar com uma letra ou underscore.
- Não podem conter espaços, hífens ou pontos.
- Não podem ser palavras reservadas do Python ou do Ansible (como `environment`, `name`, `hosts`).

| Nome | Válido? |
|---|---|
| `pacote_web` | Sim |
| `porta_http` | Sim |
| `servidor-web` | Não (hífen) |
| `1_porta` | Não (começa com número) |
| `http port` | Não (espaço) |

### 1.3 Definindo variáveis em um play

```yaml
---
- name: Exemplo de variáveis
  hosts: all
  become: true

  vars:
    usuario: tux
    porta_http: 8080
    pacotes:
      - vim
      - curl
      - git

  tasks:
    - name: Mostrar o usuário
      ansible.builtin.debug:
        msg: "Usuário: {{ usuario }}, porta: {{ porta_http }}"
```

### 1.4 Tipos de dados

```yaml
vars:
  # String
  mensagem: "Olá, mundo"

  # Número
  porta: 8080

  # Booleano
  habilitado: true

  # Lista
  pacotes:
    - vim
    - git

  # Dicionário
  usuario:
    nome: tux
    shell: /bin/bash
    uid: 1001
```

### 1.5 Usando variáveis

**Variável simples:**

```yaml
msg: "Porta: {{ porta }}"
```

**Item de uma lista** (índice começa em 0):

```yaml
msg: "Primeiro pacote: {{ pacotes[0] }}"
```

**Campo de um dicionário** (duas notações):

```yaml
msg: "Usuário: {{ usuario.nome }}"
msg: "Shell: {{ usuario['shell'] }}"
```

**Lista inteira em um módulo:**

```yaml
- name: Instalar pacotes
  ansible.builtin.package:
    name: "{{ pacotes }}"
    state: present
```

### 1.6 Atenção às aspas

Quando o valor **começa** com `{{`, o YAML interpreta como um dicionário e dá erro. Sempre use aspas nesse caso.

```yaml
# ERRADO
msg: {{ usuario }}

# CORRETO
msg: "{{ usuario }}"
```

No meio de um texto, as aspas já cobrem o valor inteiro:

```yaml
msg: "O usuário é {{ usuario }}"
```

### 1.7 Variáveis registradas com `register`

Guardam o resultado de uma task, como você já viu com `res.stdout`:

```yaml
- name: Obter hostname
  ansible.builtin.command: hostname -f
  register: res
  changed_when: false

- name: Mostrar
  ansible.builtin.debug:
    msg: "O hostname é {{ res.stdout }}"
```

Campos comuns de uma variável registrada:

| Campo | Conteúdo |
|---|---|
| `stdout` | Saída padrão como texto |
| `stdout_lines` | Saída padrão como lista de linhas |
| `stderr` | Saída de erro |
| `rc` | Código de retorno do comando |
| `changed` | Se a task alterou algo |
| `failed` | Se a task falhou |

### 1.8 Criando variáveis durante a execução com `set_fact`

```yaml
- name: Definir variável calculada
  ansible.builtin.set_fact:
    nome_curto: "{{ inventory_hostname | split('.') | first }}"
```

Ao contrário de `vars`, o `set_fact` define o valor **em tempo de execução** e ele permanece disponível nas tasks seguintes, para aquele host.

### 1.9 Facts

Facts são variáveis coletadas automaticamente dos hosts quando `gather_facts: true`. Exemplos:

| Fact | Exemplo de valor |
|---|---|
| `ansible_os_family` | `Debian`, `RedHat` |
| `ansible_distribution` | `Debian`, `Rocky` |
| `ansible_distribution_version` | `12` |
| `ansible_hostname` | `deb00` |
| `ansible_default_ipv4.address` | `192.168.1.10` |
| `ansible_pkg_mgr` | `apt`, `dnf` |

Para ver todos os facts de um host:

```bash
ansible deb00 -i hosts -m ansible.builtin.setup
```

### 1.10 Variáveis mágicas

São variáveis especiais mantidas pelo próprio Ansible:

| Variável | Significado |
|---|---|
| `inventory_hostname` | Nome do host como está no inventário |
| `groups` | Dicionário com todos os grupos e seus hosts |
| `group_names` | Lista de grupos a que o host atual pertence |
| `hostvars` | Variáveis de todos os hosts |
| `playbook_dir` | Diretório do playbook em execução |

```yaml
- name: Mostrar grupos do host
  ansible.builtin.debug:
    msg: "{{ inventory_hostname }} pertence a {{ group_names }}"
```

### 1.11 Valor padrão e variáveis opcionais

O filtro `default` evita erro quando a variável não existe:

```yaml
msg: "Porta: {{ porta_http | default(80) }}"
```

Para tornar uma variável obrigatória e falhar com uma mensagem clara:

```yaml
msg: "{{ porta_http | mandatory }}"
```

### 1.12 Variáveis na linha de comando (`-e`)

```bash
ansible-playbook -i hosts test.yml -e "usuario=maria porta_http=9090"
```

Variáveis passadas com `-e` (extra vars) têm a **maior precedência** e sobrescrevem qualquer outra definição.

### 1.13 Pedindo valores ao usuário com `vars_prompt`

```yaml
- name: Exemplo interativo
  hosts: all
  vars_prompt:
    - name: ambiente
      prompt: "Qual o ambiente (dev/prod)?"
      private: false
      default: dev
```

### 1.14 Exemplo prático: nomes de pacote diferentes por sistema

Um caso clássico em ambientes mistos: o servidor web se chama `apache2` no Debian e `httpd` no Red Hat. Em vez de repetir tasks, defina um dicionário e use um fact como chave:

```yaml
---
- name: Instalar servidor web
  hosts: all
  become: true

  vars:
    pacote_web:
      Debian: apache2
      RedHat: httpd

  tasks:
    - name: Instalar servidor web
      ansible.builtin.package:
        name: "{{ pacote_web[ansible_os_family] }}"
        state: present
```

### 1.15 Precedência (resumo)

Quando a mesma variável é definida em mais de um lugar, vence a de maior precedência. Do **menor para o maior**, de forma simplificada:

1. Defaults da role (`roles/x/defaults/main.yml`)
2. Inventário: variáveis de grupo (`group_vars`)
3. Inventário: variáveis de host (`host_vars`)
4. Facts coletados
5. Variáveis do play (`vars`, `vars_files`)
6. Variáveis da role (`roles/x/vars/main.yml`)
7. Variáveis de bloco e de task
8. `include_vars`, `set_fact` e `register`
9. **Extra vars (`-e`)**: sempre vencem

A lista oficial é mais detalhada (são 22 níveis), mas esta ordem resolve a grande maioria dos casos. Na dúvida, use `ansible-inventory --host nome_do_host` para ver o que vem do inventário.

---

## Parte 2: Arquivos de Variáveis

### 2.1 Por que usar arquivos de variáveis

Colocar tudo em `vars:` dentro do playbook funciona para exemplos pequenos, mas logo vira bagunça. Arquivos separados permitem:

- reaproveitar os mesmos valores em vários playbooks;
- separar configuração (dados) de lógica (tasks);
- ter valores diferentes por ambiente, grupo ou host;
- proteger dados sensíveis com o Ansible Vault.

Os arquivos de variáveis são YAML simples, com pares chave/valor:

```yaml
---
usuario: tux
porta_http: 8080
pacotes:
  - vim
  - curl
  - git
```

### 2.2 `vars_files`: carregando arquivos em um play

Estrutura:

```
ansible/
├── hosts
├── test.yml
└── vars/
    └── comum.yml
```

`vars/comum.yml`:

```yaml
---
usuario: tux
porta_http: 8080
pacotes:
  - vim
  - curl
```

Playbook:

```yaml
---
- name: Usando arquivo de variáveis
  hosts: all
  become: true

  vars_files:
    - vars/comum.yml

  tasks:
    - name: Instalar pacotes
      ansible.builtin.package:
        name: "{{ pacotes }}"
        state: present

    - name: Mostrar porta
      ansible.builtin.debug:
        msg: "Porta: {{ porta_http }}"
```

O caminho é relativo ao playbook. É possível carregar vários arquivos; em caso de conflito, o **último** da lista vence.

### 2.3 Um arquivo por sistema operacional

Combinando `vars_files` com facts, o Ansible escolhe o arquivo certo automaticamente:

```
vars/
├── Debian.yml
└── RedHat.yml
```

`vars/Debian.yml`:

```yaml
---
pacote_web: apache2
servico_web: apache2
```

`vars/RedHat.yml`:

```yaml
---
pacote_web: httpd
servico_web: httpd
```

Playbook:

```yaml
---
- name: Servidor web multiplataforma
  hosts: all
  gather_facts: true
  become: true

  vars_files:
    - "vars/{{ ansible_os_family }}.yml"

  tasks:
    - name: Instalar servidor web
      ansible.builtin.package:
        name: "{{ pacote_web }}"
        state: present

    - name: Habilitar e iniciar o serviço
      ansible.builtin.service:
        name: "{{ servico_web }}"
        state: started
        enabled: true
```

Para tolerar a ausência de um arquivo, use uma **lista aninhada** (um item que é, ele mesmo, uma lista). O Ansible carrega o primeiro arquivo que existir:

```yaml
  vars_files:
    - [ "vars/{{ ansible_os_family }}.yml", "vars/default.yml" ]
```

Atenção: se você escrever os dois itens como lista simples (cada um com seu `-`), **ambos** serão carregados, e o Ansible falhará se algum não existir.

### 2.4 `include_vars`: carregando durante a execução

Diferente de `vars_files`, o `include_vars` é uma **task**, então pode ser condicional e usar valores calculados no meio do playbook:

```yaml
tasks:
  - name: Carregar variáveis do sistema
    ansible.builtin.include_vars: "vars/{{ ansible_os_family }}.yml"

  - name: Carregar todos os arquivos de um diretório
    ansible.builtin.include_vars:
      dir: vars/extras
      extensions:
        - yml
```

Fallback com `first_found`:

```yaml
  - name: Carregar variáveis com fallback
    ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', arquivos) }}"
    vars:
      arquivos:
        - "vars/{{ ansible_distribution }}.yml"
        - "vars/{{ ansible_os_family }}.yml"
        - vars/default.yml
```

### 2.5 `group_vars` e `host_vars`

São diretórios com nomes especiais, lidos **automaticamente**, sem precisar declarar nada no playbook. Ficam ao lado do inventário ou do playbook.

```
ansible/
├── hosts
├── test.yml
├── group_vars/
│   ├── all.yml
│   ├── debian.yml
│   └── redhat.yml
└── host_vars/
    ├── deb00.yml
    └── rh01.yml
```

| Arquivo | Aplica-se a |
|---|---|
| `group_vars/all.yml` | Todos os hosts |
| `group_vars/debian.yml` | Hosts do grupo `debian` |
| `host_vars/deb00.yml` | Somente o host `deb00` |

Exemplo, `group_vars/all.yml`:

```yaml
---
ntp_server: pool.ntp.org
usuario_admin: tux
```

`host_vars/deb00.yml`:

```yaml
---
usuario_admin: maria
```

Resultado: todos usam `tux`, exceto `deb00`, que usa `maria` (host vence grupo).

Também é possível usar um **diretório** por grupo ou host, com vários arquivos dentro, que são carregados em ordem alfabética:

```
group_vars/
└── debian/
    ├── pacotes.yml
    ├── rede.yml
    └── segredos.yml
```

### 2.6 Passando um arquivo pela linha de comando

Use `-e @arquivo`:

```bash
ansible-playbook -i hosts test.yml -e @vars/producao.yml
```

Como é extra var, esse arquivo tem precedência sobre as demais definições. Pode ser usado várias vezes:

```bash
ansible-playbook -i hosts test.yml -e @vars/comum.yml -e @vars/producao.yml
```

### 2.7 Variáveis de inventário

Também é possível definir variáveis diretamente no inventário (formato INI):

```ini
[debian]
deb00 ansible_host=192.168.1.10
deb02 ansible_host=192.168.1.12

[debian:vars]
ansible_user=tux
ansible_python_interpreter=/usr/bin/python3
```

Para valores mais extensos, prefira `group_vars` e `host_vars`.

### 2.8 Protegendo dados sensíveis com Ansible Vault

Senhas, tokens e chaves não devem ficar em texto puro. O Vault criptografa arquivos de variáveis.

**Criar um arquivo criptografado:**

```bash
ansible-vault create group_vars/all/segredos.yml
```

**Editar:**

```bash
ansible-vault edit group_vars/all/segredos.yml
```

**Criptografar um arquivo existente:**

```bash
ansible-vault encrypt vars/segredos.yml
```

**Visualizar sem editar:**

```bash
ansible-vault view vars/segredos.yml
```

**Executar um playbook que usa arquivos criptografados:**

```bash
ansible-playbook -i hosts test.yml --ask-vault-pass
```

ou, com um arquivo contendo a senha (com permissões restritas):

```bash
ansible-playbook -i hosts test.yml --vault-password-file ~/.vault_pass
```

**Boa prática:** mantenha as variáveis sensíveis em um arquivo separado do restante, e use um prefixo no nome para facilitar a identificação:

```yaml
# group_vars/all/segredos.yml (criptografado)
vault_db_senha: "s3nh4-sup3r-s3cr3t4"
```

```yaml
# group_vars/all/vars.yml (texto puro)
db_senha: "{{ vault_db_senha }}"
```

Assim, é possível ver nos arquivos em texto puro quais variáveis existem, sem expor os valores.

### 2.9 Organização sugerida de um projeto

```
ansible/
├── ansible.cfg
├── hosts
├── site.yml
├── group_vars/
│   ├── all/
│   │   ├── vars.yml
│   │   └── segredos.yml      # criptografado
│   ├── debian.yml
│   └── redhat.yml
├── host_vars/
│   └── deb00.yml
├── vars/
│   ├── Debian.yml
│   └── RedHat.yml
└── roles/
```

---

## Boas práticas

1. **Use nomes descritivos e consistentes**, em minúsculas e com underscore (`porta_http`, e não `p` ou `PortaHTTP`).
2. **Prefixe variáveis de roles** com o nome da role (`nginx_porta`), evitando conflitos.
3. **Não repita valores:** defina uma vez e referencie com `{{ }}`.
4. **Separe dados de lógica:** valores em `group_vars`, `host_vars` e `vars/`; tasks nos playbooks.
5. **Prefira `group_vars` e `host_vars`** para valores ligados ao inventário, e `vars_files` ou `include_vars` para valores ligados a uma tarefa específica.
6. **Use `default()`** em variáveis opcionais.
7. **Nunca coloque senhas em texto puro**; use o Ansible Vault.
8. **Evite abusar de precedência.** Quanto menos lugares definirem a mesma variável, mais fácil de depurar.
9. **Use `-e` com moderação**, para sobrescritas pontuais, não como configuração permanente.
10. **Depure** com `ansible.builtin.debug` e `var:` quando algo não tiver o valor esperado:

```yaml
- name: Depurar variável
  ansible.builtin.debug:
    var: pacotes
```

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Valor fixo dentro do playbook | `vars:` |
| Guardar a saída de uma task | `register:` |
| Criar valor em tempo de execução | `set_fact` |
| Informação do sistema do host | Facts (`ansible_*`) |
| Carregar arquivo no início do play | `vars_files:` |
| Carregar arquivo durante a execução | `include_vars` |
| Valores por grupo | `group_vars/<grupo>.yml` |
| Valores por host | `host_vars/<host>.yml` |
| Sobrescrever na execução | `-e "var=valor"` ou `-e @arquivo.yml` |
| Pedir valor ao usuário | `vars_prompt` |
| Proteger segredos | `ansible-vault` |
