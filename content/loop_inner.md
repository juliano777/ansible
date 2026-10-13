# Capítulo: Loops Internos (Inner Loops) com `include_tasks` e `loop_var`

## 1. O problema: um loop dentro de outro

Uma task do Ansible aceita **um único `loop`**. Mas muitas situações pedem dois níveis de repetição:

- para cada **site**, criar várias **pastas**;
- para cada **cliente**, para cada **projeto**, criar um **ambiente**;
- para cada **servidor**, aplicar várias **configurações**.

Quando a repetição interna envolve **várias tasks**, ou lógica própria (condições, blocos, tratamento de erro), a solução padrão é:

1. O **loop externo** fica em uma task `include_tasks`.
2. O arquivo incluído contém as tasks que usam o **loop interno**.
3. O `loop_var` do loop externo recebe um **nome próprio**, para não colidir com o `item` do loop interno.

```
Playbook ─ include_tasks (loop externo: loop_var = site)
              └─ site.yml ─ task com loop interno (item)
```

---

## 2. Por que o `loop_var` é indispensável

Dentro de um loop, o item atual se chama `item`. Se o loop externo e o interno usarem o mesmo nome, um **sobrescreve** o outro:

```yaml
# PROBLEMA: os dois loops usam "item"
- name: Configurar cada site
  ansible.builtin.include_tasks: site.yml
  loop: "{{ sites }}"          # item = site (dicionário)
```

```yaml
# site.yml
- name: Criar as subpastas
  ansible.builtin.file:
    path: "/var/www/{{ item.nome }}/{{ item }}"   # item é o site ou a pasta?
    state: directory
  loop: "{{ item.pastas }}"                       # aqui "item" é redefinido
```

O Ansible detecta a situação e avisa:

```
[WARNING]: The loop variable 'item' is already in use. You should set the `loop_var`
value in the `loop_control` option for the task to something else to avoid variable
collisions and unexpected behavior.
```

A correção é renomear a variável do loop externo:

```yaml
- name: Configurar cada site
  ansible.builtin.include_tasks: site.yml
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
```

Agora `site` é o site e `item` fica livre para o loop interno.

---

## 3. O padrão básico, passo a passo

### 3.1 Os dados

```yaml
vars:
  sites:
    - nome: loja.exemplo.com
      pastas: [html, logs, backup]
    - nome: blog.exemplo.com
      pastas: [html, logs]
```

### 3.2 O playbook (loop externo)

```yaml
---
- name: Criar a estrutura dos sites
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

### 3.3 O arquivo incluído (loop interno)

`site.yml`, na mesma pasta do playbook:

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

### 3.4 O que acontece

1. O Ansible repete a task `include_tasks` uma vez para cada site.
2. A cada repetição, carrega `site.yml` com a variável `site` definida.
3. Dentro do arquivo, as tasks enxergam `site` (o externo) e `item` (o interno).

Resultado: `/var/www/loja.exemplo.com/{html,logs,backup}` e `/var/www/blog.exemplo.com/{html,logs}`.

> O nome da task usa `{{ site.nome }}`: isso é permitido e ajuda a ler a saída, pois cada repetição mostra o site correspondente.

---

## 4. Nomeando os dois níveis

Mesmo com o `item` livre para o loop interno, é **boa prática** nomear os dois, principalmente em arquivos longos:

```yaml
# site.yml
- name: Criar as subpastas de {{ site.nome }}
  ansible.builtin.file:
    path: "/var/www/{{ site.nome }}/{{ pasta }}"
    state: directory
    mode: "0755"
  loop: "{{ site.pastas }}"
  loop_control:
    loop_var: pasta
    label: "{{ site.nome }}/{{ pasta }}"
```

Assim, o código fica autoexplicativo (`site` e `pasta`, e não `site` e `item`) e é seguro caso o arquivo seja incluído por outro loop no futuro.

---

## 5. Passando dados ao arquivo incluído

### 5.1 As variáveis do loop e do play já estão disponíveis

O arquivo incluído enxerga: variáveis do play, facts, `site` (o `loop_var` externo) e qualquer variável de `index_var` do loop externo.

### 5.2 Parâmetros extras com `vars`

```yaml
- name: Configurar cada site
  ansible.builtin.include_tasks: site.yml
  vars:
    dono: www-data
    modo_pasta: "0750"
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
```

```yaml
# site.yml
- name: Criar as subpastas
  ansible.builtin.file:
    path: "/var/www/{{ site.nome }}/{{ item }}"
    state: directory
    owner: "{{ dono }}"
    mode: "{{ modo_pasta }}"
  loop: "{{ site.pastas }}"
```

### 5.3 Índice do loop externo

```yaml
- name: Configurar cada site
  ansible.builtin.include_tasks: site.yml
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
    index_var: site_idx
```

Dentro de `site.yml`, `site_idx` está disponível (começa em 0), útil para numerar portas ou nomes:

```yaml
- name: Definir a porta do site
  ansible.builtin.debug:
    msg: "{{ site.nome }} usa a porta {{ 8080 + site_idx }}"
```

Use **nomes diferentes** para os índices de cada nível (`site_idx`, `pasta_idx`), para não sobrescrever.

### 5.4 Escolhendo o arquivo por item

O nome do arquivo pode ser dinâmico, o que permite tarefas diferentes para cada tipo de item:

```yaml
vars:
  servicos:
    - { nome: loja,  tipo: web }
    - { nome: dados, tipo: banco }

tasks:
  - name: Configurar cada serviço
    ansible.builtin.include_tasks: "tipo_{{ servico.tipo }}.yml"
    loop: "{{ servicos }}"
    loop_control:
      loop_var: servico
```

O Ansible incluirá `tipo_web.yml` para o primeiro e `tipo_banco.yml` para o segundo.

---

## 6. Condições no loop externo

O `when` na task `include_tasks` é avaliado **por item** do loop externo:

```yaml
- name: Configurar apenas os sites ativos
  ansible.builtin.include_tasks: site.yml
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
  when: site.ativo | default(true)
```

Sites com `ativo: false` não têm seu arquivo carregado.

Atenção: no `include_tasks` (dinâmico), o `when` vale **apenas para a task de include**. Se você precisa que a mesma condição valha dentro do arquivo, use `apply` (seção 9) ou repita a condição nas tasks internas.

---

## 7. Três níveis de loops

Cada nível adicional exige **um novo `include_tasks`** e **um novo `loop_var`**.

### 7.1 Estrutura de arquivos

```
ansible/
├── hosts
├── clientes.yml          # playbook (nível 1)
├── tasks/
│   ├── cliente.yml       # nível 2
│   └── projeto.yml       # nível 3
```

### 7.2 Os dados

```yaml
clientes:
  - nome: acme
    projetos:
      - { nome: portal, ambientes: [dev, prod] }
      - { nome: api,    ambientes: [dev, homolog, prod] }
  - nome: globex
    projetos:
      - { nome: site,   ambientes: [prod] }
```

### 7.3 Nível 1: `clientes.yml`

```yaml
---
- name: Estrutura de clientes
  hosts: all
  become: true

  vars:
    clientes:
      - nome: acme
        projetos:
          - { nome: portal, ambientes: [dev, prod] }
          - { nome: api,    ambientes: [dev, homolog, prod] }
      - nome: globex
        projetos:
          - { nome: site, ambientes: [prod] }

  tasks:
    - name: Processar cada cliente
      ansible.builtin.include_tasks: tasks/cliente.yml
      loop: "{{ clientes }}"
      loop_control:
        loop_var: cliente
        label: "{{ cliente.nome }}"
```

### 7.4 Nível 2: `tasks/cliente.yml`

```yaml
---
- name: Criar a pasta do cliente {{ cliente.nome }}
  ansible.builtin.file:
    path: "/srv/{{ cliente.nome }}"
    state: directory
    mode: "0755"

- name: Processar cada projeto de {{ cliente.nome }}
  ansible.builtin.include_tasks: tasks/projeto.yml
  loop: "{{ cliente.projetos }}"
  loop_control:
    loop_var: projeto
    label: "{{ cliente.nome }}/{{ projeto.nome }}"
```

### 7.5 Nível 3: `tasks/projeto.yml`

```yaml
---
- name: Criar a pasta do projeto {{ projeto.nome }}
  ansible.builtin.file:
    path: "/srv/{{ cliente.nome }}/{{ projeto.nome }}"
    state: directory
    mode: "0755"

- name: Criar os ambientes de {{ cliente.nome }}/{{ projeto.nome }}
  ansible.builtin.file:
    path: "/srv/{{ cliente.nome }}/{{ projeto.nome }}/{{ ambiente }}"
    state: directory
    mode: "0750"
  loop: "{{ projeto.ambientes }}"
  loop_control:
    loop_var: ambiente
    label: "{{ cliente.nome }}/{{ projeto.nome }}/{{ ambiente }}"
```

### 7.6 Como as variáveis se acumulam

| Onde | Variáveis disponíveis |
|---|---|
| `clientes.yml` (nível 1) | `cliente` |
| `tasks/cliente.yml` (nível 2) | `cliente`, `projeto` |
| `tasks/projeto.yml` (nível 3) | `cliente`, `projeto`, `ambiente` |

As variáveis dos níveis anteriores continuam visíveis nos níveis seguintes.

Resultado: `/srv/acme/portal/{dev,prod}`, `/srv/acme/api/{dev,homolog,prod}` e `/srv/globex/site/prod`.

> Mais de três níveis costumam indicar que a **estrutura de dados** precisa ser repensada (seção 8).

---

## 8. Alternativas ao `include_tasks`

Nem todo loop interno precisa de um arquivo separado. Para casos simples, com **uma única task** repetida, o loop pode ser "achatado" com filtros.

### 8.1 `subelements` (lista dentro de lista)

```yaml
- name: Criar as subpastas de cada site
  ansible.builtin.file:
    path: "/var/www/{{ item.0.nome }}/{{ item.1 }}"
    state: directory
    mode: "0755"
  loop: "{{ sites | subelements('pastas') }}"
  loop_control:
    label: "{{ item.0.nome }}/{{ item.1 }}"
```

Faz o mesmo que o exemplo da seção 3, em **uma única task**, sem arquivo extra. Aqui `item.0` é o site e `item.1` é a pasta.

### 8.2 `product` (combinações)

```yaml
- name: Criar ambiente/serviço
  ansible.builtin.file:
    path: "/srv/{{ item.0 }}/{{ item.1 }}"
    state: directory
  loop: "{{ ['dev', 'prod'] | product(['web', 'db']) | list }}"
```

### 8.3 Lista "plana" montada com Jinja

Para estruturas mais complexas, monte antes uma lista simples com `set_fact`:

```yaml
- name: Montar a lista de caminhos
  ansible.builtin.set_fact:
    caminhos: >-
      {{ caminhos | default([]) + [site.nome ~ '/' ~ pasta] }}
  loop: "{{ sites | subelements('pastas') }}"
```

(O padrão com acumulador está detalhado na seção 10.)

### 8.4 Quando escolher cada um

| Situação | Escolha |
|---|---|
| Uma única task repetida para os pares (externo, interno) | `subelements` ou `product` |
| **Várias tasks** por item do loop externo | `include_tasks` + `loop_var` |
| Condições, blocos ou `rescue` por item | `include_tasks` |
| Três ou mais níveis com lógica própria | `include_tasks` em cadeia |
| Arquivos de tasks diferentes por item | `include_tasks` com nome dinâmico |
| Máxima simplicidade e menor sobrecarga | `subelements`, `product` |
| Reaproveitar a lógica em vários playbooks | `include_tasks` ou role |

---

## 9. `include_tasks` × `import_tasks`, tags e `apply`

### 9.1 Só o `include_tasks` aceita loop

| Diretiva | Aceita `loop`? | Natureza |
|---|---|---|
| `include_tasks` | **Sim** | Dinâmica: processada durante a execução |
| `import_tasks` | **Não** | Estática: processada ao carregar o playbook |

Para loop interno, use sempre `include_tasks`.

### 9.2 Tags e outras diretivas: `apply`

No `include_tasks` (dinâmico), as tags e diretivas aplicadas à task de include **não** são herdadas pelas tasks do arquivo. Use `apply` para propagá-las:

```yaml
- name: Configurar cada site
  ansible.builtin.include_tasks:
    file: site.yml
    apply:
      tags: sites
      become: true
  tags: sites
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
```

- A tag **fora** do `apply` garante que o próprio include seja executado quando você usar `--tags sites`.
- A tag **dentro** do `apply` é a que vai para as tasks incluídas.
- `apply` também aceita `when`, `become`, `environment` e outras diretivas.

### 9.3 Limitações a conhecer

- `ansible-playbook --list-tasks` e `--list-tags` **não** mostram as tasks dentro de includes dinâmicos, pois elas só são carregadas na execução.
- `--start-at-task` não encontra tasks dentro de includes dinâmicos.
- Um erro de sintaxe no arquivo incluído só aparece quando ele é carregado, e não na verificação inicial (`--syntax-check`).

---

## 10. Resultados (`register`) em loops internos

### 10.1 O `register` é sobrescrito a cada repetição externa

Um `register` dentro do arquivo incluído guarda apenas o resultado da **última** repetição do loop externo. Quando a task de include termina, o valor que sobra é o da última volta.

```yaml
# site.yml
- name: Verificar as pastas
  ansible.builtin.stat:
    path: "/var/www/{{ site.nome }}/{{ item }}"
  loop: "{{ site.pastas }}"
  register: verificacao      # sobrescrito a cada site
```

### 10.2 Acumulando resultados com `set_fact`

Para guardar o resultado de todas as repetições, acumule em uma lista:

```yaml
# site.yml
- name: Verificar as pastas
  ansible.builtin.stat:
    path: "/var/www/{{ site.nome }}/{{ item }}"
  loop: "{{ site.pastas }}"
  register: verificacao

- name: Acumular as pastas ausentes
  ansible.builtin.set_fact:
    pastas_ausentes: >-
      {{ pastas_ausentes | default([])
         + [site.nome ~ '/' ~ item.item] }}
  loop: "{{ verificacao.results }}"
  loop_control:
    label: "{{ site.nome }}/{{ item.item }}"
  when: not item.stat.exists
```

No playbook principal, depois do `include_tasks`:

```yaml
- name: Mostrar o que está faltando
  ansible.builtin.debug:
    msg: "{{ pastas_ausentes | default([]) }}"
```

O padrão `variavel | default([]) + [novo]` cria a lista na primeira vez e a estende nas seguintes.

### 10.3 O `register` na própria task de include

Registrar o resultado da task `include_tasks` **não** devolve o resultado das tasks internas; apenas informa que a inclusão aconteceu. Não use esse recurso para capturar resultados.

---

## 11. `include_role` com loop

O mesmo raciocínio vale para roles:

```yaml
- name: Aplicar a role web para cada site
  ansible.builtin.include_role:
    name: web
  vars:
    web_site: "{{ site }}"
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
    label: "{{ site.nome }}"
```

Dentro da role, use o nome `web_site` (o parâmetro passado), e não `site`: isso mantém a role independente de quem a chama. Se a role tiver loops internos próprios, defina neles um `loop_var` com prefixo da role (`web_pasta`, `web_vhost`).

---

## 12. Exemplo completo

Provisionamento de aplicações em Debian e Red Hat, com loop externo por aplicação e loops internos por diretórios e por parâmetros, usando `include_tasks`, `loop_var`, `apply`, acumulador de resultados e relatório.

### 12.1 Playbook: `apps.yml`

```yaml
---
- name: Provisionar aplicações
  hosts: all
  gather_facts: true
  become: true

  vars:
    apps:
      - nome: loja
        usuario: app_loja
        ativa: true
        diretorios:
          - { caminho: /opt/loja,      modo: "0755" }
          - { caminho: /opt/loja/logs, modo: "0750" }
          - { caminho: /opt/loja/tmp,  modo: "1777" }
        parametros:
          porta: 8080
          modo: producao
      - nome: blog
        usuario: app_blog
        ativa: true
        diretorios:
          - { caminho: /opt/blog,      modo: "0755" }
          - { caminho: /opt/blog/logs, modo: "0750" }
        parametros:
          porta: 8081
          modo: homologacao
      - nome: legado
        usuario: app_legado
        ativa: false
        diretorios: []
        parametros: {}

  tasks:
    - name: Provisionar cada aplicação ativa
      ansible.builtin.include_tasks:
        file: tasks/app.yml
        apply:
          tags: apps
      loop: "{{ apps }}"
      loop_control:
        loop_var: app
        index_var: app_idx
        label: "{{ app.nome }}"
      when: app.ativa | default(true)
      tags: apps

    - name: Relatório dos diretórios criados
      ansible.builtin.debug:
        msg: "{{ diretorios_criados | default([]) }}"
      run_once: true
      tags: apps
```

### 12.2 Arquivo incluído: `tasks/app.yml`

```yaml
---
- name: Criar o usuário de {{ app.nome }}
  ansible.builtin.user:
    name: "{{ app.usuario }}"
    shell: /usr/sbin/nologin
    system: true
    state: present

- name: Criar os diretórios de {{ app.nome }}
  ansible.builtin.file:
    path: "{{ pasta.caminho }}"
    state: directory
    owner: "{{ app.usuario }}"
    mode: "{{ pasta.modo }}"
  loop: "{{ app.diretorios }}"
  loop_control:
    loop_var: pasta
    label: "{{ app.nome }}: {{ pasta.caminho }}"
  register: criacao

- name: Acumular os diretórios criados ou alterados
  ansible.builtin.set_fact:
    diretorios_criados: "{{ diretorios_criados | default([]) + [res.path] }}"
  loop: "{{ criacao.results }}"
  loop_control:
    loop_var: res
    label: "{{ res.path | default(res.pasta.caminho) }}"
  when: res is changed

- name: Gravar os parâmetros de {{ app.nome }}
  ansible.builtin.lineinfile:
    path: "/opt/{{ app.nome }}/app.conf"
    regexp: "^{{ param.key }}="
    line: "{{ param.key }}={{ param.value }}"
    create: true
    owner: "{{ app.usuario }}"
    mode: "0640"
  loop: "{{ app.parametros | dict2items }}"
  loop_control:
    loop_var: param
    label: "{{ app.nome }}: {{ param.key }}"

- name: Informar a porta da aplicação
  ansible.builtin.debug:
    msg: "{{ app.nome }} (posição {{ app_idx + 1 }}) usa a porta {{ app.parametros.porta | default('n/d') }}"
```

### 12.3 Observações sobre o exemplo

- O loop externo usa `loop_var: app` e `index_var: app_idx`; os loops internos usam `pasta`, `res` e `param`. Nenhum usa `item`, e nenhuma colisão é possível.
- A condição `when: app.ativa` evita carregar o arquivo para a aplicação `legado`.
- O `apply: tags: apps` faz com que as tasks do arquivo respondam à tag `apps`; a tag no próprio `include_tasks` garante que ele seja executado com `--tags apps`.
- Em `res`, o resultado de `file` traz o campo `path`; o `default(res.pasta.caminho)` no `label` é só uma proteção para o caso em que ele esteja ausente. Como o loop interno de `file` usa `loop_var: pasta`, a chave original do item nos resultados é `pasta`.
- O acumulador `diretorios_criados` junta tudo que foi alterado, de todas as aplicações, e é exibido ao final.

### 12.4 Execuções

```bash
# Tudo
ansible-playbook -i hosts apps.yml -K

# Só as aplicações, em dois hosts
ansible-playbook -i hosts apps.yml -K --tags apps --limit deb00,deb02

# Simulação
ansible-playbook -i hosts apps.yml -K --check

# Forçando só uma aplicação, ajustando a lista
ansible-playbook -i hosts apps.yml -K -e '{"apps": [{"nome": "loja", "usuario": "app_loja", "ativa": true, "diretorios": [], "parametros": {"porta": 9090}}]}'
```

---

## 13. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `[WARNING]: The loop variable 'item' is already in use` | Os dois níveis usam `item` | `loop_var` no externo (e, de preferência, no interno) |
| Valores trocados ou "misturados" entre os níveis | Colisão de `item` | Nomes distintos em cada nível |
| `'site' is undefined` no arquivo incluído | `loop_var` com outro nome, ou arquivo chamado sem loop | Conferir o nome em `loop_var` e como o arquivo é incluído |
| `'loop' is not a valid attribute` em `import_tasks` | Imports são estáticos e não aceitam loop | Usar `include_tasks` |
| Tags não executam as tasks do arquivo | Include dinâmico não propaga tags | `apply: tags:` e a tag também no include |
| `--list-tasks` não mostra as tasks internas | Includes dinâmicos só carregam na execução | Comportamento esperado; use `-v` ou execute com `--check` |
| `register` só tem a última volta | Sobrescrito a cada repetição externa | Acumular com `set_fact` |
| Resultado do `include_tasks` sem dados das tasks internas | O resultado do include não traz o das tasks | Registrar dentro do arquivo |
| Caminho do arquivo incluído não encontrado | Caminho relativo ao arquivo que inclui | Ajustar o caminho (por exemplo, `tasks/arquivo.yml`) |
| Erro só aparece no meio da execução | Sintaxe do arquivo só é verificada ao ser carregado | Testar o arquivo com o loop em um ambiente de teste |
| Execução lenta com muitas repetições | Cada volta recarrega o arquivo | Usar `subelements` ou `product`, ou reestruturar os dados |
| `item.item` não existe nos resultados | `loop_var` personalizado muda o nome da chave | Usar `res.<loop_var>` (por exemplo, `res.pasta`) |
| Índice do externo sobrescrito | Dois níveis com o mesmo `index_var` | Nomes diferentes (`app_idx`, `pasta_idx`) |

---

## 14. Boas práticas

1. **Sempre defina `loop_var` no loop externo** que usa `include_tasks`, e prefira definir também no interno.
2. **Use nomes descritivos:** `site`, `pasta`, `cliente`, `projeto`, e não `item`, `item2`.
3. **Use prefixos nas roles** (`web_site`) para evitar conflito com quem as chama.
4. **Prefira `subelements` e `product`** quando uma única task basta; guarde o `include_tasks` para casos com várias tasks, condições ou blocos.
5. **Mantenha poucos níveis** (dois, no máximo três). Mais que isso sugere reorganizar os dados.
6. **Use `label`** em todos os níveis, mostrando o caminho completo (`cliente/projeto/ambiente`).
7. **Use `apply`** para propagar tags, `become` e outras diretivas às tasks incluídas, e coloque a tag também no include.
8. **Acumule resultados com `set_fact`** quando precisar dos dados de todas as repetições.
9. **Escolha o arquivo dinamicamente** (`"tipo_{{ servico.tipo }}.yml"`) para tratar tipos diferentes.
10. **Documente a estrutura de dados esperada** no topo do arquivo incluído, listando as variáveis que ele usa (`site.nome`, `site.pastas`).
11. **Valide os dados** com `assert` no início do arquivo incluído se ele depender de campos específicos.
12. **Teste com listas pequenas** e `--check` antes de rodar com a lista completa.

---

## Resumo

| Necessidade | Solução |
|---|---|
| Loop dentro de loop com várias tasks | `include_tasks` + `loop` no externo, `loop` no arquivo incluído |
| Evitar colisão de `item` | `loop_control: loop_var: nome` |
| Nomear também o loop interno | `loop_var` nas duas tasks |
| Passar dados extras ao arquivo | `vars:` na task de include |
| Índice do loop externo no arquivo | `index_var` no externo |
| Arquivo diferente por item | `include_tasks: "tipo_{{ x.tipo }}.yml"` |
| Condição por item externo | `when` na task de include |
| Propagar tags às tasks incluídas | `apply: tags:` (e a tag também no include) |
| Três níveis | Um `include_tasks` + `loop_var` por nível |
| Uma única task para dois níveis | `subelements` ou `product` |
| Guardar resultados de todas as voltas | `set_fact` com acumulador `default([]) + [...]` |
| Loop interno com `import_tasks` | Não funciona; use `include_tasks` |
| Role para cada item | `include_role` + `loop` + `loop_var` |
| Nomes das chaves nos `results` | Seguem o `loop_var` (`res.pasta`, `res.site`...) |
