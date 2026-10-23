# Capítulo: `ansible-inventory`

## 1. O que é o `ansible-inventory`

O `ansible-inventory` é o comando que **mostra como o Ansible enxerga o seu inventário**: quais hosts existem, em quais grupos estão e quais **variáveis** valem para cada um, já com todas as heranças aplicadas. Ele não executa nada nos hosts; apenas **lê, interpreta e exibe** o inventário.

Para que serve:

- **Depurar** o inventário ("por que este host não está no grupo?", "de onde vem esta variável?");
- **Conferir** se `group_vars` e `host_vars` estão sendo carregados;
- **Visualizar** a hierarquia de grupos;
- **Testar** inventários dinâmicos (nuvem, scripts) sem rodar um playbook;
- **Converter** um inventário entre formatos (INI, YAML, TOML, JSON);
- **Exportar** um retrato do inventário para scripts, relatórios e testes de CI.

### 1.1 Comparação com comandos parecidos

| Comando | Mostra |
|---|---|
| `ansible-inventory --graph` | A **árvore** de grupos e hosts |
| `ansible-inventory --list` | **Tudo**: grupos, hosts e variáveis, em JSON, YAML ou TOML |
| `ansible-inventory --host NOME` | As **variáveis** de um host |
| `ansible all --list-hosts` | Só os **nomes** dos hosts que casam com um padrão |
| `ansible-playbook pg.yml --list-hosts` | Os hosts de **cada play**, após aplicar `hosts:` e `--limit` |
| `ansible -m debug -a "var=..."` | Variáveis **durante a execução** (inclui facts e variáveis de play) |

O `ansible-inventory` enxerga apenas o que vem **do inventário**: grupos, variáveis de inventário, `group_vars` e `host_vars`. Ele **não** mostra facts, variáveis de play, de roles ou registradas.

---

## 2. Revisão rápida: o inventário

Para que as saídas façam sentido, este capítulo usa o inventário abaixo, na forma INI, que é o formato do arquivo `hosts` usado nos capítulos anteriores.

### 2.1 O inventário de exemplo (`hosts`)

```ini
# Host sem grupo (fica em "ungrouped")
monitor01 ansible_host=192.168.1.5

[debian]
deb00 ansible_host=192.168.1.10
deb02 ansible_host=192.168.1.12

[redhat]
rh01 ansible_host=192.168.1.21

[db]
deb00
rh01

[web]
deb02

# Grupo que contém outros grupos
[servidores:children]
debian
redhat

# Variáveis de um grupo
[servidores:vars]
ansible_user=tux

[db:vars]
postgresql_remote_porta=5432
```

### 2.2 Conceitos

| Conceito | Descrição |
|---|---|
| **Host** | Uma máquina gerenciada, com variáveis opcionais (`ansible_host=...`) |
| **Grupo** | Conjunto de hosts (`[db]`) |
| **Subgrupo** | Grupo dentro de outro grupo (`[servidores:children]`) |
| **Variáveis de grupo** | Valem para todos os hosts do grupo (`[db:vars]`) |
| `all` | Grupo implícito que contém **todos** os hosts |
| `ungrouped` | Grupo implícito dos hosts que **não** estão em nenhum outro grupo |
| Um host em vários grupos | Permitido (`deb00` está em `debian`, `db` e `servidores`) |

### 2.3 O mesmo inventário em YAML

```yaml
---
all:
  hosts:
    monitor01:
      ansible_host: 192.168.1.5
  children:
    servidores:
      vars:
        ansible_user: tux
      children:
        debian:
          hosts:
            deb00:
              ansible_host: 192.168.1.10
            deb02:
              ansible_host: 192.168.1.12
        redhat:
          hosts:
            rh01:
              ansible_host: 192.168.1.21
    db:
      vars:
        postgresql_remote_porta: 5432
      hosts:
        deb00:
        rh01:
    web:
      hosts:
        deb02:
```

### 2.4 Faixas de hosts

Para muitos hosts com nomes numerados:

```ini
[web]
web[01:05]               # web01, web02, web03, web04, web05
db-[a:c].exemplo.com     # db-a, db-b, db-c
```

---

## 3. Sintaxe e opções

```
ansible-inventory [opções] [grupo|host]
```

| Opção | Efeito |
|---|---|
| `-i`, `--inventory` | Arquivo, diretório ou lista de hosts (repetível) |
| `--list` | Mostra o inventário completo |
| `--host NOME` | Mostra as variáveis de um host |
| `--graph` | Mostra a árvore de grupos e hosts |
| `--vars` | Com `--graph`, mostra também as variáveis de cada grupo |
| `-y`, `--yaml` | Saída em YAML (em vez de JSON) |
| `--toml` | Saída em TOML |
| `--export` | Em `--list`, preserva as variáveis onde foram definidas, em vez de "achatá-las" |
| `--output ARQUIVO` | Em `--list`, grava em um arquivo em vez de mostrar na tela |
| `--playbook-dir PASTA` | Usa a pasta do projeto para localizar `group_vars` e `host_vars` |
| `-e`, `--extra-vars` | Variáveis extras (afetam inventários dinâmicos e construídos) |
| `--ask-vault-password`, `--vault-password-file`, `--vault-id` | Senha do Vault (para arquivos criptografados) |
| `-v` | Mais detalhes, incluindo qual plugin leu cada fonte |

Opcionalmente, pode-se informar um **grupo** ou **host** como argumento (usado principalmente com `--graph`).

> Observação: o `ansible-inventory` não possui a opção `--limit` do `ansible-playbook`. Para filtrar, use o argumento de grupo (com `--graph`) ou filtros externos, como o `jq`.

### 3.1 Indicando o inventário

```bash
ansible-inventory -i hosts --graph
ansible-inventory -i inventory/ --graph                 # diretório
ansible-inventory -i hosts -i dinamico.aws_ec2.yml --graph   # vários
ansible-inventory -i "deb00,deb02," --graph             # lista direta (note a vírgula final)
```

Se o `ansible.cfg` do projeto define `inventory = ./hosts`, o `-i` pode ser omitido.

---

## 4. A árvore de grupos: `--graph`

```bash
ansible-inventory -i hosts --graph
```

```
@all:
  |--@db:
  |  |--deb00
  |  |--rh01
  |--@servidores:
  |  |--@debian:
  |  |  |--deb00
  |  |  |--deb02
  |  |--@redhat:
  |  |  |--rh01
  |--@ungrouped:
  |  |--monitor01
  |--@web:
  |  |--deb02
```

(A ordem dos grupos pode variar conforme a versão.)

Como ler:

- `@nome:` é um **grupo**, e o texto simples é um **host**.
- A **indentação** mostra a hierarquia (`debian` está dentro de `servidores`).
- Um host aparece **em todos os grupos** a que pertence (`deb00` aparece em `db` e em `debian`).

### 4.1 Um grupo específico

```bash
ansible-inventory -i hosts --graph db
```

```
@db:
  |--deb00
  |--rh01
```

### 4.2 Com variáveis (`--vars`)

```bash
ansible-inventory -i hosts --graph --vars
```

```
@all:
  |--@db:
  |  |--{postgresql_remote_porta = 5432}
  |  |--deb00
  |  |  |--{ansible_host = 192.168.1.10}
  |  |  |--{ansible_user = tux}
  |  |--rh01
  |  |  |--{ansible_host = 192.168.1.21}
  ...
```

Mostra, abaixo de cada grupo e host, as variáveis em chaves. É ótimo para ver **de onde vem** cada valor (do host? de qual grupo?).

### 4.3 O que o `--graph` ajuda a descobrir

| Dúvida | O que olhar |
|---|---|
| "O host está no grupo certo?" | O grupo na árvore |
| "Quais grupos o host pertence?" | Em quais `@grupo` o nome aparece |
| "Existe algum host sem grupo?" | O grupo `@ungrouped` |
| "O subgrupo foi ligado ao pai?" | A indentação |
| "Há um erro de digitação no nome do host?" | Um host duplicado com nome quase igual |

---

## 5. O inventário completo: `--list`

### 5.1 Saída em JSON (padrão)

```bash
ansible-inventory -i hosts --list
```

```json
{
    "_meta": {
        "hostvars": {
            "deb00": {
                "ansible_host": "192.168.1.10",
                "ansible_user": "tux",
                "postgresql_remote_porta": 5432
            },
            "deb02": {
                "ansible_host": "192.168.1.12",
                "ansible_user": "tux"
            },
            "monitor01": {
                "ansible_host": "192.168.1.5"
            },
            "rh01": {
                "ansible_host": "192.168.1.21",
                "ansible_user": "tux",
                "postgresql_remote_porta": 5432
            }
        }
    },
    "all": {
        "children": ["ungrouped", "servidores", "db", "web"]
    },
    "db": {
        "hosts": ["deb00", "rh01"]
    },
    "servidores": {
        "children": ["debian", "redhat"]
    },
    "debian": {
        "hosts": ["deb00", "deb02"]
    },
    "redhat": {
        "hosts": ["rh01"]
    },
    "ungrouped": {
        "hosts": ["monitor01"]
    },
    "web": {
        "hosts": ["deb02"]
    }
}
```

(Saída resumida e ilustrativa.)

### 5.2 A estrutura

| Chave | Conteúdo |
|---|---|
| `_meta.hostvars` | As variáveis **finais** de cada host, já combinadas com as de grupos, `group_vars` e `host_vars` |
| Nome de um grupo | `hosts` (lista de hosts diretos), `children` (subgrupos) e, às vezes, `vars` |
| `all` | Os grupos de primeiro nível |
| `ungrouped` | Hosts sem grupo |

Repare que `deb00` recebeu `ansible_user` (do grupo `servidores`) e `postgresql_remote_porta` (do grupo `db`): o `--list` mostra o **resultado** da combinação, e não onde cada valor foi definido.

### 5.3 `--export`: variáveis onde foram definidas

```bash
ansible-inventory -i hosts --list --export
```

Com `--export`, as variáveis **não são achatadas** nos hosts: ficam nos grupos em que foram definidas (por exemplo, `ansible_user` em `servidores`). Isso gera uma saída mais próxima do inventário original, ideal para **converter** ou **versionar**, e menos útil para saber o valor final de um host.

| | Sem `--export` | Com `--export` |
|---|---|---|
| Variáveis | Combinadas em cada host | Onde foram definidas (grupos e hosts) |
| Uso | Saber o **valor final** de cada host | **Converter** e guardar a estrutura |

### 5.4 YAML e TOML

```bash
ansible-inventory -i hosts --list -y
ansible-inventory -i hosts --list -y --export
ansible-inventory -i hosts --list --toml
```

Exemplo com `-y --export` (resumido):

```yaml
all:
  children:
    db:
      hosts:
        deb00: {}
        rh01: {}
      vars:
        postgresql_remote_porta: 5432
    servidores:
      children:
        debian:
          hosts:
            deb00:
              ansible_host: 192.168.1.10
            deb02:
              ansible_host: 192.168.1.12
        redhat:
          hosts:
            rh01:
              ansible_host: 192.168.1.21
      vars:
        ansible_user: tux
    ungrouped:
      hosts:
        monitor01:
          ansible_host: 192.168.1.5
    web:
      hosts:
        deb02: {}
```

Lembre-se: a opção `-y` é ignorada com `--graph`, e a saída em YAML não é a mesma de `--host`.

### 5.5 Gravando em arquivo

```bash
ansible-inventory -i hosts --list --output inventario.json
ansible-inventory -i hosts --list -y --export --output hosts.yml
```

O mesmo resultado de `> arquivo`, sem misturar com mensagens de aviso (que vão para a saída de erro).

---

## 6. Variáveis de um host: `--host`

```bash
ansible-inventory -i hosts --host deb00
```

```json
{
    "ansible_host": "192.168.1.10",
    "ansible_user": "tux",
    "postgresql_remote_porta": 5432
}
```

Mostra as variáveis do inventário que valem para `deb00`, combinando as definidas no host, nos grupos a que ele pertence e nos arquivos `group_vars` e `host_vars`.

Variações úteis:

```bash
ansible-inventory -i hosts --host deb00 | jq 'keys'                          # só os nomes
ansible-inventory -i hosts --host deb00 | jq '.postgresql_remote_porta'      # um valor
ansible-inventory -i hosts --host deb00 -y                                   # em YAML
```

### 6.1 O que o `--host` **não** mostra

| Não aparece | Onde ver |
|---|---|
| Facts (`ansible_facts`) | `ansible host -m ansible.builtin.setup` |
| Variáveis do play (`vars:`, `vars_files`) | `debug: var=...` dentro do playbook |
| Variáveis de roles (`defaults/`, `vars/`) | `debug: var=...` dentro do playbook |
| Variáveis registradas (`register`) | Durante a execução |
| Extra vars (`-e`) | Aparecem apenas se informadas no próprio `ansible-inventory -e` |

---

## 7. Diretórios de inventário, `group_vars` e `host_vars`

### 7.1 Estrutura recomendada

Para projetos que crescem, use um **diretório** de inventário:

```
inventory/
├── 01-hosts.ini
├── 02-nuvem.aws_ec2.yml        # inventário dinâmico (opcional)
├── group_vars/
│   ├── all.yml
│   └── db.yml
└── host_vars/
    └── deb00.yml
```

```bash
ansible-inventory -i inventory/ --graph
```

O Ansible lê **todos os arquivos** do diretório (em ordem alfabética, por isso os prefixos numéricos) e carrega `group_vars/` e `host_vars/` que estejam ao lado.

### 7.2 Verificando a precedência

`inventory/group_vars/all.yml`:

```yaml
---
ntp_server: pool.ntp.org
postgresql_remote_porta: 5432
```

`inventory/group_vars/db.yml`:

```yaml
---
postgresql_remote_porta: 5433
```

`inventory/host_vars/deb00.yml`:

```yaml
---
postgresql_remote_porta: 5434
```

Consultando os hosts:

```bash
ansible-inventory -i inventory/ --host rh01  | jq '.postgresql_remote_porta'    # 5433 (vem do grupo db)
ansible-inventory -i inventory/ --host deb00 | jq '.postgresql_remote_porta'    # 5434 (host vence grupo)
ansible-inventory -i inventory/ --host deb02 | jq '.postgresql_remote_porta'    # 5432 (deb02 não está em db; vem de all)
```

Regras de precedência no inventário (do **menor** para o **maior**):

1. Grupo `all`
2. Grupos pais
3. Grupos filhos (o filho vence o pai)
4. O próprio host (host vence grupo)

Quando a mesma variável vem de **fontes diferentes**, a ordem completa (do menor para o maior) é:

1. variáveis de **grupo** definidas no arquivo de inventário;
2. `group_vars/` ao lado do inventário (`all` e depois os demais grupos);
3. `group_vars/` ao lado do playbook;
4. variáveis de **host** definidas no arquivo de inventário;
5. `host_vars/` ao lado do inventário;
6. `host_vars/` ao lado do playbook.

Ou seja: variáveis de host sempre vencem as de grupo, e dentro de cada nível os arquivos de `group_vars/` e `host_vars/` vencem as definidas no arquivo de inventário.

### 7.3 Grupos no mesmo nível: `ansible_group_priority`

Quando um host está em dois grupos **do mesmo nível** que definem a mesma variável, vale o grupo cujo nome vem **por último na ordem alfabética**. Para controlar isso explicitamente, use `ansible_group_priority` (maior número vence; o padrão é 1):

```ini
[debian:vars]
ansible_group_priority=10
motd=Servidor Debian

[db:vars]
motd=Servidor de banco
```

A variável `ansible_group_priority` só funciona quando definida **no arquivo de inventário**, e não em `group_vars/`.

### 7.4 `--playbook-dir`: `group_vars` ao lado do playbook

O `group_vars/` e o `host_vars/` podem ficar ao lado do **inventário** ou ao lado do **playbook**. Como o `ansible-inventory` não usa playbook, informe a pasta do projeto para que ele os encontre:

```bash
ansible-inventory -i hosts --playbook-dir . --host deb00
ansible-inventory -i hosts --playbook-dir /home/tux/ansible --graph --vars
```

Se uma variável de `group_vars/` **não aparece** no `ansible-inventory`, mas aparece no playbook, esse é o motivo mais comum.

---

## 8. Padrões de hosts e `--list-hosts`

O `ansible-inventory` mostra a **estrutura**. Para verificar quais hosts um **padrão** selecionaria, use `--list-hosts`:

```bash
ansible all -i hosts --list-hosts
ansible db -i hosts --list-hosts
ansible 'db:&debian' -i hosts --list-hosts        # interseção: em db E em debian
ansible 'servidores:!redhat' -i hosts --list-hosts # em servidores, menos redhat
ansible 'web:db' -i hosts --list-hosts             # união
ansible 'deb*' -i hosts --list-hosts               # curinga
```

| Padrão | Significado |
|---|---|
| `all` ou `*` | Todos os hosts |
| `db` | Hosts do grupo `db` (incluindo subgrupos) |
| `web:db` | **União** (web ou db) |
| `db:&debian` | **Interseção** (em ambos) |
| `servidores:!redhat` | **Exclusão** (servidores, menos os do redhat) |
| `deb*` | Nomes que começam com `deb` |
| `~deb0[0-9]` | **Expressão regular** |
| `db[0]` | O primeiro host do grupo |

Para ver o que um **playbook** faria, incluindo o `--limit`:

```bash
ansible-playbook -i hosts pg.yml --list-hosts
ansible-playbook -i hosts pg.yml --limit deb00,deb02 --list-hosts
```

Isso lista os hosts de **cada play**, depois de aplicados o `hosts:` do play e o `--limit`. Faça isso sempre **antes** de executar algo importante.

---

## 9. Inventários dinâmicos e plugins

O `ansible-inventory` é a melhor forma de **testar** inventários dinâmicos, sem executar nenhum playbook. (Os plugins de inventário foram apresentados no capítulo de plugins.)

### 9.1 Inventário de nuvem

```bash
ansible-inventory -i inventario.aws_ec2.yml --graph
ansible-inventory -i inventario.aws_ec2.yml --list
ansible-inventory -i inventario.aws_ec2.yml --host i-0abc123def4567890
```

Se a saída vier vazia, os motivos mais comuns são credenciais não configuradas, filtros muito restritos, região incorreta ou biblioteca ausente (`boto3`). Use `-v` ou `-vvv` para ver mais detalhes.

### 9.2 Inventário construído (`constructed`)

O plugin `ansible.builtin.constructed` cria **grupos e variáveis** a partir dos dados de outros inventários. Exemplo, `grupos.constructed.yml`:

```yaml
---
plugin: ansible.builtin.constructed
strict: false
groups:
  banco: "'db' in group_names"
  producao: "inventory_hostname is match('^.*-prod')"
keyed_groups:
  - prefix: so
    key: ansible_distribution | default('desconhecido')
```

```bash
ansible-inventory -i hosts -i grupos.constructed.yml --graph
```

Aqui, os dois inventários são **combinados**: o `constructed` enxerga os hosts do primeiro e adiciona grupos novos. Observe que as expressões que dependem de **facts** (como `ansible_distribution`) só funcionam se os facts estiverem em cache.

### 9.3 O formato de um inventário em script

Um **script de inventário** é um executável que responde a duas chamadas: `--list` e `--host NOME`, devolvendo JSON. O `ansible-inventory --list` produz exatamente esse formato, e é por isso que ele serve para **testar** scripts:

`inventario.py`:

```python
#!/usr/bin/env python3
import json
import sys

INVENTARIO = {
    "_meta": {
        "hostvars": {
            "app01": {"ansible_host": "10.0.0.11"},
            "app02": {"ansible_host": "10.0.0.12"},
        }
    },
    "app": {"hosts": ["app01", "app02"]},
}

if len(sys.argv) > 1 and sys.argv[1] == "--list":
    print(json.dumps(INVENTARIO))
elif len(sys.argv) > 2 and sys.argv[1] == "--host":
    print(json.dumps(INVENTARIO["_meta"]["hostvars"].get(sys.argv[2], {})))
else:
    sys.exit(1)
```

```bash
chmod +x inventario.py
ansible-inventory -i ./inventario.py --graph
ansible-inventory -i ./inventario.py --host app01
```

Com a chave `_meta.hostvars` presente, o Ansible não precisa chamar `--host` para cada host (mais rápido). Hoje, na maioria dos casos, **plugins de inventário** (por exemplo, `amazon.aws.aws_ec2`) são preferíveis a scripts, mas os scripts continuam úteis para integrações simples.

---

## 10. Convertendo e guardando retratos do inventário

### 10.1 INI para YAML

```bash
ansible-inventory -i hosts --list -y --export --output hosts.yml
```

O `hosts.yml` gerado pode ser usado diretamente com `-i hosts.yml`. Confira o resultado com:

```bash
ansible-inventory -i hosts.yml --graph
diff <(ansible-inventory -i hosts --list --export) <(ansible-inventory -i hosts.yml --list --export)
```

Se a comparação não mostra diferenças, a conversão preservou tudo.

### 10.2 Um retrato de um inventário dinâmico

Para guardar o estado de um inventário de nuvem em um dado momento (para auditoria, ou para trabalhar offline):

```bash
ansible-inventory -i inventario.aws_ec2.yml --list -y --output snapshot-2026-10-19.yml
```

O arquivo YAML gerado é um inventário estático válido (`-i snapshot-2026-10-19.yml`).

(O JSON de `--list` segue o formato de scripts de inventário, e não o de arquivos estáticos. Para guardar em JSON e reutilizar com `-i`, a forma mais simples é um pequeno script que imprime o arquivo, como o da seção 9.3.)

### 10.3 Cuidados ao converter e gravar

- O `--list` expande **variáveis** (inclusive de `group_vars` e `host_vars`). O arquivo gerado pode conter **dados sensíveis**.
- Variáveis de arquivos criptografados com Vault podem ser gravadas **em texto puro** quando a senha do Vault é fornecida (seção 11).
- Não faça commit de retratos sem revisar o conteúdo.

---

## 11. Segurança: o que o `ansible-inventory` pode revelar

Como o comando precisa ler **todas** as variáveis para mostrá-las, ele pode expor segredos:

| Origem do segredo | O que aparece |
|---|---|
| Variável em texto puro em `group_vars` | Aparece em texto puro |
| Arquivo inteiro criptografado com Vault, com a senha informada | Pode aparecer **descriptografado** na saída |
| Valor inline (`!vault \|`) | Costuma aparecer ainda criptografado (como `__ansible_vault` em JSON), dependendo da versão |
| Senhas em variáveis de inventário (`ansible_password`, `ansible_become_password`) | Aparecem em texto puro, se estiverem em texto puro |

Cuidados:

- **Não cole** a saída de `--list` ou `--host` em chats, tickets ou e-mails sem revisar.
- **Não grave** a saída em logs de CI/CD sem filtrar (use `--graph` ou `jq` para mostrar só o necessário).
- Evite `ansible_password` e `ansible_become_password` em texto puro; use chaves SSH e o Vault (ver capítulo de Vault).
- Prefira consultar valores específicos (`--host x | jq '.chave'`) a despejar tudo na tela.

---

## 12. Usando em scripts e na integração contínua

### 12.1 Com `jq`

```bash
# Quantos hosts existem
ansible-inventory -i hosts --list | jq '._meta.hostvars | length'

# Hosts diretos de um grupo
ansible-inventory -i hosts --list | jq -r '.db.hosts[]'

# Todos os nomes de grupos
ansible-inventory -i hosts --list | jq -r 'keys[] | select(. != "_meta")'

# Hosts que não definem ansible_host
ansible-inventory -i hosts --list \
  | jq -r '._meta.hostvars | to_entries[] | select(.value.ansible_host == null) | .key'

# Valor de uma variável em todos os hosts
ansible-inventory -i hosts --list \
  | jq -r '._meta.hostvars | to_entries[] | "\(.key)\t\(.value.postgresql_remote_porta // "-")"'
```

(O campo `.hosts` de um grupo lista apenas os hosts **diretos**; para incluir os de subgrupos, use `ansible NOME --list-hosts`.)

### 12.2 Validar o inventário na CI

Um inventário com erro de sintaxe faz o comando terminar com código diferente de zero:

```bash
#!/bin/sh
set -eu

# 1. O inventário carrega sem erros?
ansible-inventory -i inventory/ --list > /dev/null

# 2. Há hosts sem grupo (possível esquecimento)?
SEM_GRUPO=$(ansible-inventory -i inventory/ --list | jq -r '.ungrouped.hosts[]? // empty')
if [ -n "$SEM_GRUPO" ]; then
  echo "Hosts sem grupo: $SEM_GRUPO"
  exit 1
fi

# 3. Todo host tem ansible_host?
FALTANDO=$(ansible-inventory -i inventory/ --list \
  | jq -r '._meta.hostvars | to_entries[] | select(.value.ansible_host == null) | .key')
if [ -n "$FALTANDO" ]; then
  echo "Hosts sem ansible_host: $FALTANDO"
  exit 1
fi

echo "Inventário válido"
```

### 12.3 Com Python

```python
#!/usr/bin/env python3
"""Lista os grupos de cada host e aponta hosts sem ansible_host."""

import json
import subprocess

saida = subprocess.run(
    ["ansible-inventory", "-i", "hosts", "--list"],
    capture_output=True, text=True, check=True,
).stdout
inventario = json.loads(saida)

hostvars = inventario["_meta"]["hostvars"]
grupos = {nome: dados for nome, dados in inventario.items() if nome != "_meta"}

# Quais grupos diretos contêm cada host
por_host = {host: [] for host in hostvars}
for nome, dados in grupos.items():
    for host in dados.get("hosts", []):
        por_host[host].append(nome)

for host, lista in sorted(por_host.items()):
    aviso = "" if "ansible_host" in hostvars[host] else "  <-- sem ansible_host"
    print(f"{host}: {', '.join(sorted(lista))}{aviso}")
```

A biblioteca `ansible-runner` (capítulo anterior) também oferece uma função para obter o inventário já processado, em Python.

### 12.4 Em testes de roles e playbooks

O comando é uma ótima verificação inicial em pipelines: se o inventário não carrega, não adianta rodar o resto.

---

## 13. Exemplo completo: investigando um problema

**Cenário:** o playbook `pg.yml` roda com `hosts: db`, mas o PostgreSQL em `deb00` está usando a porta errada. Você precisa descobrir **de onde** vem o valor.

### Passo 1: o host está no grupo certo?

```bash
ansible-inventory -i inventory/ --graph db
```

```
@db:
  |--deb00
  |--rh01
```

### Passo 2: qual é o valor final da variável?

```bash
ansible-inventory -i inventory/ --host deb00 | jq '.postgresql_remote_porta'
```

```
5434
```

### Passo 3: de onde vem? (ver as variáveis por nível)

```bash
ansible-inventory -i inventory/ --graph --vars
```

Mostra a variável em cada grupo e host: `all` define 5432, `db` define 5433 e `deb00` define 5434.

### Passo 4: confirmar com os arquivos

```bash
grep -rn postgresql_remote_porta inventory/
```

```
inventory/group_vars/all.yml:3:postgresql_remote_porta: 5432
inventory/group_vars/db.yml:2:postgresql_remote_porta: 5433
inventory/host_vars/deb00.yml:2:postgresql_remote_porta: 5434
```

O `host_vars/deb00.yml` vence o grupo `db`, que vence o `all`. Era essa a explicação.

### Passo 5: confirmar quais hosts o playbook atinge

```bash
ansible-playbook -i inventory/ pg.yml --list-hosts
```

### Passo 6: resolver

Remova (ou corrija) o valor em `host_vars/deb00.yml`, e verifique:

```bash
ansible-inventory -i inventory/ --host deb00 | jq '.postgresql_remote_porta'
# 5433
```

Como a variável também pode ser sobrescrita **durante a execução** (variáveis de play, de roles e `-e`), se o inventário mostra o valor esperado mas o playbook usa outro, o problema está em outro nível. Nesse caso, continue com `debug: var=...` dentro do playbook (ver capítulo de variáveis).

---

## 14. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `[WARNING]: No inventory was parsed, only implicit localhost is available` | Caminho do inventário incorreto, ou formato não reconhecido | Conferir o `-i` e o `ansible.cfg` |
| `Unable to parse ... as an inventory source` | Sintaxe inválida em INI ou YAML | Corrigir o arquivo; testar com `-vvv` |
| Variável de `group_vars` não aparece | `group_vars/` está ao lado do playbook, não do inventário | `--playbook-dir .` |
| Host não aparece em um grupo | Erro de digitação ou seção `[grupo]` errada | `--graph` e conferir o nome |
| Subgrupo não aparece no pai | Faltou `:children` | `[pai:children]` com o nome do subgrupo |
| Valor da variável diferente do esperado | Precedência: host vence grupo; filho vence pai | `--graph --vars` e `grep` nos arquivos |
| Dois grupos conflitam na mesma variável | Mesma profundidade, vence o último em ordem alfabética | `ansible_group_priority` no arquivo de inventário |
| `ansible_group_priority` ignorado | Definido em `group_vars/` | Definir no arquivo de inventário |
| Inventário dinâmico vazio | Credenciais, filtros ou região incorretos | `-vvv` e testar o plugin separadamente |
| `--host` mostra `{}` | O host não tem variáveis, ou o nome está incorreto | Conferir com `--list` |
| `--host` não encontra o host | Nome diferente (maiúsculas, domínio) | Usar o nome exato do inventário |
| Erro ao ler arquivo criptografado | Falta a senha do Vault | `--ask-vault-password` ou `--vault-password-file` |
| Segredos apareceram na saída | `--list` e `--host` expandem as variáveis | Filtrar com `jq`, não registrar a saída |
| Saída JSON misturada com avisos | Avisos vão para `stderr` | Redirecionar `2>/dev/null` ou usar `--output` |
| Inventário em diretório lê arquivos indesejados | O Ansible lê todos os arquivos | Remover, renomear ou adicionar à lista de extensões ignoradas |
| `constructed` não cria os grupos esperados | Depende de facts ou de variáveis não carregadas | Cache de facts, ou usar variáveis do inventário |
| `--limit` não é reconhecido | A opção não existe no `ansible-inventory` | Usar `--graph NOME`, `jq` ou `--list-hosts` |
| Saída muito grande | Muitos hosts | `--graph`, ou `jq` para selecionar |

---

## 15. Boas práticas

1. **Use o `--graph` como primeiro passo** ao receber ou alterar um inventário.
2. **Use `--host` e `--graph --vars`** para depurar variáveis antes de culpar o playbook.
3. **Informe `--playbook-dir`** quando `group_vars` e `host_vars` ficam ao lado do playbook.
4. **Combine com `--list-hosts`** para saber exatamente quais hosts um padrão ou um `--limit` atinge.
5. **Estruture o inventário em diretório**, com `group_vars/` e `host_vars/`, e prefixos numéricos nos arquivos.
6. **Tenha poucos pontos de definição** para cada variável: quanto menos lugares, mais fácil de depurar a precedência.
7. **Use `--export`** ao converter ou versionar um retrato, e sem ele para saber o valor final de cada host.
8. **Valide o inventário na CI** (carrega sem erros, sem hosts sem grupo, `ansible_host` presente).
9. **Teste inventários dinâmicos** com `--graph` e `--list` antes de usar em playbooks, e confira credenciais e filtros.
10. **Não exponha a saída completa** em logs, chats ou tickets: ela pode conter segredos.
11. **Evite senhas em texto puro** no inventário (`ansible_password`); use chaves SSH e Vault.
12. **Revise os arquivos gerados** por conversões antes de versioná-los.
13. **Prefira plugins de inventário** a scripts, e use os scripts apenas para integrações simples.
14. **Nomeie os grupos de forma clara** e consistente (por função, por ambiente, por sistema), e documente a organização.
15. **Lembre-se do limite do comando:** ele mostra o inventário, não facts nem variáveis de play; para isso, use `debug` e `setup`.

---

## Resumo

| Necessidade | Comando |
|---|---|
| Ver a árvore de grupos e hosts | `ansible-inventory -i hosts --graph` |
| Ver apenas um grupo | `ansible-inventory -i hosts --graph db` |
| Ver variáveis por grupo e host | `ansible-inventory -i hosts --graph --vars` |
| Ver tudo, em JSON | `ansible-inventory -i hosts --list` |
| Ver tudo, em YAML | `ansible-inventory -i hosts --list -y` |
| Preservar onde as variáveis foram definidas | `--list --export` |
| Ver em TOML | `--list --toml` |
| Gravar em arquivo | `--list --output arquivo` |
| Variáveis de um host | `ansible-inventory -i hosts --host deb00` |
| Um valor específico | `--host deb00 \| jq '.chave'` |
| Encontrar `group_vars` ao lado do playbook | `--playbook-dir .` |
| Usar um diretório de inventário | `-i inventory/` |
| Combinar inventários | `-i hosts -i outro.yml` |
| Quais hosts um padrão seleciona | `ansible 'db:&debian' -i hosts --list-hosts` |
| Quais hosts um playbook atinge | `ansible-playbook pg.yml --list-hosts` |
| Testar inventário dinâmico | `ansible-inventory -i plugin.yml --graph` |
| Converter INI para YAML | `--list -y --export --output hosts.yml` |
| Controlar prioridade entre grupos | `ansible_group_priority` (no arquivo de inventário) |
| Contar hosts | `--list \| jq '._meta.hostvars \| length'` |
| Validar na CI | `--list > /dev/null` e verificações com `jq` |
| Arquivos criptografados | `--ask-vault-password` ou `--vault-password-file` |
| O que o comando não mostra | Facts, variáveis de play, de roles e registradas |
