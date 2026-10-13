# Capítulo: `loop_control`

## 1. O que é o `loop_control`

O `loop_control` é uma palavra-chave que **ajusta o comportamento de um loop**: como o item é exibido, qual o nome da variável do item, se há pausa entre repetições, que informações extras ficam disponíveis e quando o loop deve parar.

Ele é escrito no nível da task, ao lado de `loop` (ou `with_*`), e recebe um dicionário de opções:

```yaml
- name: Criar usuários
  ansible.builtin.user:
    name: "{{ item.nome }}"
    state: present
  loop: "{{ usuarios }}"
  loop_control:
    label: "{{ item.nome }}"
    pause: 2
```

Ele não faz sentido sozinho: só existe junto de uma task que tenha `loop` (ou `with_*`, `include_tasks` com `loop`, `include_role` com `loop`).

---

## 2. Visão geral das opções

| Opção | Para que serve | Observação |
|---|---|---|
| `label` | Texto exibido na saída para cada item | Só altera a **exibição** |
| `loop_var` | Renomeia a variável `item` | Essencial em loops aninhados |
| `index_var` | Cria uma variável com o índice (começa em 0) | |
| `pause` | Espera N segundos entre as repetições | |
| `extended` | Habilita a variável `ansible_loop` | Posição, primeiro, último, item anterior e próximo |
| `extended_allitems` | Controla se `ansible_loop.allitems` é incluída | Usado com `extended`; versões recentes |
| `break_when` | Interrompe o loop quando a condição for verdadeira | `ansible-core` 2.18 ou superior |

Exemplo com várias opções juntas:

```yaml
loop_control:
  label: "{{ item.nome }}"
  loop_var: usuario
  index_var: idx
  pause: 1
  extended: true
```

> Os nomes passados a `loop_var` e `index_var` são **literais** (não aceitam templates). Já `label`, `pause` e `break_when` são avaliados a cada iteração.

---

## 3. `label`: saída legível

### 3.1 O problema

Quando os itens são dicionários, o Ansible imprime o item inteiro em cada linha:

```yaml
- name: Criar os usuários
  ansible.builtin.user:
    name: "{{ item.nome }}"
    shell: "{{ item.shell }}"
  loop:
    - { nome: ana,   shell: /bin/bash, grupo: dev, ativo: true }
    - { nome: bruno, shell: /bin/sh,   grupo: ops, ativo: true }
```

```
changed: [deb00] => (item={'nome': 'ana', 'shell': '/bin/bash', 'grupo': 'dev', 'ativo': True})
changed: [deb00] => (item={'nome': 'bruno', 'shell': '/bin/sh', 'grupo': 'ops', 'ativo': True})
```

### 3.2 A solução

```yaml
  loop_control:
    label: "{{ item.nome }}"
```

```
changed: [deb00] => (item=ana)
changed: [deb00] => (item=bruno)
```

### 3.3 Rótulos mais ricos

```yaml
# Vários campos
label: "{{ item.nome }} ({{ item.grupo }})"

# Loop com dict2items
label: "{{ item.key }}"

# Resultado de um loop registrado
label: "{{ item.item }}"

# Elementos de subelements
label: "{{ item.0.nome }} / {{ item.1 }}"
```

### 3.4 O que o `label` **não** faz

O `label` muda **somente o que é mostrado** na linha de cada item. O item completo continua existindo:

- nas variáveis registradas (`res.results[*].item`);
- na saída com verbosidade (`-v`, `-vv`...), que exibe o resultado detalhado.

Portanto, o `label` **não protege dados sensíveis** (senhas, tokens). Para isso, combine com `no_log: true`:

```yaml
- name: Definir senhas
  ansible.builtin.user:
    name: "{{ item.nome }}"
    password: "{{ item.senha_hash }}"
  loop: "{{ usuarios }}"
  loop_control:
    label: "{{ item.nome }}"
  no_log: true
```

Com `no_log`, o conteúdo dos resultados fica oculto e o `label` deixa de ter efeito visível. Use-o quando o item contiver segredos, e use `label` sozinho quando o objetivo for apenas deixar a saída limpa.

---

## 4. `loop_var`: renomeando o `item`

### 4.1 Por que existe

Dentro de um loop, `item` é a variável do item atual. Se uma task incluída (`include_tasks`) ou uma role também fizer um loop, os dois usariam o mesmo nome `item`, e um sobrescreveria o outro. O Ansible avisa quando isso acontece:

```
[WARNING]: The loop variable 'item' is already in use. You should set the `loop_var`
value in the `loop_control` option for the task to something else to avoid variable
collisions and unexpected behavior.
```

### 4.2 Uso básico

```yaml
- name: Criar os usuários
  ansible.builtin.user:
    name: "{{ usuario.nome }}"
    shell: "{{ usuario.shell }}"
  loop: "{{ usuarios }}"
  loop_control:
    loop_var: usuario
    label: "{{ usuario.nome }}"
```

Dentro da task, a variável passa a ser `usuario`, **e não mais** `item`.

### 4.3 Loops aninhados com `include_tasks`

Playbook principal:

```yaml
---
- name: Estrutura de vários sites
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
- name: Criar a pasta raiz
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

O loop externo usa `site` e o interno continua usando `item`, sem colisão.

### 4.4 Roles e `loop_var`

Quem escreve **roles reutilizáveis** com loops deve usar um `loop_var` com prefixo próprio da role, para não conflitar com o `item` de quem a chama:

```yaml
# roles/web/tasks/main.yml
- name: Criar os virtual hosts
  ansible.builtin.template:
    src: vhost.conf.j2
    dest: "/etc/apache2/sites-available/{{ web_site.nome }}.conf"
    mode: "0644"
  loop: "{{ web_sites }}"
  loop_control:
    loop_var: web_site
```

### 4.5 A variável `ansible_loop_var`

Em cada resultado de um loop registrado, o Ansible guarda o valor do item em uma chave com o **mesmo nome do `loop_var`** (por padrão, `item`) e anota esse nome em `ansible_loop_var`. Ou seja, com `loop_var: arquivo`, o valor original aparece em `arquivo`, e não em `item`.

```yaml
- name: Verificar arquivos
  ansible.builtin.stat:
    path: "{{ arquivo }}"
  loop: [/etc/hosts, /etc/hostname]
  loop_control:
    loop_var: arquivo
  register: arquivos

- name: Ler o resultado
  ansible.builtin.debug:
    msg: "{{ item.arquivo }}: {{ item.stat.exists }}"
  loop: "{{ arquivos.results }}"
```

Note: nos `results`, o valor original está em `item.arquivo` (e não em `item.item`), porque a chave segue o `loop_var`. Em caso de dúvida, inspecione com `debug: var=arquivos`.

---

## 5. `index_var`: o índice do item

Cria uma variável com a posição do item, **começando em 0**:

```yaml
- name: Listar com número
  ansible.builtin.debug:
    msg: "{{ idx + 1 }}. {{ item }}"
  loop:
    - alfa
    - beta
    - gama
  loop_control:
    index_var: idx
```

Saída: `1. alfa`, `2. beta`, `3. gama`.

Usos típicos:

```yaml
# Nomes numerados
name: "web{{ '%02d' | format(idx + 1) }}"

# Portas sequenciais
port: "{{ 8080 + idx }}"

# Gravar com ordem
line: "{{ idx }}={{ item }}"
```

Exemplo prático: criar servidores numerados com portas consecutivas:

```yaml
- name: Gravar a lista de instâncias
  ansible.builtin.lineinfile:
    path: /etc/instancias.conf
    regexp: "^instancia{{ idx }}="
    line: "instancia{{ idx }}={{ item }}:{{ 8080 + idx }}"
    create: true
    mode: "0644"
  loop: [app-a, app-b, app-c]
  loop_control:
    index_var: idx
```

Resultado no arquivo:

```
instancia0=app-a:8080
instancia1=app-b:8081
instancia2=app-c:8082
```

Se precisar de índice com `extended`, prefira `ansible_loop.index` (começa em 1) ou `ansible_loop.index0` (começa em 0), vistos adiante.

---

## 6. `pause`: intervalo entre repetições

Espera N segundos **entre** uma iteração e a próxima:

```yaml
- name: Reiniciar os serviços, um de cada vez
  ansible.builtin.service:
    name: "{{ item }}"
    state: restarted
  loop:
    - app1
    - app2
    - app3
  loop_control:
    pause: 10
```

Quando usar:

- **reinícios escalonados**, para dar tempo ao serviço de subir;
- **APIs com limite de requisições**, para respeitar o rate limit;
- **operações pesadas**, para evitar sobrecarga.

Observações:

- A pausa é aplicada por host, em cada loop. Com muitos hosts, o tempo total cresce proporcionalmente à lista de itens.
- Para uma pausa única em um ponto do playbook, use o módulo `ansible.builtin.pause` (capítulo de prompts).
- Para espera com condição (por exemplo, até o serviço responder), use `until`, `retries` e `delay`, ou `wait_for`.

---

## 7. `extended`: informações detalhadas do loop

Com `extended: true`, a variável **`ansible_loop`** passa a existir dentro do loop:

| Campo | Conteúdo |
|---|---|
| `ansible_loop.index` | Posição atual, começando em 1 |
| `ansible_loop.index0` | Posição atual, começando em 0 |
| `ansible_loop.revindex` | Itens restantes, incluindo o atual (termina em 1) |
| `ansible_loop.revindex0` | Itens restantes depois do atual (termina em 0) |
| `ansible_loop.first` | Verdadeiro no primeiro item |
| `ansible_loop.last` | Verdadeiro no último item |
| `ansible_loop.length` | Total de itens |
| `ansible_loop.previtem` | Item anterior (**não existe** no primeiro) |
| `ansible_loop.nextitem` | Próximo item (**não existe** no último) |
| `ansible_loop.allitems` | Lista com todos os itens |

### 7.1 Progresso

```yaml
- name: Mostrar o progresso
  ansible.builtin.debug:
    msg: "Item {{ ansible_loop.index }} de {{ ansible_loop.length }}: {{ item }}"
  loop: [a, b, c]
  loop_control:
    extended: true
```

### 7.2 Ações no primeiro e no último item

```yaml
- name: Processar com início e fim
  ansible.builtin.debug:
    msg: "{{ '=== INÍCIO ===' if ansible_loop.first else '' }} {{ item }} {{ '=== FIM ===' if ansible_loop.last else '' }}"
  loop: "{{ itens }}"
  loop_control:
    extended: true
```

Ou, com tasks separadas:

```yaml
- name: Só no primeiro item
  ansible.builtin.debug:
    msg: "Começando o lote"
  when: ansible_loop.first

- name: Só no último item
  ansible.builtin.debug:
    msg: "Lote concluído"
  when: ansible_loop.last
```

(Ambas precisam ter o mesmo `loop` e `loop_control: extended: true`; aqui estão resumidas.)

### 7.3 Item anterior e próximo: detectar mudança de grupo

Com a lista ordenada por grupo, mostrar um cabeçalho sempre que o grupo muda:

```yaml
vars:
  usuarios:
    - { nome: ana,   grupo: dev }
    - { nome: carla, grupo: dev }
    - { nome: bruno, grupo: ops }

tasks:
  - name: Listar agrupando
    ansible.builtin.debug:
      msg: "{{ '[' ~ item.grupo ~ ']' if (ansible_loop.first or item.grupo != ansible_loop.previtem.grupo) else '' }} {{ item.nome }}"
    loop: "{{ usuarios | sort(attribute='grupo') }}"
    loop_control:
      extended: true
      label: "{{ item.nome }}"
```

Atenção: `previtem` não existe no primeiro item, por isso o teste `ansible_loop.first or ...` vem antes, protegendo a expressão (o `or` avalia o lado direito só se o esquerdo for falso).

### 7.4 `extended_allitems`

O campo `ansible_loop.allitems` guarda uma cópia da lista completa **em cada iteração**, o que pode consumir muita memória em listas grandes. Se você não o usa, desative-o (disponível em versões recentes do `ansible-core`):

```yaml
loop_control:
  extended: true
  extended_allitems: false
```

---

## 8. `break_when`: parar o loop antes do fim

Interrompe o loop assim que a condição for verdadeira (após a iteração em que ela se verificou). Aceita uma condição ou uma lista de condições (todas precisam ser verdadeiras).

> Disponível a partir do `ansible-core` **2.18**. Em versões mais antigas, processe a lista toda e escolha o resultado desejado com `selectattr`.

### 8.1 Parar no primeiro resultado desejado

```yaml
- name: Procurar o primeiro arquivo de configuração existente
  ansible.builtin.stat:
    path: "{{ item }}"
    get_checksum: false
  loop:
    - /etc/apache2/apache2.conf
    - /etc/httpd/conf/httpd.conf
    - /etc/nginx/nginx.conf
  register: busca
  loop_control:
    break_when: busca.stat.exists | default(false)
```

O resultado da iteração atual fica disponível pelo nome do `register`, o que permite decidir com base nele. Teste no seu ambiente se estiver em uma versão próxima do limite.

### 8.2 Parar com base no item

```yaml
- name: Processar até encontrar o item "pare"
  ansible.builtin.debug:
    msg: "{{ item }}"
  loop: [a, b, pare, c, d]
  loop_control:
    break_when: item == "pare"
```

Itera sobre `a`, `b` e `pare`, e para antes de `c`.

### 8.3 Alternativa para versões antigas

```yaml
- name: Verificar todos os caminhos
  ansible.builtin.stat:
    path: "{{ item }}"
  loop:
    - /etc/apache2/apache2.conf
    - /etc/httpd/conf/httpd.conf
  register: busca

- name: Escolher o primeiro que existe
  ansible.builtin.set_fact:
    conf_path: "{{ busca.results | selectattr('stat.exists') | map(attribute='item') | first | default('') }}"
```

---

## 9. Combinando as opções

```yaml
- name: Reiniciar serviços em ordem, com progresso
  ansible.builtin.service:
    name: "{{ servico.nome }}"
    state: restarted
  loop: "{{ servicos }}"
  loop_control:
    loop_var: servico
    label: "{{ servico.nome }}"
    index_var: idx
    pause: 5
    extended: true
    extended_allitems: false
  when: servico.reiniciar | default(true)
```

Dentro da task, você tem `servico` (o item), `idx` (índice a partir de 0) e `ansible_loop` (posição, primeiro, último...). Somente o `label` e o `pause` são vistos na saída e no tempo de execução; os demais são variáveis para uso interno.

---

## 10. Onde o `loop_control` pode ser usado

| Contexto | Funciona? | Observação |
|---|---|---|
| Task com `loop` | Sim | Uso normal |
| Task com `with_items` e demais `with_*` | Sim | Mesmas opções |
| `include_tasks` com `loop` | Sim | Use `loop_var` para evitar colisões |
| `include_role` com `loop` | Sim | Idem |
| `import_tasks` e `import_role` | Não | São estáticos e **não aceitam loop** |
| `block` | Não | Blocos não aceitam `loop`; use `include_tasks` + `loop` |

---

## 11. Exemplo completo

Playbook com reinícios escalonados, usuários agrupados, procura de arquivo e loops aninhados, em Debian e Red Hat:

```yaml
---
- name: Exemplo de loop_control
  hosts: all
  gather_facts: true
  become: true

  vars:
    usuarios:
      - { nome: ana,   grupo: dev, shell: /bin/bash }
      - { nome: carla, grupo: dev, shell: /bin/bash }
      - { nome: bruno, grupo: ops, shell: /bin/sh }

    servicos:
      - cron
      - rsyslog

    sites:
      - nome: loja.exemplo.com
        pastas: [html, logs]
      - nome: blog.exemplo.com
        pastas: [html]

  tasks:
    - name: Criar os grupos
      ansible.builtin.group:
        name: "{{ item }}"
        state: present
      loop: "{{ usuarios | map(attribute='grupo') | unique | list }}"
      tags: usuarios

    - name: Criar os usuários (saída limpa e progresso)
      ansible.builtin.user:
        name: "{{ usuario.nome }}"
        shell: "{{ usuario.shell }}"
        group: "{{ usuario.grupo }}"
        state: present
      loop: "{{ usuarios | sort(attribute='grupo') }}"
      loop_control:
        loop_var: usuario
        label: "{{ usuario.nome }}"
        extended: true
        extended_allitems: false
      register: criados
      tags: usuarios

    - name: Resumo da criação
      ansible.builtin.debug:
        msg: "{{ item.usuario.nome }}: {{ 'criado' if item.changed else 'já existia' }}"
      loop: "{{ criados.results }}"
      loop_control:
        label: "{{ item.usuario.nome }}"
      run_once: true
      tags: usuarios

    - name: Reiniciar os serviços, um de cada vez
      ansible.builtin.service:
        name: "{{ item }}"
        state: restarted
      loop: "{{ servicos }}"
      loop_control:
        pause: 3
        index_var: idx
        label: "{{ idx + 1 }}/{{ servicos | length }}: {{ item }}"
      tags: servicos

    - name: Criar a estrutura de cada site
      ansible.builtin.include_tasks: site.yml
      loop: "{{ sites }}"
      loop_control:
        loop_var: site
        label: "{{ site.nome }}"
      tags: sites
```

Arquivo `site.yml` (na mesma pasta):

```yaml
---
- name: Criar a pasta raiz de {{ site.nome }}
  ansible.builtin.file:
    path: "/var/www/{{ site.nome }}"
    state: directory
    mode: "0755"

- name: Criar as subpastas de {{ site.nome }}
  ansible.builtin.file:
    path: "/var/www/{{ site.nome }}/{{ item }}"
    state: directory
    mode: "0755"
  loop: "{{ site.pastas }}"
```

Execuções:

```bash
ansible-playbook -i hosts lc.yml -K
ansible-playbook -i hosts lc.yml -K --tags usuarios --limit deb00,deb02
ansible-playbook -i hosts lc.yml -K --tags servicos --check
```

Os serviços `cron` e `rsyslog` existem no Debian; no Red Hat os nomes equivalentes são `crond` e `rsyslog`. Ajuste a lista (por exemplo, com um dicionário por família de SO, como visto nos capítulos de variáveis e facts) se o seu inventário for misto.

---

## 12. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `[WARNING]: The loop variable 'item' is already in use` | Loops aninhados (include ou role) usando o mesmo nome | `loop_var` no loop externo |
| `'item' is undefined` após definir `loop_var` | O nome da variável mudou | Usar o nome definido em `loop_var` |
| Em `results`, não encontro `item.item` | Com `loop_var: x`, a chave nos resultados é `x` | Usar `item.x` ou conferir com `debug: var=` |
| Saída continua gigante | Falta `label` | `loop_control: label:` |
| Senha aparece com `-v` mesmo com `label` | `label` só afeta a exibição da linha | `no_log: true` |
| `ansible_loop` indefinido | Falta `extended: true` | Habilitar em `loop_control` |
| `ansible_loop.previtem` indefinido no primeiro item | Não existe item anterior | Testar `ansible_loop.first` antes |
| `ansible_loop.nextitem` indefinido no último item | Não existe próximo item | Testar `ansible_loop.last` antes |
| Playbook lento com `pause` | A pausa se soma ao tempo de cada item | Reduzir o tempo ou aplicar apenas onde necessário |
| `break_when` não é reconhecido | Versão do `ansible-core` anterior à 2.18 | Atualizar, ou usar `selectattr` ao final |
| `loop_control` em `block` dá erro | Blocos não aceitam `loop` | `include_tasks` com `loop` |
| `loop_control` em `import_tasks` dá erro | Imports são estáticos | Usar `include_tasks` |
| Consumo alto de memória com listas grandes | `ansible_loop.allitems` copiado a cada iteração | `extended_allitems: false` |
| `idx` começa em 0 e a numeração fica estranha | `index_var` é baseado em 0 | `idx + 1` ou `ansible_loop.index` |

---

## 13. Boas práticas

1. **Use `label` em todo loop com dicionários**, para manter a saída legível.
2. **Combine `label` e `no_log`** quando houver segredos: o `label` sozinho não protege nada.
3. **Use `loop_var` sempre** que a task for incluída por outra com loop ou fizer parte de uma role; em roles, use um nome com prefixo da role.
4. **Prefira nomes descritivos** (`usuario`, `site`, `servico`) em vez de `item`, quando o loop é longo ou aninhado.
5. **Use `index_var`** para numeração e portas sequenciais, lembrando que começa em 0.
6. **Use `extended` apenas quando precisar** de posição, primeiro, último, anterior ou próximo.
7. **Desative `extended_allitems`** em listas grandes.
8. **Use `pause` em reinícios escalonados** e APIs com limites, e prefira `until` ou `wait_for` quando a espera depender de uma condição.
9. **Use `break_when`** para parar na primeira ocorrência, ciente do requisito de versão.
10. **Para repetir várias tasks por item**, use `include_tasks` com `loop` e `loop_control: loop_var`.
11. **Inspecione os resultados** com `debug: var=` antes de montar loops sobre `register.results`, para conferir os nomes das chaves.
12. **Teste com `--check`** e com listas pequenas.

---

## Resumo

| Necessidade | Opção |
|---|---|
| Saída mais curta e legível | `label` |
| Esconder segredos | `no_log: true` (e `label`) |
| Renomear `item` | `loop_var` |
| Evitar colisão em loops aninhados e roles | `loop_var` |
| Índice a partir de 0 | `index_var` |
| Intervalo entre itens | `pause` |
| Progresso e posição (começa em 1) | `extended` + `ansible_loop.index` e `ansible_loop.length` |
| Ações no primeiro e no último item | `ansible_loop.first`, `ansible_loop.last` |
| Comparar com o item anterior ou o próximo | `ansible_loop.previtem`, `ansible_loop.nextitem` |
| Economizar memória | `extended_allitems: false` |
| Parar cedo | `break_when` (2.18+) |
| Repetir um grupo de tasks por item | `include_tasks` + `loop` + `loop_var` |
| Onde não funciona | `block`, `import_tasks`, `import_role` |
