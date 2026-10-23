# Capítulo: `with_sequence`

## 1. O que é o `with_sequence`

O `with_sequence` gera uma **sequência numérica** e repete a task para cada número. É útil quando você precisa de itens numerados sem ter uma lista pronta: `web01` a `web05`, portas de 8080 a 8085, arquivos `dados_1` a `dados_10`, ou simplesmente repetir algo N vezes.

```yaml
- name: Contar de 1 a 5
  ansible.builtin.debug:
    msg: "Número {{ item }}"
  with_sequence: start=1 end=5
```

Saída: `Número 1`, `Número 2`, `Número 3`, `Número 4`, `Número 5`.

Ele faz parte da família `with_*` (ver capítulo de `with_items`) e, por baixo, usa o lookup `ansible.builtin.sequence`. Em código novo, a recomendação é usar `loop` com `range` (seção 9), mas o `with_sequence` continua funcionando e aparece em muitos playbooks existentes.

---

## 2. Sintaxe e parâmetros

Os parâmetros são escritos no formato `chave=valor`, separados por espaço, em uma única linha:

```yaml
with_sequence: start=1 end=10 stride=3 format=item%02d
```

| Parâmetro | Padrão | Descrição |
|---|---|---|
| `start` | `1` | Primeiro número da sequência |
| `end` | (nenhum) | Último número da sequência (**incluído**) |
| `count` | (nenhum) | Quantidade de números a gerar (use no lugar de `end`) |
| `stride` | `1` | Passo entre um número e o próximo (pode ser negativo) |
| `format` | `%d` | Formato do texto gerado, no estilo `printf` |

Regras importantes:

- É obrigatório informar **`end` ou `count`** (um dos dois).
- **Não** use `end` e `count` juntos.
- O `end` é **inclusivo**: `start=1 end=5` gera 1, 2, 3, 4, 5. Isso é diferente do `range` do `loop`, em que o limite é excluído.
- Os valores aceitam variáveis: `end={{ total }}`.
- O `start` padrão é **1** (e não 0).

---

## 3. Exemplos básicos

### 3.1 Com `end`

```yaml
- name: De 1 a 5
  ansible.builtin.debug:
    msg: "{{ item }}"
  with_sequence: start=1 end=5
```

Gera: 1, 2, 3, 4, 5.

### 3.2 Com `count`

Quando você sabe **quantos** itens quer, e não o último valor:

```yaml
- name: Cinco repetições
  ansible.builtin.debug:
    msg: "Repetição {{ item }}"
  with_sequence: count=5
```

Gera: 1, 2, 3, 4, 5 (o `start` padrão é 1).

Com `start`:

```yaml
  with_sequence: start=10 count=3
```

Gera: 10, 11, 12.

### 3.3 Começando do zero

```yaml
  with_sequence: start=0 end=4
```

Gera: 0, 1, 2, 3, 4.

### 3.4 Com passo (`stride`)

```yaml
- name: Números ímpares até 10
  ansible.builtin.debug:
    msg: "{{ item }}"
  with_sequence: start=1 end=10 stride=2
```

Gera: 1, 3, 5, 7, 9.

```yaml
  with_sequence: start=0 end=100 stride=25
```

Gera: 0, 25, 50, 75, 100.

### 3.5 Contagem regressiva (`stride` negativo)

Para contar de trás para frente, o `stride` precisa ser **negativo**:

```yaml
- name: Contagem regressiva
  ansible.builtin.debug:
    msg: "{{ item }}"
  with_sequence: start=5 end=1 stride=-1
```

Gera: 5, 4, 3, 2, 1.

Se `start` for maior que `end` com `stride` positivo, o Ansible gera um erro (ver seção 10).

### 3.6 Com limite vindo de uma variável

```yaml
vars:
  total_servidores: 4

tasks:
  - name: Um item para cada servidor
    ansible.builtin.debug:
      msg: "Servidor {{ item }} de {{ total_servidores }}"
    with_sequence: start=1 end={{ total_servidores }}
```

Também funciona com `count={{ total_servidores }}`, e com valores vindos de `-e`:

```bash
ansible-playbook -i hosts test.yml -e "total_servidores=10"
```

---

## 4. O `format`: números formatados

O parâmetro `format` define como cada número vira texto, com a sintaxe `printf` (a mesma de `%d`, `%02d`, `%x`).

| Formato | Exemplo (item = 7) | Resultado |
|---|---|---|
| `%d` (padrão) | `7` | `7` |
| `%02d` | número com 2 dígitos, zeros à esquerda | `07` |
| `%03d` | 3 dígitos | `007` |
| `web%02d` | texto + número | `web07` |
| `srv-%03d.local` | texto + número + texto | `srv-007.local` |
| `%x` | hexadecimal minúsculo | `7` |
| `%02x` | hexadecimal com 2 dígitos | `07` |
| `%X` | hexadecimal maiúsculo | `7` |

### 4.1 Nomes numerados

```yaml
- name: Criar os diretórios web01 a web05
  ansible.builtin.file:
    path: "/srv/{{ item }}"
    state: directory
    mode: "0755"
  with_sequence: start=1 end=5 format=web%02d
```

Cria `/srv/web01`, `/srv/web02`, `/srv/web03`, `/srv/web04` e `/srv/web05`.

### 4.2 Usuários de teste

```yaml
- name: Criar os usuários teste01 a teste03
  ansible.builtin.user:
    name: "{{ item }}"
    shell: /bin/bash
    state: present
  with_sequence: start=1 end=3 format=teste%02d
```

### 4.3 Hexadecimal

```yaml
- ansible.builtin.debug:
    msg: "{{ item }}"
  with_sequence: start=10 end=16 format=0x%02x
```

Gera: `0x0a`, `0x0b`, `0x0c`, `0x0d`, `0x0e`, `0x0f`, `0x10`.

Observação: o `format` precisa conter **um** especificador de número (`%d`, `%02d`, `%x`...). Um texto sem `%` causa erro.

---

## 5. Atenção: os itens são **texto**

Mesmo quando parecem números, os itens gerados são **strings** (já formatadas). Isso significa que comparações e contas diretas dão resultado inesperado:

```yaml
# ERRADO: "3" (texto) não é igual a 3 (número)
when: item == 3

# ERRADO: concatena em vez de somar
msg: "{{ item + 1 }}"       # "3" + 1 gera erro ou comportamento inesperado
```

Converta com `| int`:

```yaml
when: item | int == 3
msg: "{{ item | int + 1 }}"
msg: "Porta: {{ 8080 + item | int }}"
```

Com `format=%02d`, o texto `"07"` também é convertido corretamente por `| int`.

Se você precisa de **números de verdade** e de **texto formatado**, o caminho moderno é usar `range` e formatar na task:

```yaml
loop: "{{ range(1, 6) | list }}"
# dentro da task:
name: "{{ 'web%02d' | format(item) }}"
```

---

## 6. Usos práticos

### 6.1 Entradas sequenciais no `/etc/hosts`

```yaml
- name: Registrar os servidores web01 a web03
  ansible.builtin.lineinfile:
    path: /etc/hosts
    regexp: "\\sweb{{ '%02d' | format(item | int) }}$"
    line: "10.0.0.{{ 10 + (item | int) }} web{{ '%02d' | format(item | int) }}"
  with_sequence: start=1 end=3
```

Resultado no arquivo:

```
10.0.0.11 web01
10.0.0.12 web02
10.0.0.13 web03
```

### 6.2 Portas consecutivas

```yaml
- name: Gravar as instâncias da aplicação
  ansible.builtin.lineinfile:
    path: /etc/instancias.conf
    regexp: "^instancia{{ item }}="
    line: "instancia{{ item }}=127.0.0.1:{{ 8079 + (item | int) }}"
    create: true
    mode: "0644"
  with_sequence: count=4
```

Gera `instancia1=127.0.0.1:8080` até `instancia4=127.0.0.1:8083`.

### 6.3 Arquivos de teste numerados

```yaml
- name: Criar arquivos de teste
  ansible.builtin.copy:
    dest: "/tmp/dados_{{ item }}.txt"
    content: "Arquivo número {{ item }}\n"
    mode: "0644"
  with_sequence: start=1 end=10 format=%03d
```

Cria `/tmp/dados_001.txt` até `/tmp/dados_010.txt`.

### 6.4 Faixa de portas de um serviço

```yaml
- name: Mostrar as portas do intervalo
  ansible.builtin.debug:
    msg: "Porta {{ item }}"
  with_sequence: start=5000 end=5100 stride=25
```

Gera: 5000, 5025, 5050, 5075, 5100.

### 6.5 Condição por item

Executar apenas para números pares:

```yaml
- name: Somente números pares
  ansible.builtin.debug:
    msg: "{{ item }} é par"
  with_sequence: start=1 end=10
  when: item | int is divisibleby 2
```

Se possível, prefira gerar a sequência já filtrada (`stride=2 start=2`) em vez de descartar itens com `when`, para evitar linhas `skipping` na saída.

### 6.6 Repetir uma task N vezes

```yaml
- name: Gerar 3 sorteios
  ansible.builtin.debug:
    msg: "Sorteio {{ item }}: {{ 100 | random }}"
  with_sequence: count=3
```

Útil para testes, geração de dados e simulações.

### 6.7 Com pausa entre as repetições

```yaml
- name: Reiniciar o serviço 3 vezes, com intervalo
  ansible.builtin.service:
    name: cron
    state: restarted
  with_sequence: count=3
  loop_control:
    pause: 5
```

### 6.8 Saída mais limpa e progresso

```yaml
- name: Criar os usuários de teste
  ansible.builtin.user:
    name: "{{ item }}"
    state: present
  with_sequence: start=1 end=5 format=teste%02d
  loop_control:
    label: "{{ item }}"
    extended: true
```

O `loop_control` funciona normalmente com `with_sequence` (ver capítulo de `loop_control`).

### 6.9 Combinações com outras listas (loop interno)

Para cruzar uma sequência com outra lista, use o `product` com o `loop` (seção 9) ou um `include_tasks` com `loop_var` (capítulo de loops internos):

```yaml
- name: Criar numeradas por tipo
  ansible.builtin.file:
    path: "/srv/{{ item.1 }}{{ '%02d' | format(item.0) }}"
    state: directory
  loop: "{{ range(1, 4) | product(['web', 'db']) | list }}"
```

Cria `/srv/web01`, `/srv/db01`, `/srv/web02`, `/srv/db02`, `/srv/web03`, `/srv/db03`.

---

## 7. Quando usar `with_sequence` ou `until`

O `with_sequence` repete uma task um número **fixo** de vezes. Para repetir **até uma condição ser satisfeita** (por exemplo, esperar um serviço subir), use `until`:

```yaml
- name: Aguardar o serviço responder
  ansible.builtin.uri:
    url: http://localhost:8080/health
  register: saude
  until: saude.status == 200
  retries: 10
  delay: 5
```

| Necessidade | Use |
|---|---|
| Número fixo de repetições, com índice ou nome numerado | `with_sequence` (ou `loop` + `range`) |
| Repetir até uma condição | `until` + `retries` + `delay` |
| Esperar um arquivo ou uma porta | `wait_for` |

---

## 8. Resultados com `register`

A estrutura do resultado é igual à de qualquer loop: lista em `.results`, com o valor original em `item.item`:

```yaml
- name: Verificar os arquivos numerados
  ansible.builtin.stat:
    path: "/tmp/dados_{{ item }}.txt"
    get_checksum: false
  with_sequence: start=1 end=5 format=%03d
  register: arquivos

- name: Mostrar quais existem
  ansible.builtin.debug:
    msg: "dados_{{ item.item }}.txt: {{ item.stat.exists }}"
  with_items: "{{ arquivos.results }}"
  loop_control:
    label: "dados_{{ item.item }}.txt"
```

Os valores em `item.item` seguem o `format` (por exemplo, `"001"`).

---

## 9. Migrando para `loop`

### 9.1 Tabela de equivalência

A diferença principal: o `end` do `with_sequence` é **inclusivo**, e o limite do `range` é **exclusivo**. Em sequências crescentes, some 1 ao `end`.

| `with_sequence` | `loop` equivalente |
|---|---|
| `start=1 end=5` | `loop: "{{ range(1, 6) \| list }}"` |
| `count=5` | `loop: "{{ range(1, 6) \| list }}"` |
| `start=0 end=4` | `loop: "{{ range(0, 5) \| list }}"` |
| `start=10 count=3` | `loop: "{{ range(10, 13) \| list }}"` |
| `start=1 end=10 stride=2` | `loop: "{{ range(1, 11, 2) \| list }}"` |
| `start=5 end=1 stride=-1` | `loop: "{{ range(5, 0, -1) \| list }}"` |
| `start=1 end={{ n }}` | `loop: "{{ range(1, n + 1) \| list }}"` |
| `start=1 end=5 format=web%02d` | `loop: "{{ range(1, 6) \| list }}"` + `'web%02d' \| format(item)` na task |

Para manter exatamente o comportamento (itens em texto, já formatados), também existe:

```yaml
loop: "{{ query('ansible.builtin.sequence', 'start=1 end=5 format=web%02d') }}"
```

O `query` devolve uma lista, ao contrário do `lookup` sem `wantlist=True`, que devolve um texto único separado por vírgulas.

### 9.2 Exemplo antes e depois

Antes:

```yaml
- name: Criar os diretórios web01 a web05
  ansible.builtin.file:
    path: "/srv/{{ item }}"
    state: directory
    mode: "0755"
  with_sequence: start=1 end=5 format=web%02d
```

Depois:

```yaml
- name: Criar os diretórios web01 a web05
  ansible.builtin.file:
    path: "/srv/{{ 'web%02d' | format(item) }}"
    state: directory
    mode: "0755"
  loop: "{{ range(1, 6) | list }}"
```

Na versão com `loop`, `item` é um **número inteiro**, e não texto. Por isso, `item | int` deixa de ser necessário, e comparações como `item == 3` passam a funcionar.

### 9.3 Roteiro de migração

1. Troque `with_sequence: ...` por `loop: "{{ range(...) | list }}"`, ajustando o limite final (`end + 1` em sequências crescentes, `end - 1` nas decrescentes).
2. Mova o `format` para o ponto onde o item é usado: `{{ 'web%02d' | format(item) }}`.
3. Remova os `| int` que existiam só por causa do texto, e revise comparações.
4. Se preferir manter o comportamento antigo, use `query('ansible.builtin.sequence', '...')`.
5. Compare o número de iterações antes e depois, com `--check`.

---

## 10. Exemplo completo

Playbook com `with_sequence` em vários cenários, funcionando em Debian e Red Hat:

```yaml
---
- name: Exemplos de with_sequence
  hosts: all
  gather_facts: true
  become: true

  vars:
    total_web: 3
    porta_base: 8080

  tasks:
    - name: Criar os diretórios web01 a web0N
      ansible.builtin.file:
        path: "/srv/{{ item }}"
        state: directory
        mode: "0755"
      with_sequence: start=1 end={{ total_web }} format=web%02d
      loop_control:
        label: "{{ item }}"
      tags: diretorios

    - name: Criar os usuários de teste
      ansible.builtin.user:
        name: "{{ item }}"
        shell: /bin/bash
        state: present
      with_sequence: count=3 format=teste%02d
      loop_control:
        label: "{{ item }}"
      tags: usuarios

    - name: Registrar as instâncias e suas portas
      ansible.builtin.lineinfile:
        path: /etc/instancias.conf
        regexp: "^web{{ '%02d' | format(item | int) }}="
        line: "web{{ '%02d' | format(item | int) }}=127.0.0.1:{{ porta_base + (item | int) - 1 }}"
        create: true
        mode: "0644"
      with_sequence: start=1 end={{ total_web }}
      tags: instancias

    - name: Contagem regressiva do reinício
      ansible.builtin.debug:
        msg: "Reiniciando em {{ item }}..."
      with_sequence: start=3 end=1 stride=-1
      run_once: true
      tags: contagem

    - name: Mostrar apenas os números pares até 10
      ansible.builtin.debug:
        msg: "{{ item }}"
      with_sequence: start=2 end=10 stride=2
      run_once: true
      tags: pares
```

Versão equivalente moderna das duas primeiras tasks:

```yaml
    - name: Criar os diretórios web01 a web0N
      ansible.builtin.file:
        path: "/srv/{{ 'web%02d' | format(item) }}"
        state: directory
        mode: "0755"
      loop: "{{ range(1, total_web + 1) | list }}"

    - name: Criar os usuários de teste
      ansible.builtin.user:
        name: "{{ 'teste%02d' | format(item) }}"
        shell: /bin/bash
        state: present
      loop: "{{ range(1, 4) | list }}"
```

Execuções:

```bash
ansible-playbook -i hosts seq.yml -K
ansible-playbook -i hosts seq.yml -K --tags diretorios -e "total_web=5"
ansible-playbook -i hosts seq.yml -K --tags contagem --limit deb00
```

---

## 11. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Erro dizendo que é preciso informar `count` ou `end` | Faltou um dos dois | Informar `end=` ou `count=` |
| Erro por usar `count` e `end` juntos | Os dois são mutuamente exclusivos | Usar apenas um |
| Erro sobre contar de trás para frente | `start` maior que `end` com `stride` positivo | `stride` negativo (`stride=-1`) |
| Erro de formato (`bad formatting string` ou semelhante) | `format` sem especificador (`%d`, `%02d`...) | Incluir o `%` com o tipo numérico |
| `item == 3` nunca é verdadeiro | `item` é texto (`"3"`) | `item \| int == 3` |
| `item + 1` falha ou concatena | `item` é texto | `item \| int + 1` |
| Esperava 1 a 4 e vieram 1 a 5 | O `end` é inclusivo | Reduzir o `end` ou usar `count` |
| Ao migrar para `range`, sobra ou falta um item | O limite do `range` é exclusivo | `end + 1` (crescente) ou `end - 1` (decrescente) |
| Sequência começa em 1 e eu queria 0 | O `start` padrão é 1 | `start=0` |
| Variável não é expandida no `end` | Faltaram as chaves | `end={{ variavel }}` |
| Zeros à esquerda somem em contas | Conversão para número | Formatar apenas na saída (`'%02d' \| format(...)`) |
| `lookup('sequence', ...)` devolve um texto único | `lookup` sem `wantlist=True` | Usar `query('ansible.builtin.sequence', ...)` |
| Muitas linhas `skipping` | `when` descartando itens | Gerar a sequência já filtrada (`stride`) |
| Espaços no `with_sequence` quebram os parâmetros | Valores com espaços | Evitar espaços dentro dos valores |

---

## 12. Boas práticas

1. **Em código novo, use `loop` com `range`**; mantenha o `with_sequence` para entender e manter playbooks antigos.
2. **Lembre-se de que o `end` é inclusivo** no `with_sequence` e exclusivo no `range`.
3. **Converta os itens com `| int`** antes de comparar ou fazer contas.
4. **Use `format`** para nomes numerados (`web%02d`), mas lembre-se de que o item vira texto formatado.
5. **Use `count`** quando o dado natural for "quantos", e `end` quando for "até onde".
6. **Use `stride`** em vez de `when` para pular números (pares, ímpares, múltiplos).
7. **Use `stride` negativo** para contagem regressiva.
8. **Mantenha o tamanho da sequência em variáveis** (`end={{ total }}`), para ajustar sem editar as tasks.
9. **Use `loop_control: label`** para manter a saída legível.
10. **Prefira `until` ou `wait_for`** quando a repetição depender de uma condição, e não de um número fixo.
11. **Combine com listas** usando `product` (ou `include_tasks` com `loop_var`) quando precisar de dois níveis.
12. **Compare as saídas** antes e depois de migrar para `loop`, verificando o número de itens.

---

## Resumo

| Necessidade | `with_sequence` | `loop` equivalente |
|---|---|---|
| De 1 a N | `start=1 end=N` | `range(1, N + 1) \| list` |
| N repetições | `count=N` | `range(1, N + 1) \| list` |
| Começar de outro valor | `start=10 end=15` | `range(10, 16) \| list` |
| Com passo | `start=1 end=10 stride=2` | `range(1, 11, 2) \| list` |
| Contagem regressiva | `start=5 end=1 stride=-1` | `range(5, 0, -1) \| list` |
| Nomes numerados | `format=web%02d` | `'web%02d' \| format(item)` |
| Limite variável | `end={{ n }}` | `range(1, n + 1) \| list` |
| Item é... | Texto | Número inteiro |
| Conta com o item | `item \| int + 1` | `item + 1` |
| Repetir até uma condição | (não serve) | `until` + `retries` + `delay` |
| Saída limpa | `loop_control: label` | `loop_control: label` |
