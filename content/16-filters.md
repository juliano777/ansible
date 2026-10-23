# Capítulo: Filtros no Ansible

## 1. O que são filtros

Filtros são pequenas funções que **transformam um valor** dentro de uma expressão Jinja2. Você já usou vários nos capítulos anteriores: `default`, `trim`, `int`, `bool`, `from_json`, `length`.

A sintaxe é o caractere `|` (pipe) depois do valor:

```yaml
msg: "{{ valor | filtro }}"
msg: "{{ valor | filtro(argumento1, argumento2) }}"
```

Filtros podem ser **encadeados**; o resultado de um é a entrada do próximo:

```yaml
msg: "{{ res.stdout | trim | upper | truncate(10) }}"
```

Eles funcionam em qualquer lugar onde o Jinja2 é avaliado: `msg`, parâmetros de módulos, `when`, `vars`, templates (`.j2`), `loop` etc.

### 1.1 Filtros × testes × funções

| Conceito | Sintaxe | Retorna | Exemplo |
|---|---|---|---|
| **Filtro** | `valor \| filtro` | Um valor transformado | `nome \| upper` |
| **Teste** | `valor is teste` | Verdadeiro ou falso | `nome is defined` |
| **Função / lookup** | `funcao()` | Um valor gerado | `lookup('env', 'HOME')` |

### 1.2 Testando filtros rapidamente

Sem precisar escrever um playbook:

```bash
ansible localhost -m ansible.builtin.debug -a 'msg={{ "ansible" | upper }}'
```

Para ver a documentação de um filtro (nas versões recentes do `ansible-core`):

```bash
ansible-doc -t filter -l
ansible-doc -t filter ansible.builtin.regex_replace
```

---

## 2. Valores padrão e obrigatórios

### 2.1 `default`

```yaml
msg: "Porta: {{ porta | default(80) }}"
```

Atenção ao comportamento: `default(x)` só vale quando a variável **não está definida**. Se ela existe mas é vazia (`""`), o padrão **não** é usado. Para tratar vazio e falso também, passe `true` como segundo argumento:

```yaml
msg: "{{ resposta | default('padrão', true) }}"
```

### 2.2 `mandatory`

Falha com erro claro quando a variável não existe:

```yaml
msg: "{{ pacote | mandatory }}"
msg: "{{ pacote | mandatory('Informe o pacote com -e pacote=nome') }}"
```

### 2.3 `omit`: omitir um parâmetro de módulo

Quando o padrão deve ser "não passar o parâmetro", use o valor especial `omit`:

```yaml
- name: Criar arquivo, com modo opcional
  ansible.builtin.file:
    path: /tmp/teste
    state: touch
    mode: "{{ modo_arquivo | default(omit) }}"
```

Se `modo_arquivo` não existir, o parâmetro `mode` simplesmente não é enviado ao módulo.

---

## 3. Filtros de texto

| Filtro | Efeito | Exemplo | Resultado |
|---|---|---|---|
| `upper` | Maiúsculas | `'abc' \| upper` | `ABC` |
| `lower` | Minúsculas | `'ABC' \| lower` | `abc` |
| `capitalize` | Primeira letra maiúscula | `'ansible' \| capitalize` | `Ansible` |
| `title` | Cada palavra capitalizada | `'meu host' \| title` | `Meu Host` |
| `trim` | Remove espaços e quebras nas pontas | `'  ok \n' \| trim` | `ok` |
| `replace` | Troca texto | `'a-b' \| replace('-', '_')` | `a_b` |
| `length` | Tamanho | `'abcd' \| length` | `4` |
| `truncate` | Corta o texto | `'abcdefghij' \| truncate(6)` | `abc...` |
| `split` | Divide em lista | `'a,b,c' \| split(',')` | `['a','b','c']` |
| `join` | Junta uma lista | `['a','b'] \| join('-')` | `a-b` |
| `indent` | Indenta linhas | `texto \| indent(4)` | (linhas com 4 espaços) |
| `format` | Formata como `printf` | `'%s-%02d' \| format('v', 5)` | `v-05` |
| `quote` | Escapa para uso seguro no shell | `arq \| quote` | `'meu arquivo'` |
| `urlencode` | Codifica para URL | `'a b' \| urlencode` | `a%20b` |
| `b64encode` | Codifica em Base64 | `'abc' \| b64encode` | `YWJj` |
| `b64decode` | Decodifica Base64 | `'YWJj' \| b64decode` | `abc` |

Exemplo: tirar o domínio de um FQDN, como o resultado de `hostname -f`:

```yaml
msg: "{{ res.stdout | trim | split('.') | first }}"
```

Usar `quote` em comandos `shell` evita problemas com espaços e caracteres especiais:

```yaml
- ansible.builtin.shell: "ls -l {{ caminho | quote }}"
```

---

## 4. Expressões regulares

| Filtro | Retorna |
|---|---|
| `regex_search` | A primeira parte do texto que casa com o padrão |
| `regex_findall` | **Lista** com todos os trechos que casam |
| `regex_replace` | O texto com a substituição aplicada |
| `regex_escape` | O texto com caracteres especiais escapados |

```yaml
vars:
  versao_txt: "nginx version: nginx/1.22.1"

tasks:
  - ansible.builtin.debug:
      msg:
        - "{{ versao_txt | regex_search('[0-9]+\\.[0-9]+\\.[0-9]+') }}"
        - "{{ 'a1b22c333' | regex_findall('[0-9]+') }}"
        - "{{ 'deb00.exemplo.com' | regex_replace('\\..*$', '') }}"
```

Resultados: `1.22.1`, `['1', '22', '333']` e `deb00`.

### 4.1 Grupos de captura

Em `regex_search`, os grupos são retornados como lista; em `regex_replace`, são referenciados por `\\1`, `\\2`:

```yaml
- ansible.builtin.debug:
    msg: "{{ 'versao-1.22.1' | regex_replace('^versao-(.*)$', '\\1') }}"
```

### 4.2 Cuidado com as barras invertidas

O YAML e o Jinja2 **ambos** interpretam `\`. Para evitar surpresas:

- escreva as barras **duplas** dentro do Jinja (`\\.`, `\\d`, `\\1`);
- prefira **aspas simples** no YAML quando a expressão tiver muitas barras, usando aspas duplas dentro do Jinja:

```yaml
msg: '{{ texto | regex_replace("(\\w+)-(\\d+)", "\\2-\\1") }}'
```

Se a substituição não sair como esperado, simplifique a expressão e teste com o comando ad-hoc da seção 1.2.

---

## 5. Filtros numéricos e booleanos

| Filtro | Efeito | Exemplo | Resultado |
|---|---|---|---|
| `int` | Converte para inteiro | `'42' \| int` | `42` |
| `int(0)` | Inteiro, com valor se falhar | `'abc' \| int(0)` | `0` |
| `float` | Converte para decimal | `'3.5' \| float` | `3.5` |
| `round` | Arredonda | `3.14159 \| round(2)` | `3.14` |
| `abs` | Valor absoluto | `-5 \| abs` | `5` |
| `min` / `max` | Menor / maior de uma lista | `[3,1,2] \| max` | `3` |
| `sum` | Soma | `[1,2,3] \| sum` | `6` |
| `bool` | Converte para booleano | `'yes' \| bool` | `true` |
| `human_readable` | Bytes em formato legível | `1048576 \| human_readable` | `1.00 MB` |
| `human_to_bytes` | Formato legível em bytes | `'2G' \| human_to_bytes` | `2147483648` |

Casos úteis:

```yaml
# Memória em GB, com 1 casa decimal
msg: "{{ (ansible_facts['memtotal_mb'] / 1024) | round(1) }} GB"

# Comparação numérica de uma saída de comando
when: uso_raiz.stdout | int > 80

# Texto para booleano
when: reiniciar | default('false') | bool
```

`bool` reconhece `true`, `yes`, `on`, `1` (em qualquer capitalização) como verdadeiros.

---

## 6. Filtros de listas

### 6.1 Básicos

| Filtro | Efeito | Exemplo | Resultado |
|---|---|---|---|
| `first` / `last` | Primeiro / último item | `[1,2,3] \| first` | `1` |
| `length` | Quantidade | `[1,2,3] \| length` | `3` |
| `sort` | Ordena | `[3,1,2] \| sort` | `[1,2,3]` |
| `reverse` | Inverte | `[1,2,3] \| reverse \| list` | `[3,2,1]` |
| `unique` | Remove duplicados | `[1,1,2] \| unique` | `[1,2]` |
| `flatten` | Achata listas aninhadas | `[1,[2,3]] \| flatten` | `[1,2,3]` |
| `random` | Item aleatório | `[1,2,3] \| random` | (um deles) |
| `shuffle` | Embaralha | `[1,2,3] \| shuffle` | (ordem aleatória) |
| `batch(n)` | Agrupa em blocos de n | `[1,2,3,4,5] \| batch(2) \| list` | `[[1,2],[3,4],[5]]` |
| `join` | Junta em texto | `['a','b'] \| join(', ')` | `a, b` |

### 6.2 Operações de conjunto

```yaml
vars:
  a: [1, 2, 3, 4]
  b: [3, 4, 5]

msg:
  - "{{ a | union(b) }}"                 # [1, 2, 3, 4, 5]
  - "{{ a | intersect(b) }}"             # [3, 4]
  - "{{ a | difference(b) }}"            # [1, 2]
  - "{{ a | symmetric_difference(b) }}"  # [1, 2, 5]
```

Útil para comparar listas de pacotes instalados e desejados:

```yaml
msg: "Faltam instalar: {{ pacotes_desejados | difference(pacotes_instalados) }}"
```

### 6.3 Combinando listas

```yaml
msg:
  - "{{ ['a','b'] | zip([1,2]) | list }}"       # [['a',1], ['b',2]]
  - "{{ ['a','b'] | product([1,2]) | list }}"   # todas as combinações
```

---

## 7. `select`, `reject`, `map`: filtrando e transformando listas

Estes filtros formam o conjunto mais poderoso para trabalhar com dados. **Retornam um gerador**, então termine quase sempre com `| list`.

### 7.1 `select` e `reject` (com testes)

```yaml
vars:
  numeros: [1, 2, 3, 4, 5, 6]
  nomes: [ana, bruno, alice, carla]

msg:
  - "{{ numeros | select('odd') | list }}"                 # [1, 3, 5]
  - "{{ numeros | reject('odd') | list }}"                 # [2, 4, 6]
  - "{{ nomes | select('match', '^a') | list }}"            # [ana, alice]
  - "{{ nomes | reject('search', 'l') | list }}"           # [ana, bruno]
```

### 7.2 `selectattr` e `rejectattr` (listas de dicionários)

```yaml
vars:
  usuarios:
    - { nome: ana,   grupo: dev, ativo: true }
    - { nome: bruno, grupo: ops, ativo: false }
    - { nome: carla, grupo: dev, ativo: true }

msg:
  - "{{ usuarios | selectattr('ativo') | list }}"
  - "{{ usuarios | selectattr('grupo', 'equalto', 'dev') | list }}"
  - "{{ usuarios | rejectattr('ativo') | map(attribute='nome') | list }}"
```

### 7.3 `map`: extrair ou transformar

```yaml
msg:
  - "{{ usuarios | map(attribute='nome') | list }}"          # [ana, bruno, carla]
  - "{{ ['a','b'] | map('upper') | list }}"                   # [A, B]
  - "{{ ['v1','v2'] | map('regex_replace','^v','') | list }}" # [1, 2]
```

### 7.4 Combinação típica

"Nomes dos usuários ativos do grupo dev, separados por vírgula":

```yaml
msg: >-
  {{ usuarios
     | selectattr('ativo')
     | selectattr('grupo', 'equalto', 'dev')
     | map(attribute='nome')
     | join(', ') }}
```

Resultado: `ana, carla`.

### 7.5 Exemplo real com facts

Tamanho disponível na partição raiz:

```yaml
msg: >-
  {{ ansible_facts['mounts']
     | selectattr('mount', 'equalto', '/')
     | map(attribute='size_available')
     | first
     | human_readable }}
```

### 7.6 Testes mais usados com `select` e `selectattr`

| Teste | Significado |
|---|---|
| `defined`, `undefined` | Variável existe ou não |
| `none` | É nulo |
| `equalto`, `eq`, `ne` | Igual, diferente |
| `gt`, `ge`, `lt`, `le` | Maior, maior ou igual, menor, menor ou igual |
| `in` | Está dentro de outra lista |
| `match`, `search` | Casa com regex (início / em qualquer ponto) |
| `string`, `number`, `mapping`, `iterable` | Tipo do valor |
| `even`, `odd` | Par ou ímpar |

---

## 8. Filtros de dicionários

### 8.1 `dict2items` e `items2dict`

Convertem entre dicionário e lista de pares chave/valor:

```yaml
vars:
  portas:
    http: 80
    https: 443

tasks:
  - name: Iterar sobre um dicionário
    ansible.builtin.debug:
      msg: "{{ item.key }} usa a porta {{ item.value }}"
    loop: "{{ portas | dict2items }}"
```

E o caminho inverso:

```yaml
msg: "{{ [{'key': 'a', 'value': 1}, {'key': 'b', 'value': 2}] | items2dict }}"
```

Resultado: `{'a': 1, 'b': 2}`.

### 8.2 `combine`: mesclar dicionários

```yaml
vars:
  padroes:        { porta: 80, ssl: false, workers: 2 }
  personalizados: { ssl: true }

msg: "{{ padroes | combine(personalizados) }}"
```

Resultado: `{'porta': 80, 'ssl': true, 'workers': 2}`. O último dicionário vence em caso de conflito.

Para dicionários aninhados, use `recursive=true`:

```yaml
msg: "{{ base | combine(extra, recursive=true) }}"
```

Padrão excelente para configuração: valores padrão no projeto, sobrescritas por grupo ou host.

### 8.3 Chaves, valores e ordenação

```yaml
msg:
  - "{{ portas.keys() | list }}"        # [http, https]
  - "{{ portas.values() | list }}"      # [80, 443]
  - "{{ portas | dictsort }}"           # lista de pares, ordenada pela chave
```

### 8.4 `json_query` (consultas complexas)

Permite extrair dados de estruturas aninhadas com a linguagem JMESPath:

```yaml
msg: "{{ usuarios | community.general.json_query('[?ativo].nome') }}"
```

Requisitos: a coleção `community.general` e a biblioteca Python `jmespath` na máquina de controle (`pip install jmespath`). Para casos simples, `selectattr` e `map` costumam bastar e não exigem nada extra.

---

## 9. Formatos de dados: JSON e YAML

| Filtro | Efeito |
|---|---|
| `to_json` | Estrutura para JSON compacto |
| `to_nice_json` | Estrutura para JSON legível (indentado) |
| `from_json` | Texto JSON para estrutura |
| `to_yaml` | Estrutura para YAML |
| `to_nice_yaml` | Estrutura para YAML legível |
| `from_yaml` | Texto YAML para estrutura |

Gravar a configuração de uma aplicação a partir de um dicionário:

```yaml
- name: Gerar arquivo JSON de configuração
  ansible.builtin.copy:
    dest: /etc/app/config.json
    content: "{{ config_app | to_nice_json }}\n"
    mode: "0644"
```

Ler um JSON que veio de um comando:

```yaml
- name: Interfaces
  ansible.builtin.command: ip -j addr show
  register: ip_json
  changed_when: false
  check_mode: false

- ansible.builtin.debug:
    msg: "{{ (ip_json.stdout | from_json) | map(attribute='ifname') | list }}"
```

---

## 10. Filtros de caminhos e arquivos

| Filtro | Exemplo | Resultado |
|---|---|---|
| `basename` | `'/etc/ssh/sshd_config' \| basename` | `sshd_config` |
| `dirname` | `'/etc/ssh/sshd_config' \| dirname` | `/etc/ssh` |
| `splitext` | `'relatorio.tar.gz' \| splitext` | `['relatorio.tar', '.gz']` |
| `expanduser` | `'~/bin' \| expanduser` | `/home/tux/bin` |
| `realpath` | `'/etc/../tmp' \| realpath` | `/tmp` |
| `relpath` | `'/etc/ssh' \| relpath('/etc')` | `ssh` |

`expanduser` e `realpath` são avaliados na **máquina de controle**, não no host remoto.

---

## 11. Datas e horários

```yaml
msg:
  - "{{ '%Y-%m-%d' | strftime }}"                             # data de agora
  - "{{ '%H:%M' | strftime(ansible_facts['date_time']['epoch'] | int) }}"
  - "{{ '2026-10-09' | to_datetime('%Y-%m-%d') }}"
  - "{{ (('2026-12-25' | to_datetime('%Y-%m-%d')) - ('2026-10-09' | to_datetime('%Y-%m-%d'))).days }}"
```

A última expressão calcula quantos dias faltam entre duas datas.

Também existe a função `now()`:

```yaml
msg: "{{ now().strftime('%Y%m%d_%H%M%S') }}"
```

Útil para nomes de backup: `backup_{{ inventory_hostname }}_{{ now().strftime('%Y%m%d') }}.tar.gz`.

---

## 12. Senhas, hashes e identificadores

| Filtro | Uso |
|---|---|
| `hash('sha256')` | Hash simples (checksum) de um texto |
| `checksum` | Hash SHA-1 de um texto |
| `password_hash('sha512')` | Hash de senha, no formato esperado por `/etc/shadow` |
| `to_uuid` | UUID determinístico a partir de um texto |

Criar usuário com senha em hash:

```yaml
- name: Criar usuário
  ansible.builtin.user:
    name: maria
    password: "{{ senha_texto | password_hash('sha512', 'umSaltFixo') }}"
```

Observações:

- Sem salt fixo, o hash muda a cada execução e a task aparece como **alterada** toda vez. Use um salt estável (por exemplo, derivado do nome do usuário) para manter a idempotência.
- Dependendo do Python da máquina de controle, o `password_hash` pode exigir a biblioteca `passlib` (`pip install passlib`).
- A senha em texto deve vir de um Vault, nunca escrita no playbook.

---

## 13. Decisões em uma linha: `ternary`

```yaml
msg: "{{ (ansible_facts['os_family'] == 'Debian') | ternary('apt', 'dnf') }}"
```

Se a condição for verdadeira, retorna o primeiro valor; senão, o segundo. Aceita um terceiro valor para quando a condição for nula.

Alternativa em Jinja puro, também válida:

```yaml
msg: "{{ 'apt' if ansible_facts['os_family'] == 'Debian' else 'dnf' }}"
```

Foi essa construção que usamos no capítulo inicial para escolher entre `apt-get update` e `dnf makecache`.

---

## 14. Testes (`is`)

Testes aparecem principalmente em `when`:

```yaml
when: pacote is defined
when: resposta is not none
when: caminho is file
when: caminho is directory
when: res is succeeded
when: res is failed
when: res is changed
when: res is skipped
when: ansible_facts['distribution_version'] is version('9', '>=')
when: texto is match('^[a-z]+$')
when: item in lista
```

O teste `version` é a forma correta de comparar versões; comparar texto (`'10' > '9'`) dá resultado errado.

> Os testes `file`, `directory` e `exists` verificam o caminho na **máquina de controle**. Para verificar no host remoto, use o módulo `stat` com `register`.

---

## 15. Exemplo completo

Um playbook que usa filtros de vários tipos, em Debian e Red Hat:

```yaml
---
- name: Exemplos de filtros
  hosts: all
  gather_facts: true

  vars:
    usuarios:
      - { nome: ana,   grupo: dev, ativo: true }
      - { nome: bruno, grupo: ops, ativo: false }
      - { nome: carla, grupo: dev, ativo: true }

    config_base:  { porta: 80, ssl: false, workers: 2 }
    config_extra: { ssl: true }

    pacote_web:
      Debian: apache2
      RedHat: httpd

  tasks:
    - name: Resumo do host
      ansible.builtin.debug:
        msg:
          - "Host (curto): {{ ansible_facts['fqdn'] | split('.') | first | upper }}"
          - "SO: {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_major_version'] | int }}"
          - "RAM: {{ (ansible_facts['memtotal_mb'] / 1024) | round(1) }} GB"
          - "Pacote web: {{ pacote_web[ansible_facts['os_family']] }}"
          - "Gerenciador: {{ (ansible_facts['os_family'] == 'Debian') | ternary('apt', 'dnf') }}"
      tags: resumo

    - name: Usuários ativos do grupo dev
      ansible.builtin.debug:
        msg: >-
          {{ usuarios
             | selectattr('ativo')
             | selectattr('grupo', 'equalto', 'dev')
             | map(attribute='nome')
             | join(', ') }}
      run_once: true
      tags: usuarios

    - name: Configuração final (padrão + sobrescrita)
      ansible.builtin.debug:
        msg: "{{ config_base | combine(config_extra) | to_nice_json }}"
      run_once: true
      tags: config

    - name: Nome do arquivo de backup
      ansible.builtin.debug:
        msg: "backup_{{ inventory_hostname }}_{{ now().strftime('%Y%m%d') }}.tar.gz"
      tags: backup
```

Execuções:

```bash
ansible-playbook -i hosts filtros.yml
ansible-playbook -i hosts filtros.yml --tags usuarios
ansible-playbook -i hosts filtros.yml --tags resumo --limit deb00,deb02
```

---

## 16. Filtros personalizados

Quando nenhum filtro existente resolve, você pode criar o seu em Python.

1. Crie o diretório `filter_plugins/` ao lado do playbook.
2. Crie um arquivo Python, por exemplo `filter_plugins/meus_filtros.py`:

```python
class FilterModule(object):
    def filters(self):
        return {
            "para_gb": self.para_gb,
        }

    def para_gb(self, valor_mb):
        return round(int(valor_mb) / 1024, 1)
```

3. Use no playbook:

```yaml
msg: "{{ ansible_facts['memtotal_mb'] | para_gb }} GB"
```

Filtros personalizados rodam na máquina de controle. Eles também podem ser distribuídos dentro de roles (em `roles/<role>/filter_plugins/`) ou de coleções.

---

## 17. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Resultado aparece como `<generator object ...>` | `map`, `select`, `reject`, `zip` retornam geradores | Terminar com `\| list` |
| `default` não funciona com variável vazia | `default` só atua em variável **indefinida** | `default('x', true)` |
| Comparação numérica errada | Valor é texto | `\| int` ou `\| float` |
| Erro de YAML ao escrever `{{ var }}` | Valor começa com `{{` sem aspas | Colocar entre aspas |
| Regex não casa | Barras invertidas tratadas por YAML e Jinja | Barras duplas e aspas simples no YAML |
| `\1` vira caractere estranho | Escape octal interpretado | Usar `\\1` |
| `json_query` não encontrado | Falta a coleção ou o `jmespath` | `ansible-galaxy collection install community.general` e `pip install jmespath` |
| `password_hash` altera sempre | Salt aleatório a cada execução | Informar um salt fixo |
| `password_hash` falha | Falta `passlib` ou Python novo sem `crypt` | `pip install passlib` |
| `'dict object' has no attribute` | Chave inexistente | Conferir com `debug: var=`, usar `default` |
| Filtro não encontrado | Nome incorreto, ou filtro de coleção não instalada | Usar o nome completo (FQCN) e instalar a coleção |
| Precedência confusa em `when` | Mistura de filtro e operadores | Usar parênteses: `(a \| int) + 1` |

---

## 18. Boas práticas

1. **Prefira filtros a `command` e `shell` com `awk`, `sed`, `cut`** para tratar dados já disponíveis no Ansible; é mais portátil e mais fácil de depurar.
2. **Divida expressões longas** em várias linhas com `>-` (como nos exemplos) para melhorar a leitura.
3. **Use `set_fact` ou `vars`** para guardar resultados intermediários com nomes claros, em vez de uma única expressão gigante.
4. **Termine `map`, `select` e `reject` com `| list`.**
5. **Converta tipos explicitamente** (`| int`, `| float`, `| bool`) em dados que vêm de comandos, extra vars ou prompts.
6. **Proteja o acesso** a valores opcionais com `default()`.
7. **Use `combine`** para montar configuração em camadas (padrão do projeto, grupo, host).
8. **Use `is version(...)`** para comparar versões, nunca texto.
9. **Descubra antes de filtrar:** use `debug: var=` para conhecer a estrutura dos dados.
10. **Use FQCN** (`community.general.json_query`) para filtros de coleções.
11. **Mantenha a idempotência:** evite filtros com resultado aleatório ou dependente de data em parâmetros de módulos que alteram o sistema, a menos que seja intencional.
12. **Teste com o comando ad-hoc** antes de colocar uma expressão complexa no playbook.

---

## Resumo

| Necessidade | Filtro |
|---|---|
| Valor padrão | `default(x)` / `default(x, true)` |
| Variável obrigatória | `mandatory` |
| Omitir parâmetro de módulo | `default(omit)` |
| Limpar texto | `trim`, `replace`, `upper`, `lower` |
| Dividir ou juntar | `split`, `join` |
| Extrair com regex | `regex_search`, `regex_findall`, `regex_replace` |
| Converter tipos | `int`, `float`, `bool`, `string` |
| Arredondar | `round` |
| Bytes legíveis | `human_readable` |
| Primeiro ou último item | `first`, `last` |
| Remover duplicados e ordenar | `unique`, `sort` |
| Operações de conjunto | `union`, `intersect`, `difference` |
| Filtrar listas | `select`, `reject`, `selectattr`, `rejectattr` |
| Extrair ou transformar | `map` |
| Dicionário para lista (e inverso) | `dict2items`, `items2dict` |
| Mesclar dicionários | `combine` |
| Consultas complexas | `json_query` |
| JSON e YAML | `to_json`, `to_nice_json`, `from_json`, `to_nice_yaml` |
| Caminhos | `basename`, `dirname`, `splitext` |
| Datas | `strftime`, `to_datetime`, `now()` |
| Hash de senha | `password_hash('sha512', salt)` |
| Decisão em uma linha | `ternary` |
| Comparar versões | `is version('x', '>=')` |
| Escapar para o shell | `quote` |
