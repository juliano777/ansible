# Capítulo: `ansible-doc`

## 1. O que é o `ansible-doc`

O `ansible-doc` é o **manual do Ansible na linha de comando**. Ele lê a documentação que vem **dentro do próprio código** de cada módulo, plugin e role instalados na sua máquina e a mostra no terminal, sem precisar de internet ou de navegador.

Ele responde, em segundos, às perguntas que mais aparecem no dia a dia:

- Que módulos existem para PostgreSQL?
- Quais **parâmetros** o módulo `lineinfile` aceita, e quais são obrigatórios?
- Qual é o **valor padrão** de um parâmetro?
- O que a variável registrada (`register`) vai conter depois da task?
- Esse módulo funciona em modo `--check`?
- Que biblioteca Python esse módulo exige?
- Como se configura aquele plugin?

### 1.1 Por que usar em vez do site

| | `ansible-doc` | Site `docs.ansible.com` |
|---|---|---|
| Funciona **offline** | Sim | Não |
| Corresponde à **versão instalada** | **Sim** (lê o código que você realmente usa) | Pode mostrar outra versão |
| Inclui **collections** instaladas, inclusive as da sua empresa | Sim | Apenas as publicadas |
| Inclui **plugins e roles locais** | Sim | Não |
| Pesquisa por texto | Limitada (use `grep`) | Boa |
| Navegação e explicações longas | Limitada | Melhor |

A regra prática: **o `ansible-doc` é a fonte de verdade** sobre o que **a sua instalação** aceita. O site é bom para guias e conceitos.

### 1.2 Onde ele vem

O `ansible-doc` faz parte do `ansible-core`; se o `ansible-playbook` está instalado, o `ansible-doc` também está.

```bash
ansible-doc --version
```

---

## 2. Sintaxe e opções

```
ansible-doc [opções] [nome ...]
```

| Opção | Efeito |
|---|---|
| (sem opções) `nome` | Mostra a documentação completa do módulo ou plugin |
| `-l`, `--list` | **Lista** os módulos ou plugins disponíveis, com uma descrição curta |
| `-s`, `--snippet` | Mostra um **trecho pronto** de task (para módulos, lookups e inventários) |
| `-F`, `--list_files` | Lista os nomes e os **arquivos de origem** |
| `-t TIPO`, `--type TIPO` | Escolhe o **tipo** (módulo, lookup, filter, callback, role...) |
| `-j`, `--json` | Saída em **JSON** (para programas) |
| `-e PONTO`, `--entry-point PONTO` | Em roles, escolhe o ponto de entrada (padrão: `main`) |
| `-r CAMINHO`, `--roles-path CAMINHO` | Em roles, onde procurar |
| `-M CAMINHO`, `--module-path CAMINHO` | Acrescenta uma pasta de módulos para procurar |
| `--playbook-dir PASTA` | Usa a pasta do projeto para achar plugins e roles locais |
| `--no-fail-on-errors` | Não aborta se houver erros em algum item da lista |
| `-v` | Mais detalhes |

Os **tipos** aceitos em `-t`: `module` (padrão), `become`, `cache`, `callback`, `cliconf`, `connection`, `filter`, `httpapi`, `inventory`, `keyword`, `lookup`, `netconf`, `role`, `shell`, `strategy`, `test`, `vars`.

> A lista de tipos pode variar conforme a versão; `ansible-doc --help` mostra os que a sua instalação aceita.

---

## 3. Listando o que existe

### 3.1 Todos os módulos

```bash
ansible-doc -l
```

Mostra uma linha por módulo, com o **nome completo (FQCN)** e uma descrição curta. A lista é grande, então combine com `grep` e `less`.

```bash
ansible-doc -l | less
ansible-doc -l | wc -l                  # quantos módulos existem
```

### 3.2 Procurando por palavra

O `ansible-doc` não tem busca embutida; use o `grep` sobre a listagem:

```bash
ansible-doc -l | grep -i postgres
ansible-doc -l | grep -i firewall
ansible-doc -l | grep -i "user"
```

### 3.3 Apenas uma collection

```bash
ansible-doc -l community.postgresql
ansible-doc -l ansible.builtin
ansible-doc -l ansible.posix
```

Também funciona com apenas o *namespace*:

```bash
ansible-doc -l community
```

### 3.4 Plugins de outros tipos

```bash
ansible-doc -t lookup -l
ansible-doc -t filter -l
ansible-doc -t test -l
ansible-doc -t callback -l
ansible-doc -t connection -l
ansible-doc -t become -l
ansible-doc -t inventory -l
ansible-doc -t strategy -l
ansible-doc -t cache -l
ansible-doc -t keyword -l
ansible-doc -t role -l
```

### 3.5 De onde vem cada item: `-F`

```bash
ansible-doc -F ansible.builtin
```

Mostra o nome e o **caminho do arquivo** de cada módulo. Útil para descobrir **qual collection e qual arquivo** está sendo realmente usado quando houver dúvida sobre versões.

---

## 4. Lendo a documentação de um módulo

```bash
ansible-doc ansible.builtin.lineinfile
```

(Pode-se usar o nome curto, `ansible-doc lineinfile`, mas o **nome completo** é mais seguro, pois evita ambiguidade entre collections.)

### 4.1 Anatomia da saída

A documentação segue sempre a mesma estrutura:

```
> ANSIBLE.BUILTIN.LINEINFILE    (/usr/lib/python3/dist-packages/ansible/modules/lineinfile.py)

  This module ensures a particular line is in a file, or replace an
  existing line using a back-referenced regular expression.

OPTIONS (= is mandatory):

- backup
        Create a backup file including the timestamp information...
        default: false
        type: bool

= path
        The file to modify.
        aliases: [dest, destfile, name]
        type: path

- regexp
        The regular expression to look for in every line of the file.
        default: null
        type: str
...

ATTRIBUTES:

    check_mode:
      support: full
    diff_mode:
      support: full
    platform:
      platforms: posix

NOTES:
   * ...

SEE ALSO:
   * Module ansible.builtin.blockinfile ...

AUTHOR: Daniel Hokka Zakrisson (@dhozac), Ansible Core Team

EXAMPLES:
- name: Ensure SELinux is set to enforcing mode
  ansible.builtin.lineinfile:
    path: /etc/selinux/config
    regexp: '^SELINUX='
    line: SELINUX=enforcing
...

RETURN VALUES:
...
```

(A saída acima é ilustrativa e resumida; o texto real varia conforme a versão instalada.)

### 4.2 O que cada seção significa

| Seção | O que contém | Para que serve |
|---|---|---|
| **Cabeçalho** (`> NOME  (caminho)`) | Nome completo e arquivo de origem | Confirmar **qual** módulo é |
| **Descrição** | Resumo do que o módulo faz | Entender o propósito |
| **OPTIONS** | **Todos os parâmetros**, com tipo, padrão, opções válidas e apelidos | Montar a task corretamente |
| **ATTRIBUTES** | Suporte a `check_mode`, `diff_mode`, plataformas, etc. | Saber se funciona com `--check` e em quais sistemas |
| **NOTES** | Observações e armadilhas | Evitar surpresas |
| **REQUIREMENTS** | Bibliotecas e programas exigidos | Preparar o ambiente (`pip install ...`) |
| **SEE ALSO** | Módulos relacionados | Descobrir alternativas |
| **EXAMPLES** | Tasks de exemplo prontas | Copiar e adaptar |
| **RETURN VALUES** | Os campos que o módulo devolve | Saber o que `register` conterá |
| **DEPRECATED** | Aviso de que está obsoleto e qual a alternativa | Evitar módulos que serão removidos |

### 4.3 Lendo a seção OPTIONS

```
OPTIONS (= is mandatory):

= path
        The file to modify.
        aliases: [dest, destfile, name]
        type: path

- state
        Whether the line should be there or not.
        (Choices: absent, present)[Default: present]
        type: str

- mode
        The permissions the resulting filesystem object should have.
        type: raw

- owner
        Name of the user that should own the filesystem object...
```

| Marca | Significado |
|---|---|
| `=` antes do nome | Parâmetro **obrigatório** |
| `-` antes do nome | Parâmetro opcional |
| `default:` ou `[Default: ...]` | Valor usado quando você não informa nada |
| `Choices:` | Valores aceitos (`present`, `absent`...) |
| `aliases:` | Outros nomes do mesmo parâmetro (`dest` e `path`) |
| `type:` | `str`, `int`, `bool`, `list`, `dict`, `path`, `raw`... |
| `elements:` | Tipo dos itens, quando `type` é `list` |
| `version_added:` | Versão em que o parâmetro surgiu |
| `suboptions:` | Parâmetros aninhados dentro de um dicionário |

**Dica:** procure primeiro os parâmetros com `=` (obrigatórios). Em poucos segundos, você sabe o mínimo necessário para o módulo funcionar.

### 4.4 Exemplo: conferindo o que o `package` realmente aceita

No começo do material, vimos que o `ansible.builtin.package` repassa parâmetros ao módulo real (como `update_cache`). Você pode **conferir por conta própria** o que está documentado:

```bash
ansible-doc ansible.builtin.package
```

A seção OPTIONS lista `name`, `state` e `use`. Já o `update_cache` aparece na documentação de `ansible.builtin.apt` e `ansible.builtin.dnf`:

```bash
ansible-doc ansible.builtin.apt  | grep -A3 update_cache
ansible-doc ansible.builtin.dnf  | grep -A3 update_cache
```

Isso mostra, na prática, por que o parâmetro funciona no `package` (ele chega ao módulo real), mas não faz parte do contrato documentado dele.

### 4.5 Lendo a seção RETURN VALUES

```bash
ansible-doc ansible.builtin.stat | sed -n '/RETURN VALUES/,$p'
```

Essa seção diz exatamente quais campos aparecem ao usar `register` com o módulo (`stat.exists`, `stat.isdir`, `stat.mode`...), ligando-se diretamente ao capítulo de `register` e ao do `stat`. Antes de usar `item.stat.exists` ou `res.stdout` em uma condição, **consulte o RETURN VALUES**.

### 4.6 Lendo ATTRIBUTES: suporte a `--check` e `--diff`

```bash
ansible-doc ansible.builtin.command | sed -n '/ATTRIBUTES/,/^$/p'
```

```
ATTRIBUTES:

    check_mode:
      details: while the command itself is arbitrary and cannot be subject to the check mode semantics it adds `creates`/`removes` options as a workaround
      support: partial
    diff_mode:
      support: none
```

O campo `support` indica:

| Valor | Significado |
|---|---|
| `full` | O módulo funciona plenamente no modo |
| `partial` | Funciona com restrições (leia os detalhes) |
| `none` | Não suporta o modo (a task é pulada em `--check`) |

É o que explica por que `command` e `shell` são **pulados** em `--check`, e por que precisam de `check_mode: false` quando alimentam outras tasks.

---

## 5. Trechos prontos: `-s` (snippet)

```bash
ansible-doc -s ansible.builtin.lineinfile
```

```yaml
- name: Manage lines in text files
  ansible.builtin.lineinfile:
      backup:                # Create a backup file including the timestamp information...
      create:                # Used with `state=present'. If specified, the file will be created...
      group:                 # Name of the group that should own the filesystem object...
      line:                  # The line to insert/replace into the file...
      mode:                  # The permissions the resulting filesystem object should have.
      owner:                 # Name of the user that should own the filesystem object...
      path:                  # (required) The file to modify.
      regexp:                # The regular expression to look for in every line of the file.
      state:                 # Whether the line should be there or not.
```

É um **esqueleto da task** com **todos os parâmetros** e uma descrição de cada um, em uma linha. Dois usos:

- ter uma visão geral rápida, sem rolar a documentação inteira;
- copiar para o seu playbook e apagar o que não precisa (o `(required)` aponta o que não pode faltar).

O snippet funciona para **módulos**, **lookups** e **plugins de inventário**:

```bash
ansible-doc -s -t lookup ansible.builtin.password
ansible-doc -s -t inventory amazon.aws.aws_ec2
```

---

## 6. Documentação de outros tipos de plugin

### 6.1 Lookups

```bash
ansible-doc -t lookup ansible.builtin.env
ansible-doc -t lookup ansible.builtin.first_found
ansible-doc -t lookup ansible.builtin.password
```

### 6.2 Filtros e testes

```bash
ansible-doc -t filter ansible.builtin.regex_replace
ansible-doc -t filter ansible.builtin.dict2items
ansible-doc -t test ansible.builtin.version
```

Mostram a descrição, os argumentos e exemplos de uso. (A documentação de filtros e testes está disponível nas versões mais recentes do `ansible-core`.)

### 6.3 Callbacks

```bash
ansible-doc -t callback ansible.posix.profile_tasks
ansible-doc -t callback ansible.builtin.default
```

A documentação mostra **como habilitar** (`callbacks_enabled`) e as **opções** (como `result_format` do callback `default`).

### 6.4 Conexão, `become`, estratégia, cache e inventário

```bash
ansible-doc -t connection ansible.builtin.ssh
ansible-doc -t become ansible.builtin.sudo
ansible-doc -t strategy ansible.builtin.free
ansible-doc -t cache ansible.builtin.jsonfile
ansible-doc -t inventory ansible.builtin.constructed
```

Cada opção traz uma seção de **como configurar**:

```
- pipelining
        Pipelining reduces the number of connection operations required...
        set_via:
          env:
          - name: ANSIBLE_PIPELINING
          ini:
          - key: pipelining
            section: connection
          vars:
          - name: ansible_pipelining
```

Isso informa as **três formas** de definir a opção: variável de ambiente, `ansible.cfg` e variável do Ansible (ver capítulo de plugins).

---

## 7. Palavras-chave de playbook: `-t keyword`

O `ansible-doc` também documenta as **palavras-chave** da linguagem dos playbooks (`when`, `loop`, `become`, `serial`, `delegate_to`...):

```bash
ansible-doc -t keyword -l          # lista todas
ansible-doc -t keyword serial
ansible-doc -t keyword delegate_to
ansible-doc -t keyword when
```

Mostra a **descrição** e **em quais níveis** a palavra pode ser usada (play, role, block, task):

```
serial
    Explicitly define how Ansible batches the execution of the current play on the play's target
    ...
    applies_to: Play
```

Quando houver dúvida se uma palavra vale para um bloco, para uma task ou só para o play (como `serial`, que só vale no play), esta é a consulta mais rápida.

---

## 8. Documentação de roles: `-t role`

Roles que têm o arquivo `meta/argument_specs.yml` (ver capítulo de roles) também são documentadas pelo `ansible-doc`:

```bash
ansible-doc -t role -l                                       # lista as roles encontradas
ansible-doc -t role --roles-path ./roles postgresql_remote   # documentação da role
ansible-doc -t role --roles-path ./roles postgresql_remote -e main   # ponto de entrada
```

A saída traz a descrição, **todas as variáveis** (com tipo, padrão e descrição, a partir do `argument_specs.yml`) e o ponto de entrada:

```
> ROLE: *postgresql_remote* (./roles/postgresql_remote)

ENTRY POINT: *main* - Libera o PostgreSQL para conexões remotas

        Libera o PostgreSQL para conexões remotas

OPTIONS (= is mandatory):

- postgresql_remote_porta
        Porta do PostgreSQL.
        default: 5432
        type: int

- postgresql_remote_redes_clientes
        Redes (CIDR) liberadas no pg_hba.conf.
        default: []
        elements: str
        type: list
...
```

(O formato exato varia conforme a versão.)

**Consequência para quem escreve roles:** o `argument_specs.yml` faz **duas coisas** ao mesmo tempo, valida os parâmetros na execução **e** vira a documentação consultável pelo `ansible-doc`. Escrever bem esse arquivo compensa duas vezes.

---

## 9. Saída em JSON (`-j`) para scripts

```bash
ansible-doc -t module -j ansible.builtin.stat
```

A saída é um dicionário com uma chave para cada item pedido (o FQCN), com:

| Campo | Conteúdo |
|---|---|
| `doc` | Descrição, opções, atributos, notas, requisitos |
| `examples` | O texto da seção EXAMPLES |
| `return` | Os campos do RETURN VALUES |
| `metadata` | Metadados internos (pode ser nulo) |

### 9.1 Com `jq`

```bash
# Só os exemplos
ansible-doc -t module -j ansible.builtin.stat | jq -r '."ansible.builtin.stat".examples'

# Nomes dos parâmetros
ansible-doc -t module -j ansible.builtin.stat | jq -r '."ansible.builtin.stat".doc.options | keys[]'

# Parâmetros obrigatórios
ansible-doc -t module -j ansible.builtin.lineinfile \
  | jq -r '."ansible.builtin.lineinfile".doc.options | to_entries[] | select(.value.required == true) | .key'
```

### 9.2 Com Python

```python
#!/usr/bin/env python3
"""Mostra os parâmetros obrigatórios e opcionais de um módulo."""

import json
import subprocess
import sys

modulo = sys.argv[1]

saida = subprocess.run(
    ["ansible-doc", "-t", "module", "-j", modulo],
    capture_output=True, text=True, check=True,
).stdout

nome, conteudo = next(iter(json.loads(saida).items()))
opcoes = conteudo["doc"].get("options", {})

print(f"{nome}\n")
print("Obrigatórios:")
for opcao, info in sorted(opcoes.items()):
    if info.get("required"):
        print(f"  {opcao} ({info.get('type', 'str')})")

print("\nOpcionais:")
for opcao, info in sorted(opcoes.items()):
    if not info.get("required"):
        padrao = info.get("default", "-")
        print(f"  {opcao} ({info.get('type', 'str')}, padrão: {padrao})")
```

```bash
python3 resumo_modulo.py ansible.builtin.lineinfile
```

### 9.3 Listagem completa em JSON

```bash
ansible-doc -t module -l -j
```

Devolve um dicionário `{FQCN: descrição curta}`, ótimo para montar índices, buscas e catálogos internos.

---

## 10. Documentação dos seus próprios plugins e módulos

O `ansible-doc` lê o que está nas variáveis de texto `DOCUMENTATION`, `EXAMPLES` e `RETURN` do código do plugin. Por isso, **documentar o seu plugin** o torna consultável do mesmo jeito que os embutidos (ver capítulo de plugins):

```python
DOCUMENTATION = """
  name: linhas_uteis
  short_description: Devolve as linhas de um arquivo, sem comentários e sem linhas vazias
  description:
    - Lê arquivos de texto da máquina de controle.
  options:
    _terms:
      description: Nomes dos arquivos a ler.
      required: true
"""
```

### 10.1 Consultando plugins e módulos locais

Para que o `ansible-doc` enxergue plugins e roles que ficam ao lado do seu playbook, informe a pasta do projeto:

```bash
ansible-doc --playbook-dir . -t lookup linhas_uteis
ansible-doc --playbook-dir . -t filter para_gb
ansible-doc --playbook-dir . -t test ip_privado
ansible-doc --playbook-dir . -t callback resumo_falhas
```

E para módulos em uma pasta `library/`:

```bash
ansible-doc -M ./library meu_modulo
```

### 10.2 Para quem publica collections

```bash
ansible-doc -l minha_empresa.infra          # lista o conteúdo da collection
ansible-doc minha_empresa.infra.para_gb -t filter
```

A documentação completa e correta é também exigida pelos testes `ansible-test sanity`.

---

## 11. Fluxos de trabalho

### 11.1 Receita: "preciso fazer X, qual módulo uso?"

```bash
# 1. Procurar pelo assunto
ansible-doc -l | grep -i <palavra>

# 2. Restringir a uma collection, se já souber qual
ansible-doc -l community.postgresql

# 3. Ver o esqueleto da task
ansible-doc -s <módulo>

# 4. Ler os detalhes de um parâmetro, os exemplos e o retorno
ansible-doc <módulo>
```

### 11.2 Receita: "como uso este módulo?"

1. **Cabeçalho e descrição:** confirme que é o módulo certo.
2. **REQUIREMENTS:** o que precisa estar instalado (e **onde**: no host ou na máquina de controle).
3. **OPTIONS:** procure os `=` (obrigatórios) e os valores padrão.
4. **ATTRIBUTES:** confira o suporte a `check_mode`.
5. **EXAMPLES:** copie o exemplo mais próximo do seu caso.
6. **RETURN VALUES:** veja o que o `register` vai guardar.
7. **NOTES e DEPRECATED:** leia as ressalvas antes de usar em produção.

### 11.3 Receita: "essa palavra-chave vale aqui?"

```bash
ansible-doc -t keyword <palavra>
```

### 11.4 Receita: "quais variáveis esta role aceita?"

```bash
ansible-doc -t role --roles-path ./roles <role>
```

### 11.5 Receita: documentação offline

Gere arquivos de texto para consulta sem o Ansible instalado (ou para anexar a um projeto):

```bash
mkdir -p docs
for m in ansible.builtin.copy ansible.builtin.lineinfile ansible.builtin.stat \
         community.postgresql.postgresql_user; do
  ansible-doc "$m" > "docs/$m.txt"
done
```

---

## 12. Exemplo completo: do problema à task

**Cenário:** é preciso criar o usuário `app` no PostgreSQL com o Ansible, e você nunca usou esse módulo.

### Passo 1: encontrar o módulo

```bash
ansible-doc -l | grep -i postgres | grep -i user
```

```
community.postgresql.postgresql_user   Create, alter, or remove a user (role) from a PostgreSQL server instance
community.postgresql.postgresql_privs  Grant or revoke privileges on PostgreSQL database objects
...
```

(Se nada aparecer, a collection não está instalada: `ansible-galaxy collection install community.postgresql`.)

### Passo 2: ver o esqueleto

```bash
ansible-doc -s community.postgresql.postgresql_user
```

```yaml
- name: Create, alter, or remove a user (role) from a PostgreSQL server instance
  community.postgresql.postgresql_user:
      comment:               # Add a comment on the user...
      db:                    # Name of database to connect to and where user's permissions will be granted.
      encrypted:             # Whether the password is stored hashed in the database.
      expires:               # The date at which the user's password is to expire.
      name:                  # (required) Name of the user (role) to add or remove.
      password:              # Set the user's password, before 1.4 this was required.
      state:                 # The user (role) state.
      ...
```

### Passo 3: ler os requisitos e as notas

```bash
ansible-doc community.postgresql.postgresql_user | sed -n '/REQUIREMENTS/,/AUTHOR/p'
```

O trecho indica, entre outros, que o módulo exige a biblioteca Python `psycopg2` **no host onde ele executa**.

### Passo 4: ver se aceita `--check`

```bash
ansible-doc community.postgresql.postgresql_user | sed -n '/ATTRIBUTES/,/^$/p'
```

### Passo 5: copiar e adaptar um exemplo

```bash
ansible-doc -t module -j community.postgresql.postgresql_user \
  | jq -r '."community.postgresql.postgresql_user".examples' | head -30
```

### Passo 6: escrever a task

```yaml
- name: Criar o usuário da aplicação no PostgreSQL
  community.postgresql.postgresql_user:
    name: "{{ postgresql_app_usuario }}"
    password: "{{ postgresql_app_senha }}"
    state: present
  become: true
  become_user: postgres
  no_log: true
```

### Passo 7: descobrir o que o `register` terá

```bash
ansible-doc -t module -j community.postgresql.postgresql_user \
  | jq -r '."community.postgresql.postgresql_user".return | keys[]'
```

```
queries
user
```

Com isso, a task seguinte pode usar `resultado.user` e `resultado.queries` com segurança, sem tentativa e erro.

---

## 13. Ambiente: versões, collections, offline

### 13.1 O que o `ansible-doc` enxerga

Ele procura nos mesmos lugares que o Ansible usa para executar:

| Fonte | Como é definida |
|---|---|
| Módulos e plugins do `ansible-core` | Instalação do Ansible |
| Collections instaladas | `collections_path` (`ANSIBLE_COLLECTIONS_PATH`) |
| Plugins e roles do projeto | `--playbook-dir` |
| Módulos extras | `-M` e `ANSIBLE_LIBRARY` |

Se um módulo "não aparece", quase sempre o problema é a collection não estar instalada, ou instalada fora do `collections_path` do projeto (ver capítulo do Galaxy):

```bash
ansible-galaxy collection list
ansible-config dump | grep -i COLLECTIONS_PATHS
```

### 13.2 Versões

A documentação mostrada é a da **versão instalada** de cada collection. Se a equipe fixa versões (`requirements.yml`), o `ansible-doc` de cada pessoa mostrará a mesma coisa, o que evita divergências entre "o que a documentação diz" e "o que o código faz".

O campo `version_added` informa **a partir de qual versão** um módulo ou parâmetro existe; se você usa uma collection antiga, o parâmetro novo simplesmente não existirá.

### 13.3 Paginador e cores

Em um terminal, a saída passa por um paginador (normalmente o `less`). Para desativá-lo, ou ao usar em scripts, redirecione:

```bash
ansible-doc ansible.builtin.copy | cat
ansible-doc ansible.builtin.copy > copy.txt
```

Fora de um terminal (em *pipes* e redirecionamentos), o `ansible-doc` já não usa o paginador. Para desativar as cores: `ANSIBLE_NOCOLOR=1`.

### 13.4 Completar com a tecla Tab

Se a biblioteca `argcomplete` estiver instalada e ativada no shell, os comandos do Ansible (incluindo o `ansible-doc`) completam opções e nomes com a tecla Tab. Consulte a documentação do `argcomplete` para ativá-la no seu shell.

---

## 14. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `module ... not found in` | Nome incorreto ou collection não instalada | `ansible-doc -l \| grep -i nome` e `ansible-galaxy collection install ...` |
| O nome curto abre outro módulo | Ambiguidade entre collections | Usar o **FQCN** (`ansible.builtin.copy`) |
| O módulo existe no site, mas não no `ansible-doc` | Versão instalada antiga, ou collection ausente | `ansible-galaxy collection list` e atualizar |
| Um parâmetro do site não existe no `ansible-doc` | O parâmetro é de versão mais nova | Ver `version_added` e atualizar a collection |
| Plugin local não é encontrado | O projeto não foi informado | `--playbook-dir .` |
| Role não aparece com `-t role` | Sem `meta/argument_specs.yml`, ou caminho incorreto | Criar o arquivo e usar `--roles-path` |
| `-s` não funciona para um tipo | Snippet só existe para módulos, lookups e inventários | Usar a documentação completa |
| `-t filter` ou `-t test` falha | Versão antiga do `ansible-core` | Atualizar, ou consultar o site |
| Saída trava esperando tecla | Paginador (`less`) aberto | Pressionar `q`, ou redirecionar a saída |
| Saída com códigos estranhos em arquivos | Cores ativas | `ANSIBLE_NOCOLOR=1` |
| Muitas linhas na listagem | Muitas collections instaladas | Filtrar por collection ou com `grep` |
| `jq` não encontrado | Ferramenta não instalada | Instalar o `jq`, ou usar um script Python |
| Erro de documentação malformada em um plugin | `DOCUMENTATION` com YAML inválido | Corrigir o YAML do plugin; `--no-fail-on-errors` ajuda em listagens |
| A documentação difere do comportamento observado | Versão do módulo executado difere da consultada | `ansible-doc -F nome` e conferir o caminho e a versão |

---

## 15. Boas práticas

1. **Consulte o `ansible-doc` antes de escrever uma task** com um módulo novo: leia OPTIONS, EXAMPLES e RETURN VALUES.
2. **Use o nome completo (FQCN)** nas consultas, igual ao que você usa nos playbooks.
3. **Procure primeiro os parâmetros obrigatórios** (`=`), depois os padrões.
4. **Leia o RETURN VALUES** antes de usar `register`, para não adivinhar nomes de campos.
5. **Confira o ATTRIBUTES (`check_mode`)** antes de depender de `--check` em um módulo.
6. **Confira o REQUIREMENTS:** bibliotecas Python e programas que precisam estar instalados, e **onde** (host ou máquina de controle).
7. **Atenção a DEPRECATED e `version_added`** para evitar módulos obsoletos e parâmetros que não existem na sua versão.
8. **Use `-s` (snippet)** para ter um esqueleto de task e descobrir parâmetros opcionais úteis.
9. **Use `-t keyword`** para dúvidas sobre palavras-chave (onde valem, o que fazem).
10. **Documente seus plugins, módulos e roles** (`DOCUMENTATION`, `argument_specs.yml`): o `ansible-doc` passa a documentá-los sem trabalho extra.
11. **Fixe as versões das collections** para que todos consultem a mesma documentação.
12. **Use `-j` com `jq` ou Python** para automatizar consultas, catálogos e verificações.
13. **Em ambientes isolados**, o `ansible-doc` é a documentação disponível: gere cópias em texto se necessário.
14. **Combine com o site** para guias e conceitos, e use o `ansible-doc` como referência exata da sua instalação.

---

## Resumo

| Necessidade | Comando |
|---|---|
| Documentação de um módulo | `ansible-doc ansible.builtin.copy` |
| Listar todos os módulos | `ansible-doc -l` |
| Procurar um módulo por palavra | `ansible-doc -l \| grep -i palavra` |
| Listar os módulos de uma collection | `ansible-doc -l community.postgresql` |
| Trecho pronto de task | `ansible-doc -s ansible.builtin.copy` |
| Ver o arquivo de origem de cada módulo | `ansible-doc -F ansible.builtin` |
| Documentação de um lookup | `ansible-doc -t lookup ansible.builtin.env` |
| Documentação de um filtro ou teste | `ansible-doc -t filter ...` / `-t test ...` |
| Documentação de um callback ou conexão | `ansible-doc -t callback ...` / `-t connection ...` |
| Listar plugins de um tipo | `ansible-doc -t <tipo> -l` |
| Palavras-chave de playbook | `ansible-doc -t keyword -l` e `-t keyword <palavra>` |
| Documentação de uma role | `ansible-doc -t role --roles-path ./roles <role>` |
| Saída em JSON | `ansible-doc -j ...` |
| Só os exemplos | `ansible-doc -t module -j nome \| jq -r '."nome".examples'` |
| Plugins locais do projeto | `ansible-doc --playbook-dir . -t <tipo> nome` |
| Módulos em outra pasta | `ansible-doc -M ./library nome` |
| Campos que o `register` terá | Seção **RETURN VALUES** |
| Suporte a `--check` e `--diff` | Seção **ATTRIBUTES** |
| Parâmetros obrigatórios | Marcados com `=` em **OPTIONS** |
| Requisitos do módulo | Seção **REQUIREMENTS** |
