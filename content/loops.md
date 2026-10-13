# Capítulo: Loops no Ansible

## 1. O que são loops

Loops permitem **repetir uma task** para cada item de uma coleção: criar vários usuários, instalar vários pacotes, ajustar permissões em vários diretórios, consultar vários arquivos. Em vez de escrever dez tasks quase iguais, você escreve uma e informa a lista de itens.

A palavra-chave moderna é **`loop`**. Em cada repetição, o item atual fica disponível na variável **`item`**.

```yaml
- name: Mostrar cada fruta
  ansible.builtin.debug:
    msg: "Fruta: {{ item }}"
  loop:
    - maçã
    - banana
    - laranja
```

Saída:

```
ok: [deb00] => (item=maçã)   => { "msg": "Fruta: maçã" }
ok: [deb00] => (item=banana) => { "msg": "Fruta: banana" }
ok: [deb00] => (item=laranja) => { "msg": "Fruta: laranja" }
```

---

## 2. Parte 1: Loops simples (listas)

### 2.1 Lista escrita na própria task

```yaml
- name: Criar diretórios
  ansible.builtin.file:
    path: "/opt/{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - app
    - logs
    - backup
```

### 2.2 Lista guardada em uma variável

A variável precisa ser referenciada com `{{ }}` entre aspas:

```yaml
vars:
  servicos:
    - ssh
    - cron
    - rsyslog

tasks:
  - name: Garantir que os serviços estão ativos
    ansible.builtin.service:
      name: "{{ item }}"
      state: started
      enabled: true
    loop: "{{ servicos }}"
```

Também funciona com uma variável vinda de `-e`, `group_vars`, `vars_files` ou de um `register`:

```bash
ansible-playbook -i hosts test.yml -e '{"servicos": ["ssh", "cron"]}'
```

### 2.3 Lista de números e intervalos

```yaml
- name: Contar de 1 a 5
  ansible.builtin.debug:
    msg: "Número {{ item }}"
  loop: "{{ range(1, 6) | list }}"
```

`range(1, 6)` gera 1, 2, 3, 4, 5 (o último valor é excluído). Há também o passo: `range(0, 20, 5)` gera 0, 5, 10, 15.

### 2.4 Lista vinda de uma saída de comando

```yaml
- name: Listar os arquivos de /etc/cron.d
  ansible.builtin.command: ls /etc/cron.d
  register: cron_d
  changed_when: false

- name: Mostrar cada um
  ansible.builtin.debug:
    msg: "{{ item }}"
  loop: "{{ cron_d.stdout_lines }}"
```

### 2.5 Lista de hosts do inventário

```yaml
- name: Mostrar o IP de cada host do grupo debian
  ansible.builtin.debug:
    msg: "{{ item }}: {{ hostvars[item]['ansible_facts']['default_ipv4']['address'] | default('n/d') }}"
  loop: "{{ groups['debian'] }}"
  run_once: true
```

Os facts dos outros hosts só existem se já foram coletados na execução (ver capítulo de facts).

### 2.6 Quando **não** usar loop

Muitos módulos aceitam **uma lista diretamente**, e fazem tudo em uma única chamada, o que é bem mais rápido:

```yaml
# EVITE: três chamadas ao gerenciador de pacotes
- name: Instalar utilitários
  ansible.builtin.package:
    name: "{{ item }}"
    state: present
  loop:
    - vim
    - curl
    - git

# PREFIRA: uma chamada
- name: Instalar utilitários
  ansible.builtin.package:
    name:
      - vim
      - curl
      - git
    state: present
```

Isso vale para `package`, `apt`, `dnf`, `yum`, entre outros. Use `loop` quando o módulo opera sobre **um item por vez** (`user`, `file`, `copy`, `service`, `lineinfile`...).

### 2.7 Filtrando a lista antes do loop

```yaml
loop: "{{ numeros | select('odd') | list }}"
loop: "{{ usuarios | selectattr('ativo') | list }}"
loop: "{{ lista | unique | sort }}"
```

Filtrar antes deixa a saída mais limpa do que usar `when` (que mostra um `skipping` para cada item descartado).

---

## 3. Parte 2: Loops compostos

Loops compostos são os que percorrem estruturas com **mais de um dado por item**: listas de dicionários, dicionários e combinações entre listas.

### 3.1 Lista de dicionários

É a forma mais comum e mais legível. Cada item é um dicionário, acessado com `item.campo`:

```yaml
vars:
  usuarios:
    - { nome: ana,   shell: /bin/bash, grupo: dev }
    - { nome: bruno, shell: /bin/sh,   grupo: ops }
    - { nome: carla, shell: /bin/bash, grupo: dev }

tasks:
  - name: Criar os grupos
    ansible.builtin.group:
      name: "{{ item }}"
      state: present
    loop: "{{ usuarios | map(attribute='grupo') | unique | list }}"

  - name: Criar os usuários
    ansible.builtin.user:
      name: "{{ item.nome }}"
      shell: "{{ item.shell }}"
      group: "{{ item.grupo }}"
      state: present
    loop: "{{ usuarios }}"
    loop_control:
      label: "{{ item.nome }}"
```

Na primeira task, `map(attribute='grupo') | unique` extrai os grupos sem repetição. O `loop_control.label` faz a saída mostrar só o nome, em vez do dicionário inteiro (seção 5).

Também é possível escrever a lista de dicionários diretamente na task:

```yaml
- name: Criar diretórios com dono e modo
  ansible.builtin.file:
    path: "{{ item.path }}"
    state: directory
    owner: "{{ item.owner }}"
    mode: "{{ item.mode }}"
  loop:
    - { path: /opt/app,      owner: root,    mode: "0755" }
    - { path: /opt/app/logs, owner: appuser, mode: "0750" }
    - { path: /opt/app/tmp,  owner: appuser, mode: "1777" }
```

### 3.2 Campos opcionais com `default`

Nem todo item precisa ter todos os campos:

```yaml
vars:
  usuarios:
    - { nome: ana,   shell: /bin/bash }
    - { nome: bruno, estado: absent }
    - { nome: carla }

tasks:
  - name: Gerenciar usuários
    ansible.builtin.user:
      name: "{{ item.nome }}"
      shell: "{{ item.shell | default('/bin/bash') }}"
      state: "{{ item.estado | default('present') }}"
    loop: "{{ usuarios }}"
    loop_control:
      label: "{{ item.nome }}"
```

Para omitir um parâmetro quando o campo não existe, use `default(omit)`:

```yaml
      uid: "{{ item.uid | default(omit) }}"
```

### 3.3 Dicionário (`dict2items`)

Um loop não aceita um dicionário diretamente. Converta-o com o filtro `dict2items`, que o transforma em uma lista de pares com **`key`** e **`value`**:

```yaml
vars:
  parametros_app:
    porta: 8080
    modo: producao
    workers: 4

tasks:
  - name: Gravar cada parâmetro no arquivo de configuração
    ansible.builtin.lineinfile:
      path: /etc/app.conf
      regexp: "^{{ item.key }}="
      line: "{{ item.key }}={{ item.value }}"
      create: true
      mode: "0644"
    loop: "{{ parametros_app | dict2items }}"
```

O arquivo resultante:

```
porta=8080
modo=producao
workers=4
```

### 3.4 Dicionário de dicionários

Quando cada **valor** é, ele mesmo, um dicionário:

```yaml
vars:
  diretorios:
    /opt/app:
      owner: root
      mode: "0755"
    /opt/app/logs:
      owner: appuser
      mode: "0750"
    /opt/app/tmp:
      owner: appuser
      mode: "1777"

tasks:
  - name: Criar os diretórios
    ansible.builtin.file:
      path: "{{ item.key }}"
      state: directory
      owner: "{{ item.value.owner }}"
      mode: "{{ item.value.mode }}"
    loop: "{{ diretorios | dict2items }}"
    loop_control:
      label: "{{ item.key }}"
```

Aqui `item.key` é o caminho e `item.value.owner` e `item.value.mode` são os campos internos. A ordem do YAML é preservada (importante para criar o diretório pai antes dos filhos). Para ordenar por chave:

```yaml
loop: "{{ diretorios | dict2items | sort(attribute='key') }}"
```

### 3.5 Dicionário cujos valores são listas

```yaml
vars:
  pacotes_por_funcao:
    web:
      - nginx
      - certbot
    banco:
      - postgresql
      - pgbouncer

tasks:
  - name: Mostrar os pacotes de cada função
    ansible.builtin.debug:
      msg: "{{ item.key }} usa {{ item.value | join(', ') }}"
    loop: "{{ pacotes_por_funcao | dict2items }}"
```

Para obter **todos** os pacotes em uma lista única:

```yaml
loop: "{{ pacotes_por_funcao.values() | flatten | list }}"
```

### 3.6 Itens dentro de itens: `subelements`

Quando cada item de uma lista contém **outra lista**, o filtro `subelements` produz pares (item externo, item interno):

```yaml
vars:
  usuarios:
    - nome: ana
      projetos: [alpha, beta]
    - nome: bruno
      projetos: [gama]

tasks:
  - name: Criar a pasta de cada projeto para cada usuário
    ansible.builtin.file:
      path: "/home/{{ item.0.nome }}/{{ item.1 }}"
      state: directory
      owner: "{{ item.0.nome }}"
      mode: "0750"
    loop: "{{ usuarios | subelements('projetos') }}"
    loop_control:
      label: "{{ item.0.nome }} / {{ item.1 }}"
```

Resultado: `/home/ana/alpha`, `/home/ana/beta`, `/home/bruno/gama`.

Aqui `item.0` é o usuário (dicionário completo) e `item.1` é o projeto. Os usuários precisam existir (veja a seção 3.1).

### 3.7 Combinando listas: `product` (loop aninhado)

Para percorrer **todas as combinações** entre duas listas, use `product`:

```yaml
- name: Criar a estrutura ambiente/serviço
  ansible.builtin.file:
    path: "/srv/{{ item.0 }}/{{ item.1 }}"
    state: directory
    mode: "0755"
  loop: "{{ ['dev', 'homolog', 'prod'] | product(['web', 'db']) | list }}"
```

Gera seis combinações: `dev/web`, `dev/db`, `homolog/web`, `homolog/db`, `prod/web`, `prod/db`.

### 3.8 Emparelhando listas: `zip`

Para juntar listas **posição a posição**:

```yaml
vars:
  hosts_banco: [db01, db02, db03]
  ips_banco: [10.0.0.11, 10.0.0.12, 10.0.0.13]

tasks:
  - name: Registrar cada host no /etc/hosts
    ansible.builtin.lineinfile:
      path: /etc/hosts
      line: "{{ item.1 }} {{ item.0 }}"
    loop: "{{ hosts_banco | zip(ips_banco) | list }}"
```

### 3.9 Lista de listas: `flatten`

```yaml
vars:
  base: [vim, curl]
  extras: [git, htop]

loop: "{{ [base, extras] | flatten }}"
```

---

## 4. Loops com variáveis registradas

### 4.1 Os resultados ficam em `results`

Quando uma task com `loop` usa `register`, o resultado é uma **lista** em `.results`, com um elemento por item. O valor original do loop fica em `item.item`:

```yaml
- name: Verificar vários arquivos
  ansible.builtin.stat:
    path: "{{ item }}"
    get_checksum: false
  loop:
    - /etc/hosts
    - /etc/hostname
    - /etc/nao-existe
  register: arquivos

- name: Mostrar quais existem
  ansible.builtin.debug:
    msg: "{{ item.item }}: {{ 'existe' if item.stat.exists else 'não existe' }}"
  loop: "{{ arquivos.results }}"
  loop_control:
    label: "{{ item.item }}"
```

### 4.2 Usando só os que atendem a uma condição

```yaml
- name: Remover os arquivos que existem
  ansible.builtin.file:
    path: "{{ item.item }}"
    state: absent
  loop: "{{ arquivos.results | selectattr('stat.exists') | list }}"
  loop_control:
    label: "{{ item.item }}"
```

---

## 5. Controlando o loop: `loop_control`

| Opção | Efeito |
|---|---|
| `label` | Texto exibido na saída para cada item (em vez do item inteiro) |
| `loop_var` | Renomeia a variável `item` |
| `index_var` | Cria uma variável com o índice do item (começa em 0) |
| `pause` | Espera N segundos entre as repetições |
| `extended` | Habilita a variável `ansible_loop` com informações detalhadas |
| `break_when` | Interrompe o loop quando a condição for verdadeira (versões recentes do `ansible-core`) |

### 5.1 `label`: saída limpa

Sem `label`, uma lista de dicionários polui a tela:

```
ok: [deb00] => (item={'nome': 'ana', 'shell': '/bin/bash', 'grupo': 'dev'})
```

Com `label: "{{ item.nome }}"`:

```
ok: [deb00] => (item=ana)
```

Isso também evita que dados sensíveis dos itens (como senhas) apareçam na saída.

### 5.2 `loop_var`: renomear a variável

Essencial em **loops aninhados** (seção 7), para que o `item` de um loop não colida com o do outro:

```yaml
loop: "{{ usuarios }}"
loop_control:
  loop_var: usuario
```

Dentro da task, use `{{ usuario.nome }}` em vez de `{{ item.nome }}`.

### 5.3 `index_var`: posição do item

```yaml
- name: Listar com número
  ansible.builtin.debug:
    msg: "{{ idx + 1 }}. {{ item }}"
  loop: [alfa, beta, gama]
  loop_control:
    index_var: idx
```

### 5.4 `pause`: intervalo entre itens

```yaml
- name: Reiniciar serviços com intervalo
  ansible.builtin.service:
    name: "{{ item }}"
    state: restarted
  loop: [app1, app2, app3]
  loop_control:
    pause: 10
```

### 5.5 `extended`: informações detalhadas

Com `extended: true`, a variável `ansible_loop` traz:

| Campo | Conteúdo |
|---|---|
| `ansible_loop.index` | Posição atual (começa em 1) |
| `ansible_loop.index0` | Posição atual (começa em 0) |
| `ansible_loop.first` | Verdadeiro no primeiro item |
| `ansible_loop.last` | Verdadeiro no último item |
| `ansible_loop.length` | Total de itens |
| `ansible_loop.revindex` | Itens restantes, contando o atual |
| `ansible_loop.previtem` | Item anterior (não existe no primeiro) |
| `ansible_loop.nextitem` | Próximo item (não existe no último) |

```yaml
- name: Mostrar progresso
  ansible.builtin.debug:
    msg: "Item {{ ansible_loop.index }} de {{ ansible_loop.length }}: {{ item }}"
  loop: [a, b, c]
  loop_control:
    extended: true
```

### 5.6 `break_when`: parar antes do fim

```yaml
- name: Procurar o primeiro arquivo existente
  ansible.builtin.stat:
    path: "{{ item }}"
  loop:
    - /etc/apache2/apache2.conf
    - /etc/httpd/conf/httpd.conf
    - /etc/nginx/nginx.conf
  register: busca
  loop_control:
    break_when: busca.stat.exists | default(false)
```

O recurso está disponível a partir do `ansible-core` 2.18. Em versões antigas, use a alternativa: processe a lista completa e escolha o primeiro resultado com `selectattr(...) | first`.

---

## 6. Loops com condições (`when`)

O `when` é avaliado **a cada item**, e pode usar `item`:

```yaml
- name: Instalar apenas os pacotes marcados
  ansible.builtin.package:
    name: "{{ item.nome }}"
    state: present
  loop:
    - { nome: nginx, instalar: true }
    - { nome: apache2, instalar: false }
    - { nome: htop, instalar: true }
  when: item.instalar
  loop_control:
    label: "{{ item.nome }}"
```

Combinando com facts:

```yaml
- name: Instalar o pacote correto para cada sistema
  ansible.builtin.package:
    name: "{{ item.pacote }}"
    state: present
  loop:
    - { pacote: apache2, familia: Debian }
    - { pacote: httpd,   familia: RedHat }
  when: item.familia == ansible_facts['os_family']
  loop_control:
    label: "{{ item.pacote }}"
```

Quando possível, prefira filtrar a lista antes do loop (seção 2.7); o `when` mostra uma linha `skipping` para cada item descartado.

---

## 7. Loops aninhados com `include_tasks`

O `loop` não funciona em `block` (ver capítulo de blocks). Para repetir **várias tasks** para cada item, ou para ter um loop dentro de outro com lógica própria, use `include_tasks` com `loop`.

Playbook principal:

```yaml
---
- name: Criar a estrutura de vários sites
  hosts: all
  become: true

  vars:
    sites:
      - nome: loja.exemplo.com
        pastas: [html, logs, backup]
      - nome: blog.exemplo.com
        pastas: [html, logs]

  tasks:
    - name: Configurar cada site
      ansible.builtin.include_tasks: site.yml
      loop: "{{ sites }}"
      loop_control:
        loop_var: site
        label: "{{ site.nome }}"
```

Arquivo `site.yml`:

```yaml
---
- name: Criar a pasta raiz do site
  ansible.builtin.file:
    path: "/var/www/{{ site.nome }}"
    state: directory
    mode: "0755"

- name: Criar as subpastas
  ansible.builtin.file:
    path: "/var/www/{{ site.nome }}/{{ item }}"
    state: directory
    mode: "0755"
  loop: "{{ site.pastas }}"
```

O loop externo usa `loop_var: site`, deixando `item` livre para o loop interno. **Sempre** renomeie a variável do loop externo ao usar `include_tasks` com `loop`, para evitar colisões.

---

## 8. Mudando a variável do loop, repetições e erros

### 8.1 `until` em loops

O `until` repete **cada item** até a condição ser satisfeita:

```yaml
- name: Aguardar cada serviço responder
  ansible.builtin.uri:
    url: "http://localhost:{{ item }}/health"
  loop: [8080, 8081]
  register: saude
  until: saude.status == 200
  retries: 5
  delay: 3
```

### 8.2 Resultado geral da task

- A task é marcada como **alterada** se **qualquer** item alterou algo.
- É marcada como **falha** se algum item falhar (use `ignore_errors` ou `failed_when` quando precisar tolerar).
- Se a lista estiver **vazia**, a task é pulada, sem erro.

---

## 9. Migrando de `with_*` para `loop`

Em playbooks mais antigos você encontrará `with_items`, `with_dict` e similares. Eles continuam funcionando, mas o padrão atual é `loop` com filtros:

| Antigo | Equivalente com `loop` |
|---|---|
| `with_items: lista` | `loop: "{{ lista }}"` |
| `with_list: lista` | `loop: "{{ lista }}"` |
| `with_dict: dic` | `loop: "{{ dic \| dict2items }}"` |
| `with_nested: [a, b]` | `loop: "{{ a \| product(b) \| list }}"` |
| `with_together: [a, b]` | `loop: "{{ a \| zip(b) \| list }}"` |
| `with_subelements: [lista, 'campo']` | `loop: "{{ lista \| subelements('campo') }}"` |
| `with_sequence: start=1 end=5` | `loop: "{{ range(1, 6) \| list }}"` |
| `with_fileglob: 'files/*.conf'` | `loop: "{{ query('fileglob', 'files/*.conf') }}"` |

Diferença sutil: o `with_items` **achata um nível** de listas aninhadas, e o `loop` não. Ao migrar, use `| flatten(levels=1)` se o comportamento fizer diferença:

```yaml
loop: "{{ lista_de_listas | flatten(levels=1) }}"
```

### 9.1 Arquivos da máquina de controle (`fileglob`)

```yaml
- name: Copiar todos os arquivos .conf de files/
  ansible.builtin.copy:
    src: "{{ item }}"
    dest: "/etc/app/{{ item | basename }}"
    mode: "0644"
  loop: "{{ query('fileglob', 'files/*.conf') }}"
```

O `fileglob` procura na **máquina de controle**, não nos hosts remotos. Para buscar nos hosts, use o módulo `find` com `register`.

---

## 10. Exemplo completo

Configuração de um servidor de aplicação em Debian e Red Hat, combinando loops simples e compostos:

```yaml
---
- name: Configurar servidor de aplicação
  hosts: all
  gather_facts: true
  become: true

  vars:
    pacotes_comuns:
      - vim
      - curl
      - git

    pacote_web:
      Debian: apache2
      RedHat: httpd

    usuarios:
      - { nome: ana,   shell: /bin/bash, grupos: [dev, docker] }
      - { nome: bruno, shell: /bin/sh,   grupos: [ops] }
      - { nome: carla, shell: /bin/bash, grupos: [dev], estado: absent }

    diretorios:
      /opt/app:
        owner: root
        mode: "0755"
      /opt/app/logs:
        owner: root
        mode: "0750"

    parametros_app:
      porta: 8080
      modo: producao
      workers: 4

  tasks:
    - name: Instalar os pacotes comuns (uma única chamada)
      ansible.builtin.package:
        name: "{{ pacotes_comuns + [pacote_web[ansible_facts['os_family']]] }}"
        state: present
      tags: pacotes

    - name: Criar os grupos necessários
      ansible.builtin.group:
        name: "{{ item }}"
        state: present
      loop: "{{ usuarios | map(attribute='grupos') | flatten | unique | list }}"
      tags: usuarios

    - name: Gerenciar os usuários
      ansible.builtin.user:
        name: "{{ item.nome }}"
        shell: "{{ item.shell | default('/bin/bash') }}"
        groups: "{{ item.grupos }}"
        append: true
        state: "{{ item.estado | default('present') }}"
      loop: "{{ usuarios }}"
      loop_control:
        label: "{{ item.nome }}"
      tags: usuarios

    - name: Criar os diretórios da aplicação
      ansible.builtin.file:
        path: "{{ item.key }}"
        state: directory
        owner: "{{ item.value.owner }}"
        mode: "{{ item.value.mode }}"
      loop: "{{ diretorios | dict2items }}"
      loop_control:
        label: "{{ item.key }}"
      tags: diretorios

    - name: Gravar os parâmetros da aplicação
      ansible.builtin.lineinfile:
        path: /opt/app/app.conf
        regexp: "^{{ item.key }}="
        line: "{{ item.key }}={{ item.value }}"
        create: true
        mode: "0644"
      loop: "{{ parametros_app | dict2items }}"
      loop_control:
        label: "{{ item.key }}"
      tags: config

    - name: Resumo da execução
      ansible.builtin.debug:
        msg: "{{ ansible_loop.index }}/{{ ansible_loop.length }} - {{ item.nome }} ({{ item.estado | default('present') }})"
      loop: "{{ usuarios }}"
      loop_control:
        extended: true
        label: "{{ item.nome }}"
      run_once: true
      tags: resumo
```

Execuções:

```bash
ansible-playbook -i hosts app.yml -K
ansible-playbook -i hosts app.yml -K --tags usuarios --limit deb00,deb02
ansible-playbook -i hosts app.yml -K --tags config --check
```

---

## 11. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `Invalid data passed to 'loop', it requires a list` | Passou um dicionário ou texto ao `loop` | Usar `dict2items`, ou garantir que a variável é uma lista |
| `'item' is undefined` | `item` usado fora de uma task com `loop` | Usar `item` apenas dentro da task que tem `loop` |
| Itens do loop externo "somem" no loop interno | Ambos usam `item` | `loop_var` no loop externo |
| Saída gigante com dicionários | Falta `label` | `loop_control: label:` |
| Senha aparece na saída | O item inteiro é exibido | `label` e `no_log: true` |
| `loop` em `block` dá erro | Blocos não aceitam `loop` | `include_tasks` com `loop` |
| `register` com loop: `stdout` indefinido | Dados estão em `.results` | Iterar `res.results` e usar `item.stdout` |
| Muitas linhas `skipping` | `when` descartando muitos itens | Filtrar a lista antes (`select`, `selectattr`) |
| Instalação de pacotes muito lenta | Um loop com uma chamada por pacote | Passar a lista direto ao módulo (`name: [a, b, c]`) |
| `with_items` e `loop` com resultados diferentes | `with_items` achata listas | `flatten(levels=1)` |
| `fileglob` não encontra arquivos | Procura na máquina de controle | Conferir o caminho local, ou usar `find` no remoto |
| Ordem dos diretórios incorreta | Dicionário sem ordem pensada | Listar o pai antes do filho, ou `sort(attribute='key')` |
| Erro ao acessar `item.0` | Lista não gerada por `product`, `zip` ou `subelements` | Conferir a estrutura com `debug: var=` |
| `ansible_loop` indefinido | Falta `extended: true` | Habilitar em `loop_control` |

---

## 12. Boas práticas

1. **Use `loop`** em vez de `with_*` em código novo.
2. **Passe listas direto aos módulos** que as aceitam (`package`, `apt`, `dnf`), em vez de fazer loop.
3. **Prefira listas de dicionários** a estruturas muito aninhadas: são mais fáceis de ler, estender e validar.
4. **Use `dict2items`** para percorrer dicionários, e lembre-se de `item.key` e `item.value`.
5. **Use `label`** em todo loop com itens complexos, para manter a saída legível e esconder dados sensíveis.
6. **Renomeie a variável (`loop_var`)** sempre que houver loops aninhados ou `include_tasks` com `loop`.
7. **Filtre antes do loop** em vez de usar `when` para descartar muitos itens.
8. **Use `default()`** para campos opcionais dos itens, e `default(omit)` para parâmetros opcionais de módulos.
9. **Mantenha os dados em variáveis** (`vars`, `group_vars`, `vars_files`) e a lógica nas tasks: para adicionar um usuário, basta editar a lista.
10. **Valide a estrutura** com `debug: var=` antes de montar loops complexos.
11. **Use `pause` com moderação** em operações que precisam de intervalo (reinícios escalonados).
12. **Para repetir várias tasks por item,** use `include_tasks` com `loop`, e não `block`.
13. **Teste com `--check`** e com listas pequenas antes de aplicar em produção.

---

## Resumo

| Necessidade | Solução |
|---|---|
| Repetir uma task para cada item | `loop: lista` |
| Item atual | `{{ item }}` |
| Lista guardada em variável | `loop: "{{ variavel }}"` |
| Intervalo numérico | `loop: "{{ range(1, 6) \| list }}"` |
| Lista de dicionários | `loop: "{{ lista }}"` + `item.campo` |
| Dicionário | `loop: "{{ dic \| dict2items }}"` + `item.key`, `item.value` |
| Dicionário de dicionários | `item.key` + `item.value.campo` |
| Lista dentro de lista de itens | `subelements('campo')` + `item.0`, `item.1` |
| Todas as combinações de duas listas | `a \| product(b) \| list` |
| Emparelhar duas listas | `a \| zip(b) \| list` |
| Achatar listas aninhadas | `flatten` |
| Resultados de um loop registrado | `res.results` e `item.item` |
| Saída limpa | `loop_control: label` |
| Renomear `item` | `loop_control: loop_var` |
| Índice e progresso | `index_var`, `extended` e `ansible_loop` |
| Intervalo entre itens | `loop_control: pause` |
| Interromper cedo | `loop_control: break_when` (versões recentes) |
| Condição por item | `when` com `item` |
| Várias tasks por item | `include_tasks` + `loop` + `loop_var` |
| Arquivos da máquina de controle | `query('fileglob', 'padrao')` |
| Muitos pacotes de uma vez | `name: [a, b, c]`, sem loop |
