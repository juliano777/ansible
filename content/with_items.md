# Capítulo: `with_items` (e a família `with_*`)

## 1. O que é o `with_items`

O `with_items` é a forma **clássica** de fazer loops no Ansible, anterior à palavra-chave `loop`. Ele repete uma task para cada item de uma lista, expondo o item atual na variável `item`:

```yaml
- name: Mostrar cada fruta
  ansible.builtin.debug:
    msg: "Fruta: {{ item }}"
  with_items:
    - maçã
    - banana
    - laranja
```

Você encontrará `with_items` em muitos playbooks, roles e tutoriais antigos, por isso é importante entendê-lo, mesmo que em código novo a recomendação seja usar `loop` (capítulo anterior).

### 1.1 Situação atual

- O `with_items` **continua funcionando** nas versões atuais do Ansible.
- A documentação recomenda `loop` para código novo, por ser mais simples e uniforme.
- Existe uma **diferença de comportamento** importante entre os dois (o "achatamento" de listas), descrita na seção 3. É nela que ocorrem os erros ao migrar.
- Não é permitido usar `loop` e `with_*` na **mesma task**.

---

## 2. Sintaxe e uso básico

### 2.1 Lista escrita na própria task

```yaml
- name: Criar diretórios
  ansible.builtin.file:
    path: "/opt/{{ item }}"
    state: directory
    mode: "0755"
  with_items:
    - app
    - logs
    - backup
```

### 2.2 Lista guardada em uma variável

Forma recomendada, com aspas e chaves duplas:

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
    with_items: "{{ servicos }}"
```

### 2.3 A forma antiga, com o nome da variável "pelado"

Em playbooks antigos você verá:

```yaml
    with_items: servicos
```

Isso funciona (o Ansible interpreta o texto como o nome da variável), mas é uma forma ambígua e desencorajada. Em código novo, escreva sempre `"{{ servicos }}"`.

### 2.4 Item único (não-lista)

Se o valor não for uma lista, o `with_items` o trata como **um único item**:

```yaml
- ansible.builtin.debug:
    msg: "{{ item }}"
  with_items: "apenas um valor"
```

### 2.5 Listas de dicionários (loop composto)

```yaml
vars:
  usuarios:
    - { nome: ana,   shell: /bin/bash, grupo: dev }
    - { nome: bruno, shell: /bin/sh,   grupo: ops }

tasks:
  - name: Criar os usuários
    ansible.builtin.user:
      name: "{{ item.nome }}"
      shell: "{{ item.shell }}"
      group: "{{ item.grupo }}"
      state: present
    with_items: "{{ usuarios }}"
```

Escrevendo a lista de dicionários diretamente na task:

```yaml
- name: Criar diretórios com dono e modo
  ansible.builtin.file:
    path: "{{ item.path }}"
    state: directory
    owner: "{{ item.owner }}"
    mode: "{{ item.mode }}"
  with_items:
    - { path: /opt/app,      owner: root,    mode: "0755" }
    - { path: /opt/app/logs, owner: appuser, mode: "0750" }
```

### 2.6 Condição por item

```yaml
- name: Instalar apenas os pacotes marcados
  ansible.builtin.package:
    name: "{{ item.nome }}"
    state: present
  with_items:
    - { nome: nginx,   instalar: true }
    - { nome: apache2, instalar: false }
    - { nome: htop,    instalar: true }
  when: item.instalar
```

### 2.7 Controle do loop (`loop_control`)

O `loop_control` funciona também com `with_items` e com as demais variantes `with_*`:

```yaml
- name: Criar os usuários
  ansible.builtin.user:
    name: "{{ item.nome }}"
    state: present
  with_items: "{{ usuarios }}"
  loop_control:
    label: "{{ item.nome }}"
    loop_var: usuario
    pause: 2
```

Atenção: ao usar `loop_var: usuario`, a variável passa a se chamar `usuario`, e não mais `item`.

### 2.8 Variáveis registradas

A estrutura do resultado é a mesma do `loop`: lista em `.results`, com o valor original em `item.item`:

```yaml
- name: Verificar arquivos
  ansible.builtin.stat:
    path: "{{ item }}"
  with_items:
    - /etc/hosts
    - /etc/nao-existe
  register: arquivos

- name: Mostrar quais existem
  ansible.builtin.debug:
    msg: "{{ item.item }}: {{ item.stat.exists }}"
  with_items: "{{ arquivos.results }}"
```

---

## 3. A diferença principal: o `with_items` "achata" listas

Esta é a única diferença que realmente importa na hora de migrar para `loop`.

O `with_items` **achata um nível** de listas aninhadas: se um item é uma lista, seus elementos viram itens individuais. O `loop` **não** faz isso.

### 3.1 Exemplo prático

```yaml
vars:
  grupo_a: [vim, curl]
  grupo_b: [git, htop]
```

Com `with_items`:

```yaml
- ansible.builtin.debug:
    msg: "{{ item }}"
  with_items:
    - "{{ grupo_a }}"
    - "{{ grupo_b }}"
```

Resultado: **4 iterações** (`vim`, `curl`, `git`, `htop`).

Com `loop`, exatamente o mesmo código:

```yaml
- ansible.builtin.debug:
    msg: "{{ item }}"
  loop:
    - "{{ grupo_a }}"
    - "{{ grupo_b }}"
```

Resultado: **2 iterações** (`['vim', 'curl']` e `['git', 'htop']`), cada item sendo uma lista inteira.

### 3.2 Como migrar mantendo o comportamento

```yaml
# Opção 1: somar as listas
loop: "{{ grupo_a + grupo_b }}"

# Opção 2: achatar explicitamente
loop: "{{ [grupo_a, grupo_b] | flatten(levels=1) }}"
```

### 3.3 Cuidados com o achatamento

- Só **um nível** é achatado: `[[1, [2, 3]], [4]]` vira `[1, [2, 3], 4]`.
- Dicionários **não** são achatados; cada dicionário continua sendo um item.
- Se algum item da sua lista é uma lista de propósito (por exemplo, pares `[nome, porta]`), o `with_items` vai quebrá-lo em itens separados. Nesse caso, use `with_list` (que **não** achata) ou `loop`:

```yaml
- ansible.builtin.debug:
    msg: "{{ item[0] }} usa a porta {{ item[1] }}"
  with_list:
    - [web, 80]
    - [ssh, 22]
```

---

## 4. Como o `with_items` funciona por baixo

Todo `with_<algo>` é um atalho para um **lookup plugin**: o Ansible executa o lookup `<algo>`, obtém uma lista e itera sobre ela. No caso de `with_items`, o lookup é o `ansible.builtin.items`, que junta os termos e achata um nível.

Por isso, a equivalência conceitual é:

```yaml
with_items: "{{ lista }}"
# equivale a
loop: "{{ lista | flatten(levels=1) }}"
```

E `with_<algo>: termos` equivale a `loop: "{{ lookup('ansible.builtin.<algo>', termos, wantlist=True) }}"`. Em geral, é mais legível usar os filtros que substituíram esses lookups (seção 6).

---

## 5. A família `with_*`

`with_items` é o membro mais usado de uma família. Segue o que cada um faz, com a variável de item correspondente.

| Diretiva | Itera sobre | Variável de item |
|---|---|---|
| `with_items` | Lista (achata 1 nível) | `item` |
| `with_list` | Lista (**sem** achatar) | `item` |
| `with_dict` | Dicionário | `item.key`, `item.value` |
| `with_nested` / `with_cartesian` | Combinações de listas | `item.0`, `item.1` |
| `with_together` | Listas emparelhadas por posição | `item.0`, `item.1` |
| `with_subelements` | Lista de dicionários e uma sub-lista de cada | `item.0`, `item.1` |
| `with_indexed_items` | Lista com índice | `item.0` (índice), `item.1` (valor) |
| `with_sequence` | Sequência numérica | `item` |
| `with_fileglob` | Arquivos da máquina de controle que casam com um padrão | `item` (caminho) |
| `with_file` | Conteúdo de arquivos da máquina de controle | `item` (conteúdo) |
| `with_lines` | Linhas da saída de um comando (rodado no controle) | `item` |
| `with_first_found` | Primeiro arquivo existente de uma lista | `item` |

### 5.1 `with_list`

Como o `with_items`, mas sem achatar:

```yaml
with_list:
  - [web, 80]
  - [ssh, 22]
```

### 5.2 `with_dict`

```yaml
vars:
  parametros_app:
    porta: 8080
    modo: producao
    workers: 4

tasks:
  - name: Gravar cada parâmetro
    ansible.builtin.lineinfile:
      path: /etc/app.conf
      regexp: "^{{ item.key }}="
      line: "{{ item.key }}={{ item.value }}"
      create: true
      mode: "0644"
    with_dict: "{{ parametros_app }}"
```

Dicionário de dicionários:

```yaml
vars:
  diretorios:
    /opt/app:
      owner: root
      mode: "0755"
    /opt/app/logs:
      owner: appuser
      mode: "0750"

tasks:
  - name: Criar os diretórios
    ansible.builtin.file:
      path: "{{ item.key }}"
      state: directory
      owner: "{{ item.value.owner }}"
      mode: "{{ item.value.mode }}"
    with_dict: "{{ diretorios }}"
```

### 5.3 `with_nested` (todas as combinações)

```yaml
- name: Criar a estrutura ambiente/serviço
  ansible.builtin.file:
    path: "/srv/{{ item.0 }}/{{ item.1 }}"
    state: directory
    mode: "0755"
  with_nested:
    - [dev, homolog, prod]
    - [web, db]
```

Gera seis combinações. `with_cartesian` tem o mesmo efeito.

### 5.4 `with_together` (emparelhar listas)

```yaml
vars:
  hosts_banco: [db01, db02]
  ips_banco: [10.0.0.11, 10.0.0.12]

tasks:
  - name: Registrar no /etc/hosts
    ansible.builtin.lineinfile:
      path: /etc/hosts
      line: "{{ item.1 }} {{ item.0 }}"
    with_together:
      - "{{ hosts_banco }}"
      - "{{ ips_banco }}"
```

### 5.5 `with_subelements`

```yaml
vars:
  usuarios:
    - nome: ana
      projetos: [alpha, beta]
    - nome: bruno
      projetos: [gama]

tasks:
  - name: Criar as pastas de projeto por usuário
    ansible.builtin.file:
      path: "/home/{{ item.0.nome }}/{{ item.1 }}"
      state: directory
      owner: "{{ item.0.nome }}"
      mode: "0750"
    with_subelements:
      - "{{ usuarios }}"
      - projetos
```

Para tolerar usuários sem o campo `projetos`:

```yaml
    with_subelements:
      - "{{ usuarios }}"
      - projetos
      - skip_missing: true
```

### 5.6 `with_indexed_items`

```yaml
- ansible.builtin.debug:
    msg: "{{ item.0 + 1 }}. {{ item.1 }}"
  with_indexed_items:
    - alfa
    - beta
    - gama
```

`item.0` é o índice (começa em 0) e `item.1` é o valor.

### 5.7 `with_sequence`

```yaml
- name: Contar de 1 a 5
  ansible.builtin.debug:
    msg: "Número {{ item }}"
  with_sequence: start=1 end=5

- name: Criar servidores web01 a web03
  ansible.builtin.debug:
    msg: "{{ item }}"
  with_sequence: start=1 end=3 format=web%02d
```

Parâmetros: `start`, `end`, `stride` (passo), `count` e `format` (estilo `printf`). Os itens são **textos**; converta com `| int` se precisar de número.

### 5.8 `with_fileglob`, `with_file` e `with_lines`

Estes três atuam na **máquina de controle**, não nos hosts remotos.

```yaml
# Copiar todos os .conf da pasta local files/
- name: Copiar arquivos de configuração
  ansible.builtin.copy:
    src: "{{ item }}"
    dest: "/etc/app/{{ item | basename }}"
    mode: "0644"
  with_fileglob:
    - "files/*.conf"

# Ler o conteúdo de arquivos locais
- ansible.builtin.debug:
    msg: "{{ item }}"
  with_file:
    - files/aviso.txt

# Cada linha da saída de um comando local vira um item
- ansible.builtin.debug:
    msg: "{{ item }}"
  with_lines: cat lista_de_hosts.txt
```

---

## 6. Migrando para `loop`

| `with_*` | Equivalente com `loop` |
|---|---|
| `with_items: lista` | `loop: "{{ lista \| flatten(levels=1) }}"` (ou apenas `loop: "{{ lista }}"` se não houver listas aninhadas) |
| `with_list: lista` | `loop: "{{ lista }}"` |
| `with_dict: dic` | `loop: "{{ dic \| dict2items }}"` |
| `with_nested: [a, b]` | `loop: "{{ a \| product(b) \| list }}"` |
| `with_cartesian: [a, b]` | `loop: "{{ a \| product(b) \| list }}"` |
| `with_together: [a, b]` | `loop: "{{ a \| zip(b) \| list }}"` |
| `with_subelements: [lista, 'campo']` | `loop: "{{ lista \| subelements('campo') }}"` |
| `with_indexed_items: lista` | `loop: "{{ lista }}"` + `loop_control: index_var: idx` |
| `with_sequence: start=1 end=5` | `loop: "{{ range(1, 6) \| list }}"` |
| `with_fileglob: 'files/*.conf'` | `loop: "{{ query('fileglob', 'files/*.conf') }}"` |
| `with_file: arq` | `loop: "{{ query('file', 'arq') }}"` |
| `with_lines: comando` | `loop: "{{ query('lines', 'comando') }}"` |

### 6.1 Exemplo antes e depois

Antes:

```yaml
- name: Gravar cada parâmetro
  ansible.builtin.lineinfile:
    path: /etc/app.conf
    regexp: "^{{ item.key }}="
    line: "{{ item.key }}={{ item.value }}"
    create: true
  with_dict: "{{ parametros_app }}"
```

Depois:

```yaml
- name: Gravar cada parâmetro
  ansible.builtin.lineinfile:
    path: /etc/app.conf
    regexp: "^{{ item.key }}="
    line: "{{ item.key }}={{ item.value }}"
    create: true
  loop: "{{ parametros_app | dict2items }}"
```

### 6.2 Roteiro para migrar um playbook

1. Troque `with_items: X` por `loop: "{{ X }}"`.
2. Verifique se algum item é uma **lista** (ou se a variável é "lista de listas"). Se for, adicione `| flatten(levels=1)` ou reescreva a estrutura.
3. Converta as demais variantes `with_*` pela tabela anterior.
4. Se o `with_items` era do tipo "nome pelado" (`with_items: pacotes`), passe para `"{{ pacotes }}"`.
5. Execute com `--check` e compare o número de iterações antes e depois (a saída mostra um `item=` por linha).
6. Mantenha `loop_control`, `when` e `register`: funcionam sem alteração.

---

## 7. Exemplo completo

Playbook com `with_items` e variantes, no estilo clássico, funcionando em Debian e Red Hat:

```yaml
---
- name: Configuração no estilo with_items
  hosts: all
  gather_facts: true
  become: true

  vars:
    grupos_de_pacotes:
      - [vim, curl]
      - [git, htop]

    pacote_web:
      Debian: apache2
      RedHat: httpd

    usuarios:
      - { nome: ana,   shell: /bin/bash }
      - { nome: bruno, shell: /bin/sh }

    parametros_app:
      porta: 8080
      modo: producao

  tasks:
    - name: Instalar os pacotes (a lista de listas é achatada)
      ansible.builtin.package:
        name: "{{ item }}"
        state: present
      with_items: "{{ grupos_de_pacotes }}"
      tags: pacotes

    - name: Instalar o servidor web
      ansible.builtin.package:
        name: "{{ pacote_web[ansible_facts['os_family']] }}"
        state: present
      tags: pacotes

    - name: Criar os usuários
      ansible.builtin.user:
        name: "{{ item.nome }}"
        shell: "{{ item.shell }}"
        state: present
      with_items: "{{ usuarios }}"
      loop_control:
        label: "{{ item.nome }}"
      tags: usuarios

    - name: Gravar os parâmetros da aplicação
      ansible.builtin.lineinfile:
        path: /etc/app.conf
        regexp: "^{{ item.key }}="
        line: "{{ item.key }}={{ item.value }}"
        create: true
        mode: "0644"
      with_dict: "{{ parametros_app }}"
      tags: config
```

Versão equivalente moderna das tasks principais:

```yaml
    - name: Instalar os pacotes (uma única chamada)
      ansible.builtin.package:
        name: "{{ grupos_de_pacotes | flatten }}"
        state: present

    - name: Criar os usuários
      ansible.builtin.user:
        name: "{{ item.nome }}"
        shell: "{{ item.shell }}"
        state: present
      loop: "{{ usuarios }}"
      loop_control:
        label: "{{ item.nome }}"

    - name: Gravar os parâmetros da aplicação
      ansible.builtin.lineinfile:
        path: /etc/app.conf
        regexp: "^{{ item.key }}="
        line: "{{ item.key }}={{ item.value }}"
        create: true
        mode: "0644"
      loop: "{{ parametros_app | dict2items }}"
```

Observe a primeira task: em vez de um loop com uma chamada ao gerenciador de pacotes por item, a versão moderna achata a lista e entrega tudo ao módulo de uma vez, o que é bem mais rápido.

---

## 8. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Migrei para `loop` e o número de iterações mudou | O `with_items` achatava listas aninhadas | `flatten(levels=1)` |
| Pares `[nome, porta]` viram dois itens separados | `with_items` achata cada par | `with_list` ou `loop` |
| `You cannot use loop and with_ together` (ou erro semelhante) | `loop` e `with_*` na mesma task | Usar apenas um |
| `with_items` com variável "pelada" dá comportamento estranho | O texto foi tratado como valor literal | Usar `"{{ variavel }}"` |
| `item.key` indefinido | Usou `with_items` onde deveria ser `with_dict` (ou `dict2items`) | Converter o dicionário |
| `with_fileglob` não acha arquivos | Procura na máquina de controle | Conferir caminho local; usar `find` para hosts remotos |
| `with_sequence` gera textos, não números | Itens são strings | `\| int` |
| Saída gigante com dicionários | Falta `label` | `loop_control: label` |
| Instalação lenta de pacotes | Uma chamada ao gerenciador por item | Passar a lista inteira ao módulo |
| `item` indefinido em include | `loop_var` renomeado | Usar o nome definido em `loop_var` |
| Loops aninhados com `include_tasks` se confundem | Ambos usam `item` | `loop_var` no externo |

---

## 9. Boas práticas

1. **Em código novo, use `loop`** com os filtros equivalentes; use `with_items` apenas para manter ou entender código antigo.
2. **Ao manter código antigo,** não misture `loop` e `with_*` na mesma task; migre task por task, testando.
3. **Escreva sempre `"{{ variavel }}"`** em vez de nomes "pelados".
4. **Cuidado com o achatamento:** se a estrutura tem listas aninhadas de propósito, use `with_list` ou `loop`.
5. **Passe listas direto a módulos que as aceitam** (`package`, `apt`, `dnf`), em vez de fazer loop.
6. **Use `loop_control: label`** para manter a saída legível.
7. **Prefira listas de dicionários** a estruturas profundamente aninhadas.
8. **Compare as saídas** antes e depois de migrar, com `--check`, verificando o número de itens.
9. **Documente** no playbook por que uma estrutura é achatada, quando isso for intencional.
10. **Para operações na máquina de controle** (`fileglob`, `file`, `lines`), deixe claro nos comentários que o caminho é local.

---

## Resumo

| Necessidade | `with_*` clássico | Moderno (`loop`) |
|---|---|---|
| Lista simples | `with_items: "{{ lista }}"` | `loop: "{{ lista }}"` |
| Lista de listas (achatar) | `with_items` | `loop: "{{ lista \| flatten(levels=1) }}"` |
| Lista sem achatar | `with_list` | `loop` |
| Lista de dicionários | `with_items` + `item.campo` | `loop` + `item.campo` |
| Dicionário | `with_dict` + `item.key`, `item.value` | `dict2items` |
| Todas as combinações | `with_nested` | `product` |
| Listas emparelhadas | `with_together` | `zip` |
| Lista dentro de lista de itens | `with_subelements` | `subelements` |
| Sequência numérica | `with_sequence` | `range` |
| Arquivos locais por padrão | `with_fileglob` | `query('fileglob', ...)` |
| Renomear o `item` | `loop_control: loop_var` | `loop_control: loop_var` |
| Saída limpa | `loop_control: label` | `loop_control: label` |
| Condição por item | `when` | `when` |
| Resultados registrados | `.results` | `.results` |
