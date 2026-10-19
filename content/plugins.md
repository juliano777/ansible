# Capítulo: Plugins no Ansible

## 1. O que são plugins

**Plugins** são pedaços de código que **estendem as funcionalidades do núcleo do Ansible**. Boa parte do que você já usou nos capítulos anteriores é plugin: os filtros (`default`, `regex_replace`), os lookups (`lookup('env', 'HOME')`), os tipos de conexão (SSH), o `sudo` do `become`, o formato da saída na tela, os arquivos de inventário e o cache de facts.

Cada tipo de plugin "pluga" em um ponto específico do funcionamento do Ansible:

| Você quer... | Tipo de plugin |
|---|---|
| Transformar valores em expressões Jinja2 | `filter` |
| Testar condições em expressões (`x is ...`) | `test` |
| Buscar dados externos (arquivos, variáveis de ambiente, APIs) | `lookup` |
| Mudar a saída da tela ou enviar notificações | `callback` |
| Usar outro meio de conexão com os hosts | `connection` |
| Usar outro método de elevação de privilégio | `become` |
| Montar o inventário a partir de uma fonte (nuvem, arquivo, script) | `inventory` |
| Guardar facts em cache | `cache` |
| Mudar a forma como as tasks são distribuídas | `strategy` |
| Carregar variáveis de outras fontes | `vars` |
| Executar lógica no controlador antes de chamar um módulo | `action` |
| Definir o shell usado no host remoto | `shell` |

### 1.1 Plugins × módulos

Essa é a diferença mais importante do capítulo:

| | **Módulos** | **Plugins** |
|---|---|---|
| Onde executam | No **host gerenciado** (via SSH) | Na **máquina de controle** (onde o Ansible roda) |
| Papel | **Fazer o trabalho** (instalar um pacote, copiar um arquivo) | **Estender o Ansible** (como ele conecta, formata, filtra, busca) |
| Exemplos | `copy`, `service`, `apt`, `lineinfile` | `default` (filtro), `env` (lookup), `ssh` (conexão) |
| Linguagem | Qualquer (em geral, Python) | **Python** |
| Aparecem como | Uma task (`- name: ... ansible.builtin.copy:`) | Dentro de expressões, configurações, ou nos bastidores |

Consequência prática: um plugin só tem acesso ao que existe na **máquina de controle**. Um lookup `file` lê arquivos de **lá**, e um lookup `pipe` executa comandos **lá**, não nos hosts remotos. As bibliotecas Python que um plugin exige precisam estar instaladas **no ambiente do Ansible** (por exemplo, no `venv`).

### 1.2 Como saber o que existe

```bash
# Ver os tipos aceitos pela opção -t (--type)
ansible-doc --help

# Listar os plugins de um tipo
ansible-doc -t lookup -l
ansible-doc -t filter -l
ansible-doc -t callback -l
ansible-doc -t connection -l
ansible-doc -t inventory -l

# Documentação de um plugin
ansible-doc -t lookup ansible.builtin.env
ansible-doc -t callback ansible.posix.profile_tasks
ansible-doc -t connection ansible.builtin.ssh
```

A saída do `ansible-doc` mostra a descrição, as **opções** (e como configurá-las: no `ansible.cfg`, por variável de ambiente ou por variável do Ansible), os requisitos e exemplos.

---

## 2. Onde os plugins ficam

### 2.1 Plugins embutidos e de collections

- Os plugins do núcleo ficam na collection `ansible.builtin`, dentro do `ansible-core`.
- Os demais vêm em **collections** (ver capítulo do Galaxy), em `plugins/<tipo>/`, e são chamados pelo nome completo: `community.general.json_query`, `ansible.posix.profile_tasks`.

### 2.2 Plugins locais (seus)

Você pode criar plugins no próprio projeto, em pastas com nomes padronizados, **ao lado do playbook** (ou dentro de uma role):

```
projeto/
├── pg.yml
├── ansible.cfg
├── filter_plugins/        # filtros
│   └── memoria.py
├── test_plugins/          # testes (x is ...)
│   └── redes.py
├── lookup_plugins/        # lookups
│   └── linhas_uteis.py
├── callback_plugins/      # callbacks
│   └── resumo_falhas.py
├── action_plugins/        # plugins de ação
├── connection_plugins/    # conexões
├── inventory_plugins/     # inventários
├── vars_plugins/          # variáveis
├── strategy_plugins/      # estratégias
├── cache_plugins/         # caches
├── library/               # módulos
└── module_utils/          # código compartilhado por módulos
```

Os mesmos diretórios (`filter_plugins/`, `lookup_plugins/` etc.) funcionam **dentro de uma role**, e então o plugin só fica disponível quando a role é usada.

### 2.3 Caminhos configuráveis

O Ansible também procura nos diretórios padrão do usuário e do sistema, por tipo:

| Local | Exemplo |
|---|---|
| `~/.ansible/plugins/<tipo>` | `~/.ansible/plugins/filter` |
| `/usr/share/ansible/plugins/<tipo>` | `/usr/share/ansible/plugins/lookup` |

E dá para acrescentar caminhos pelo `ansible.cfg`:

```ini
[defaults]
filter_plugins   = ./filter_plugins:~/.ansible/plugins/filter:/usr/share/ansible/plugins/filter
lookup_plugins   = ./lookup_plugins:~/.ansible/plugins/lookup:/usr/share/ansible/plugins/lookup
callback_plugins = ./callback_plugins:~/.ansible/plugins/callback:/usr/share/ansible/plugins/callback
```

Para conferir as configurações vigentes:

```bash
ansible-config dump --only-changed
ansible-config list | grep -i plugin
```

### 2.4 Nomes completos (FQCN)

Plugins de collections e os embutidos têm nome completo. É a forma recomendada:

```yaml
msg: "{{ lista | ansible.builtin.flatten }}"
msg: "{{ lookup('ansible.builtin.env', 'HOME') }}"
msg: "{{ dados | community.general.json_query('[?ativo].nome') }}"
```

Os plugins **locais** são chamados pelo nome simples (`para_gb`, `linhas_uteis`).

---

## 3. Filtros (`filter`)

Os filtros transformam valores (`{{ valor | filtro }}`). O capítulo de filtros mostrou os embutidos; aqui, como **criar** os seus.

`filter_plugins/memoria.py`:

```python
from __future__ import annotations


def para_gb(valor_mb, casas=1):
    """Converte megabytes em gigabytes."""
    return round(int(valor_mb) / 1024, int(casas))


class FilterModule(object):
    def filters(self):
        return {
            "para_gb": para_gb,
        }
```

Uso:

```yaml
msg: "{{ ansible_facts['memtotal_mb'] | para_gb }} GB"
msg: "{{ ansible_facts['memtotal_mb'] | para_gb(2) }} GB"
```

Regras:

- A classe se chama obrigatoriamente `FilterModule` e tem um método `filters()` que devolve um **dicionário** `{nome_do_filtro: função}`.
- O primeiro argumento da função é o valor à esquerda do `|`; os demais vêm entre parênteses.
- Um arquivo pode definir vários filtros.

---

## 4. Testes (`test`)

Os testes respondem **verdadeiro ou falso** em expressões com `is`: `x is defined`, `x is match(...)`, `res is failed`. Você pode criar os seus.

`test_plugins/redes.py`:

```python
from __future__ import annotations

import ipaddress


def ip_privado(valor):
    """Verdadeiro se o endereço ou a rede (CIDR) é privado."""
    try:
        return ipaddress.ip_interface(str(valor)).ip.is_private
    except ValueError:
        return False


class TestModule(object):
    def tests(self):
        return {
            "ip_privado": ip_privado,
        }
```

Uso:

```yaml
- name: Exigir redes privadas
  ansible.builtin.assert:
    that:
      - item is ip_privado
    fail_msg: "A rede {{ item }} não é privada"
  loop:
    - 192.168.1.0/24
    - 10.0.0.0/16

when: rede_cliente is ip_privado
when: rede_cliente is not ip_privado
```

A classe é `TestModule`, com o método `tests()`, no mesmo formato dos filtros.

---

## 5. Lookups (`lookup`)

Os lookups **buscam dados** na máquina de controle e os entregam ao playbook.

### 5.1 Sintaxe

```yaml
msg: "{{ lookup('ansible.builtin.env', 'HOME') }}"          # valor único
msg: "{{ query('ansible.builtin.fileglob', 'files/*.conf') }}"   # sempre uma lista
```

| Função | Retorno |
|---|---|
| `lookup(...)` | Um **texto** (listas viram texto separado por vírgulas), a menos que use `wantlist=True` |
| `query(...)` ou `q(...)` | Sempre uma **lista** (equivale a `lookup(..., wantlist=True)`) |

Use `query` quando espera uma lista (por exemplo, em um `loop`).

### 5.2 Lookups embutidos mais úteis

| Lookup | O que faz | Exemplo |
|---|---|---|
| `ansible.builtin.env` | Lê uma variável de ambiente | `lookup('ansible.builtin.env', 'USER')` |
| `ansible.builtin.file` | Lê o conteúdo de um arquivo local | `lookup('ansible.builtin.file', 'files/banner.txt')` |
| `ansible.builtin.template` | Processa um template e devolve o texto | `lookup('ansible.builtin.template', 'app.conf.j2')` |
| `ansible.builtin.pipe` | Executa um comando local e devolve a saída | `lookup('ansible.builtin.pipe', 'date +%F')` |
| `ansible.builtin.password` | Gera (e guarda) uma senha aleatória | veja a seção 5.3 |
| `ansible.builtin.first_found` | Primeiro arquivo que existir | `lookup('ansible.builtin.first_found', lista)` |
| `ansible.builtin.fileglob` | Arquivos que casam com um padrão | `query('ansible.builtin.fileglob', 'files/*.conf')` |
| `ansible.builtin.lines` | Linhas da saída de um comando | `query('ansible.builtin.lines', 'cat lista.txt')` |
| `ansible.builtin.sequence` | Sequência numérica | `query('ansible.builtin.sequence', 'start=1 end=5')` |
| `ansible.builtin.url` | Busca o conteúdo de uma URL | `lookup('ansible.builtin.url', 'https://...')` |
| `ansible.builtin.ini` | Lê um valor de um arquivo `.ini` | `lookup('ansible.builtin.ini', 'porta section=app file=app.ini')` |
| `ansible.builtin.csvfile` | Lê uma coluna de um CSV | `lookup('ansible.builtin.csvfile', 'ana file=users.csv col=1 delimiter=,')` |
| `ansible.builtin.vars` | Lê o valor de uma variável pelo nome | `lookup('ansible.builtin.vars', 'minha_var')` |
| `ansible.builtin.unvault` | Lê um arquivo criptografado com Vault | `lookup('ansible.builtin.unvault', 'files/chave.pem')` |

Para segredos, há lookups de gerenciadores externos em collections (por exemplo, `community.hashi_vault.hashi_vault`).

### 5.3 Exemplo: senha aleatória e idempotente

O lookup `password` gera uma senha **na primeira vez** e a grava em um arquivo local; nas execuções seguintes, **lê a mesma senha**. Isso mantém a idempotência:

```yaml
- name: Criar o usuário com senha gerada
  ansible.builtin.user:
    name: app
    password: "{{ lookup('ansible.builtin.password', 'credenciais/app.txt length=24 chars=ascii_letters,digits') | password_hash('sha512', 'saltfixo') }}"
  no_log: true
```

Proteja o diretório `credenciais/` (permissões restritas, fora do Git, ou criptografado).

### 5.4 Tratamento de erros

```yaml
msg: "{{ lookup('ansible.builtin.env', 'VAR_OPCIONAL', default='padrão') }}"
msg: "{{ lookup('ansible.builtin.file', 'talvez.txt', errors='ignore') }}"
```

A opção `errors` aceita `strict` (padrão), `warn` e `ignore`.

### 5.5 Cuidados com lookups

- Rodam na **máquina de controle**, **a cada avaliação** da expressão (inclusive uma vez por host).
- `lookup('pipe', ...)` executa comandos locais: cuidado ao montar o comando a partir de variáveis (use o filtro `quote`).
- Caminhos relativos são resolvidos a partir da pasta do playbook ou da role.

### 5.6 Criando um lookup

`lookup_plugins/linhas_uteis.py`: lê um arquivo e devolve as linhas, ignorando linhas vazias e comentários.

```python
from __future__ import annotations

DOCUMENTATION = """
  name: linhas_uteis
  short_description: Devolve as linhas de um arquivo, sem comentários e sem linhas vazias
  description:
    - Lê arquivos de texto da máquina de controle, na pasta files/ do playbook ou da role.
  options:
    _terms:
      description: Nomes dos arquivos a ler.
      required: true
"""

EXAMPLES = """
- ansible.builtin.debug:
    msg: "{{ query('linhas_uteis', 'redes_clientes.txt') }}"
"""

RETURN = """
  _list:
    description: Lista de linhas úteis.
    type: list
    elements: str
"""

from ansible.errors import AnsibleLookupError
from ansible.plugins.lookup import LookupBase


class LookupModule(LookupBase):
    def run(self, terms, variables=None, **kwargs):
        resultado = []
        for termo in terms:
            caminho = self.find_file_in_search_path(variables, "files", termo)
            if not caminho:
                raise AnsibleLookupError(f"Arquivo não encontrado: {termo}")
            with open(caminho, encoding="utf-8") as arquivo:
                for linha in arquivo:
                    linha = linha.strip()
                    if linha and not linha.startswith("#"):
                        resultado.append(linha)
        return resultado
```

`files/redes_clientes.txt`:

```
# Redes liberadas no pg_hba.conf
192.168.1.0/24

10.0.0.0/16
```

Uso:

```yaml
loop: "{{ query('linhas_uteis', 'redes_clientes.txt') }}"
```

Regras:

- A classe se chama `LookupModule`, herda de `LookupBase` e implementa `run(self, terms, variables=None, **kwargs)`.
- O método devolve **sempre uma lista**.
- Erros devem ser sinalizados com `AnsibleLookupError` (ou `AnsibleError`), e não com `print` ou `exit`.

---

## 6. Callbacks (`callback`)

Os callbacks **reagem a eventos** da execução (início de play, task concluída, falha, fim) para mudar a saída ou enviar notificações.

### 6.1 Tipos de callback

| Tipo | Função | Quantos |
|---|---|---|
| `stdout` | Define o **formato da saída na tela** | Apenas **um** ativo (`stdout_callback`) |
| `notification` | Envia avisos (Slack, e-mail, etc.) | Vários |
| `aggregate` | Coleta dados e mostra um resumo | Vários |

### 6.2 Habilitando

No `ansible.cfg`:

```ini
[defaults]
# Callbacks adicionais (não stdout)
callbacks_enabled = ansible.posix.profile_tasks, ansible.posix.timer

# Callback de saída (um só)
stdout_callback = ansible.builtin.default

# Formato dos resultados no callback default (ansible-core 2.13 ou superior)
callback_result_format = yaml
```

Ou por variável de ambiente:

```bash
export ANSIBLE_CALLBACKS_ENABLED=ansible.posix.profile_tasks,ansible.posix.timer
```

Em versões antigas, a opção `callbacks_enabled` se chamava `callback_whitelist`.

### 6.3 Callbacks úteis

| Callback | Tipo | O que faz |
|---|---|---|
| `ansible.builtin.default` | stdout | Saída padrão (aceita `callback_result_format = yaml`) |
| `ansible.builtin.minimal` | stdout | Saída mínima |
| `ansible.builtin.oneline` | stdout | Uma linha por resultado |
| `ansible.posix.json` | stdout | Saída em JSON (útil para processar depois) |
| `ansible.posix.debug` | stdout | Mostra `stdout` e `stderr` formatados em falhas |
| `ansible.posix.profile_tasks` | aggregate | **Tempo gasto em cada task** |
| `ansible.posix.timer` | aggregate | Tempo total da execução |
| `ansible.builtin.junit` | aggregate | Gera relatório JUnit para CI |
| `community.general.slack` | notification | Envia o resultado ao Slack |

(`ansible.posix.*` e `community.general.*` exigem as respectivas collections.)

### 6.4 Exemplo prático: descobrir o que é lento

```ini
[defaults]
callbacks_enabled = ansible.posix.profile_tasks, ansible.posix.timer
```

Ao final da execução, aparece o ranking das tasks mais demoradas, ordenadas por tempo. É a forma mais simples de achar gargalos em um playbook.

### 6.5 Criando um callback

`callback_plugins/resumo_falhas.py`: mostra, ao final, uma lista das tasks que falharam em cada host.

```python
from __future__ import annotations

DOCUMENTATION = """
  name: resumo_falhas
  type: aggregate
  short_description: Mostra um resumo das falhas no final da execução
  description:
    - Registra cada falha e imprime a lista no fim do playbook.
  requirements:
    - Habilitar em callbacks_enabled
"""

from ansible.plugins.callback import CallbackBase


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "aggregate"
    CALLBACK_NAME = "resumo_falhas"
    CALLBACK_NEEDS_ENABLED = True

    def __init__(self):
        super().__init__()
        self.falhas = []

    def v2_runner_on_failed(self, result, ignore_errors=False):
        if not ignore_errors:
            self.falhas.append((result._host.get_name(), result._task.get_name()))

    def v2_playbook_on_stats(self, stats):
        if self.falhas:
            self._display.banner("RESUMO DE FALHAS")
            for host, tarefa in self.falhas:
                self._display.display(f"{host}: {tarefa}")
```

Habilitação:

```ini
[defaults]
callbacks_enabled = resumo_falhas
```

Principais métodos (eventos) que um callback pode implementar:

| Método | Quando é chamado |
|---|---|
| `v2_playbook_on_start` | Início do playbook |
| `v2_playbook_on_play_start` | Início de cada play |
| `v2_playbook_on_task_start` | Início de cada task |
| `v2_runner_on_ok` | Task concluída com sucesso |
| `v2_runner_on_failed` | Task falhou |
| `v2_runner_on_skipped` | Task foi pulada |
| `v2_runner_on_unreachable` | Host inalcançável |
| `v2_playbook_on_stats` | Fim do playbook, com o resumo |

Cuidados: um callback não deve travar nem lançar exceções (isso derrubaria a execução), e **nunca deve imprimir segredos** presentes nos resultados. Use `self._display` para exibir mensagens, e não `print`.

---

## 7. Conexão (`connection`)

Os plugins de conexão definem **como o Ansible se comunica** com o host.

| Plugin | Uso |
|---|---|
| `ansible.builtin.ssh` | **Padrão** para Linux e Unix |
| `ansible.builtin.local` | Executa na própria máquina de controle |
| `ansible.builtin.paramiko_ssh` | SSH em Python, alternativa ao SSH do sistema |
| `ansible.builtin.winrm` | Windows (WinRM) |
| `ansible.builtin.psrp` | Windows (PowerShell Remoting) |
| `community.docker.docker` | Executa dentro de contêineres Docker |
| `ansible.netcommon.network_cli` | Equipamentos de rede por CLI |

Escolha por host, grupo ou execução:

```ini
# inventário
[locais]
localhost ansible_connection=local

[windows]
win01 ansible_connection=winrm ansible_user=Administrator
```

```bash
ansible-playbook -i hosts pg.yml -c local
```

Em um play, também se usa `connection: local`. É a base do `delegate_to: localhost` (ver capítulo de `delegate_to`).

Algumas opções do SSH, configuráveis no `ansible.cfg`:

```ini
[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

O `pipelining` reduz o número de operações SSH por task e acelera a execução (exige que o `requiretty` esteja desativado no `sudoers` dos hosts).

---

## 8. Become (`become`)

Os plugins `become` definem **como elevar privilégios**:

| Plugin | Método |
|---|---|
| `ansible.builtin.sudo` | **Padrão** |
| `ansible.builtin.su` | `su` |
| `ansible.builtin.doas` | `doas` (OpenBSD e outros) |
| `ansible.builtin.runas` | Windows |
| `ansible.builtin.pbrun`, `pfexec`, `dzdo`, `ksu`, `machinectl` | Outros ambientes |

```yaml
- name: Elevação com su
  hosts: all
  become: true
  become_method: su
  become_user: root
```

Ou por variável de inventário: `ansible_become_method=su`.

---

## 9. Inventário (`inventory`)

Os plugins de inventário **transformam uma fonte de dados em hosts e grupos**.

| Plugin | Fonte |
|---|---|
| `ansible.builtin.ini` | Arquivo no formato INI (o dos exemplos anteriores) |
| `ansible.builtin.yaml` | Arquivo YAML |
| `ansible.builtin.toml` | Arquivo TOML |
| `ansible.builtin.host_list` | Lista direta: `-i "deb00,deb02,"` |
| `ansible.builtin.script` | Script executável que imprime JSON |
| `ansible.builtin.constructed` | Cria grupos e variáveis a partir de outros dados |
| `amazon.aws.aws_ec2` | Instâncias da AWS (collection) |
| Plugins de outras nuvens e plataformas | Collections específicas (Azure, GCP, VMware, Proxmox...) |

Habilitação (opcional; os principais já vêm ativos):

```ini
[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml
```

### 9.1 Inventário em YAML

`hosts.yml`:

```yaml
---
all:
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
      children:
        debian:
        redhat:
```

### 9.2 Inventário dinâmico (exemplo: AWS)

Os arquivos de inventário de plugins de nuvem têm um nome que termina em `.aws_ec2.yml`, e declaram o plugin:

```yaml
# inventario.aws_ec2.yml
---
plugin: amazon.aws.aws_ec2
regions:
  - sa-east-1
filters:
  tag:Ambiente: producao
keyed_groups:
  - prefix: funcao
    key: tags.Funcao
```

Requer a collection `amazon.aws`, a biblioteca `boto3` e credenciais configuradas. Para conferir o resultado sem executar nada:

```bash
ansible-inventory -i inventario.aws_ec2.yml --graph
ansible-inventory -i inventario.aws_ec2.yml --list
```

Esse mesmo comando funciona para qualquer inventário e é a melhor forma de depurar grupos e variáveis.

---

## 10. Cache (`cache`)

Os plugins de cache guardam os **facts** (e dados de inventário) entre execuções (ver capítulo de facts):

```ini
[defaults]
gathering = smart
fact_caching = ansible.builtin.jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400
```

| Plugin | Onde guarda |
|---|---|
| `ansible.builtin.memory` | Na memória, só durante a execução (padrão) |
| `ansible.builtin.jsonfile` | Arquivos JSON em disco |
| `community.general.redis` | No Redis |
| `community.general.memcached` | No Memcached |

---

## 11. Estratégia (`strategy`)

Os plugins de estratégia definem **como as tasks são distribuídas** entre os hosts:

| Estratégia | Comportamento |
|---|---|
| `ansible.builtin.linear` | **Padrão**: cada task roda em todos os hosts antes de passar para a próxima |
| `ansible.builtin.free` | Cada host avança no seu ritmo, sem esperar os outros |
| `ansible.builtin.host_pinned` | Como a `free`, mas com cada host preso a um *worker* |
| `ansible.builtin.debug` | Como a `linear`, com o depurador interativo em falhas |

```yaml
- name: Atualização em ritmo livre
  hosts: all
  strategy: free
  tasks:
    - ansible.builtin.package:
        name: "*"
        state: latest
```

Cuidado: com `free`, um host pode terminar bem antes dos outros, e coisas que dependem de sincronização (como um `run_once` com resultado compartilhado) deixam de funcionar de forma previsível.

---

## 12. Plugins de ação (`action`)

Um **plugin de ação** executa **na máquina de controle**, antes (ou no lugar) do módulo. Muitos módulos que você usa são, na verdade, plugins de ação que preparam o trabalho e depois chamam um módulo remoto:

| Módulo | O que o plugin de ação faz |
|---|---|
| `ansible.builtin.copy` | Lê o arquivo local (e descriptografa, se for do Vault) e o envia ao host |
| `ansible.builtin.template` | Processa o template **localmente** e envia o resultado |
| `ansible.builtin.fetch` | Traz o arquivo do host para a máquina de controle |
| `ansible.builtin.debug`, `set_fact`, `assert`, `pause`, `include_vars` | Rodam inteiramente na máquina de controle |
| `ansible.builtin.package` | Escolhe o módulo certo (`apt`, `dnf`...) conforme o `ansible_pkg_mgr` e repassa os argumentos |

O último caso explica o comportamento visto no começo da nossa conversa: o `package` descobre o gerenciador de pacotes do host e **delega** ao módulo real, repassando parâmetros como `update_cache` (por isso funcionava, mesmo sem constar na documentação do `package`).

Escrever um plugin de ação é um recurso avançado, usado quando um módulo precisa de lógica **local** (ler arquivos, consultar APIs) antes de agir no host. Na maioria dos casos, **um módulo comum ou um lookup é suficiente**.

---

## 13. Outros tipos de plugin

| Tipo | Para quê |
|---|---|
| `vars` | Carregam variáveis de outras fontes. O plugin `ansible.builtin.host_group_vars` é o que lê `group_vars/` e `host_vars/` |
| `shell` | Definem o shell no host remoto (`sh`, `csh`, `fish`, `powershell`). Variável: `ansible_shell_type` |
| `httpapi` | Comunicação com APIs HTTP de equipamentos |
| `netconf`, `cliconf`, `terminal` | Automação de redes (NETCONF, CLI) |
| `module_utils` e `doc_fragments` | Não são plugins "executáveis", mas código e documentação **compartilhados** por módulos e plugins |

---

## 14. Configuração dos plugins

Cada plugin pode ter **opções**, documentadas no `ansible-doc`. Elas podem ser definidas de várias formas (a precedência varia conforme o plugin; a documentação de cada um indica as fontes disponíveis):

```bash
ansible-doc -t connection ansible.builtin.ssh
```

Exemplo de trecho da documentação:

```
OPTIONS (= is mandatory):
- pipelining
        Pipelining reduces the number of connection operations...
        set_via:
          ini: [{key: pipelining, section: ssh_connection}]
          env: [{name: ANSIBLE_PIPELINING}]
          vars: [{name: ansible_ssh_pipelining}]
```

Isso informa que a opção pode ser definida:

- no **`ansible.cfg`**, na seção `[ssh_connection]`, chave `pipelining`;
- por **variável de ambiente** `ANSIBLE_PIPELINING`;
- por **variável do Ansible** (inventário, `group_vars`, play) `ansible_ssh_pipelining`.

Para ver todas as configurações vigentes e de onde vieram:

```bash
ansible-config dump --only-changed
ansible-config dump | grep -i pipelining
ansible-config list
```

---

## 15. Escrevendo plugins: regras gerais

1. **Linguagem:** Python, na versão do ambiente onde o Ansible roda (a máquina de controle).
2. **Classe obrigatória, conforme o tipo:**

| Tipo | Classe | Método principal |
|---|---|---|
| `filter` | `FilterModule` | `filters()` → dicionário |
| `test` | `TestModule` | `tests()` → dicionário |
| `lookup` | `LookupModule(LookupBase)` | `run(terms, variables=None, **kwargs)` → lista |
| `callback` | `CallbackModule(CallbackBase)` | métodos `v2_*` |
| `inventory` | `InventoryModule(BaseInventoryPlugin)` | `verify_file()` e `parse()` |
| `action` | `ActionModule(ActionBase)` | `run(tmp=None, task_vars=None)` |
| `connection` | `Connection(ConnectionBase)` | vários métodos de conexão |

3. **Documente** com `DOCUMENTATION`, `EXAMPLES` e `RETURN` (em YAML, dentro de strings). Assim o plugin aparece no `ansible-doc`, e isso é exigido por collections publicadas.
4. **Trate erros** com exceções do Ansible (`AnsibleError`, `AnsibleLookupError`, `AnsibleFilterError`), com mensagens claras.
5. **Não use `print`;** use `Display` (`self._display` ou `from ansible.utils.display import Display`).
6. **Não faça nada lento ou bloqueante** em callbacks e filtros; eles rodam no caminho crítico da execução.
7. **Não vaze segredos** em mensagens, logs ou retornos.
8. **Local ou em collection:** comece com pastas locais (`filter_plugins/`), e quando for útil para outras equipes, empacote em uma collection (`plugins/filter/`; ver capítulo do Galaxy).

### 15.1 Testando um plugin

```bash
# Documentação aparece?
ansible-doc --playbook-dir . -t lookup linhas_uteis

# Filtro e teste: via debug ad-hoc
ansible localhost -m ansible.builtin.debug -a 'msg={{ 2048 | para_gb }}'

# Lookup
ansible localhost -m ansible.builtin.debug -a 'msg={{ query("linhas_uteis", "redes_clientes.txt") }}'

# Mais detalhes em caso de erro
ansible-playbook pg.yml -vvv

# Qualidade do código (em uma collection)
ansible-test sanity
```

---

## 16. Escolhendo: plugin, módulo ou outra solução

| Necessidade | Solução |
|---|---|
| Transformar um valor em uma expressão | **Filtro** |
| Testar uma condição reutilizável (`x is algo`) | **Teste** |
| Buscar dados da máquina de controle ou de um serviço externo | **Lookup** |
| Mudar a saída, medir tempos ou enviar notificações | **Callback** |
| Agir **no host gerenciado** (instalar, alterar, reiniciar) | **Módulo** |
| Lógica local seguida de ação remota | **Plugin de ação** + módulo |
| Obter hosts de uma fonte externa | **Plugin de inventário** |
| Reaproveitar um conjunto de tasks | **Role** |
| Distribuir tudo isso para outros | **Collection** |

---

## 17. Exemplo completo

Um projeto com um filtro, um teste, um lookup e um callback locais, funcionando em Debian e Red Hat.

### 17.1 Estrutura

```
projeto/
├── ansible.cfg
├── hosts
├── plugins.yml
├── files/
│   └── redes_clientes.txt
├── filter_plugins/
│   └── memoria.py
├── test_plugins/
│   └── redes.py
├── lookup_plugins/
│   └── linhas_uteis.py
└── callback_plugins/
    └── resumo_falhas.py
```

Os quatro arquivos de plugin são os das seções 3, 4, 5.6 e 6.5.

### 17.2 `ansible.cfg`

```ini
[defaults]
inventory = ./hosts
callbacks_enabled = resumo_falhas, ansible.posix.profile_tasks
callback_result_format = yaml
```

### 17.3 `files/redes_clientes.txt`

```
# Redes liberadas no PostgreSQL
192.168.1.0/24
10.0.0.0/16
```

### 17.4 `plugins.yml`

```yaml
---
- name: Demonstração de plugins locais
  hosts: all
  gather_facts: true

  vars:
    redes_clientes: "{{ query('linhas_uteis', 'redes_clientes.txt') }}"

  tasks:
    - name: Resumo do host (filtro local)
      ansible.builtin.debug:
        msg: >-
          {{ inventory_hostname }} tem
          {{ ansible_facts['memtotal_mb'] | para_gb }} GB de RAM
      tags: resumo

    - name: Exigir que todas as redes sejam privadas (teste local)
      ansible.builtin.assert:
        that:
          - item is ip_privado
        fail_msg: "A rede {{ item }} não é privada"
        quiet: true
      loop: "{{ redes_clientes }}"
      run_once: true
      tags: redes

    - name: Listar as redes lidas do arquivo (lookup local)
      ansible.builtin.debug:
        msg: "Redes: {{ redes_clientes | join(', ') }}"
      run_once: true
      tags: redes

    - name: Forçar uma falha para ver o resumo (callback local)
      ansible.builtin.fail:
        msg: "Falha simulada"
      when: simular_falha | default(false) | bool
      tags: falha
```

### 17.5 Execuções

```bash
# Normal: mostra o resumo e os tempos de cada task (profile_tasks)
ansible-playbook plugins.yml

# Só as redes
ansible-playbook plugins.yml --tags redes

# Simulando falha: o callback resumo_falhas lista as falhas no final
ansible-playbook plugins.yml -e "simular_falha=true"

# Documentação do lookup local
ansible-doc --playbook-dir . -t lookup linhas_uteis
```

### 17.6 O que cada plugin faz no exemplo

| Plugin | Onde aparece |
|---|---|
| `para_gb` (filtro) | `ansible_facts['memtotal_mb'] \| para_gb` |
| `ip_privado` (teste) | `item is ip_privado` |
| `linhas_uteis` (lookup) | `query('linhas_uteis', 'redes_clientes.txt')` |
| `resumo_falhas` (callback) | Resumo de falhas no fim da execução |
| `profile_tasks` (callback, collection `ansible.posix`) | Ranking de tempo por task |

---

## 18. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `template error ... No filter named 'x'` | O filtro local não foi encontrado | Conferir a pasta `filter_plugins/` (ao lado do playbook ou da role) e o nome no dicionário de `filters()` |
| `No test named 'x'` | Teste local não encontrado | Pasta `test_plugins/` e `TestModule.tests()` |
| `lookup plugin (x) not found` | Pasta ou nome do arquivo incorretos | `lookup_plugins/nome.py`, e conferir com `ansible-doc -t lookup -l` |
| O callback não aparece | Não foi habilitado | `callbacks_enabled` no `ansible.cfg` (ou `CALLBACK_NEEDS_ENABLED`) |
| Mais de um callback de saída | Só um `stdout_callback` é permitido | Usar `callbacks_enabled` para os demais |
| `callbacks_enabled` ignorado | Nome da opção antigo (`callback_whitelist`) em versão nova | Usar `callbacks_enabled` |
| Plugin não encontrado dentro de uma role | O plugin local da role só vale com a role em uso | Aplicar a role, ou mover o plugin para a pasta do playbook |
| `ModuleNotFoundError` em um plugin | Biblioteca Python ausente na máquina de controle | `pip install` no ambiente do Ansible |
| Lookup não acha o arquivo | Caminho relativo errado (resolve a partir do playbook ou da role) | Colocar em `files/` ou usar caminho completo |
| Lookup devolve texto em vez de lista | Uso de `lookup()` sem `wantlist=True` | Usar `query()` |
| Lookup `pipe` executa no host errado | Lookups rodam na máquina de controle | Usar `command` ou `shell` para executar no host |
| `ansible-doc` não mostra o plugin local | Falta `DOCUMENTATION` ou caminho não configurado | Documentar e verificar `ansible-config dump` |
| Erro de importação em callback | Versão do Ansible diferente do esperado | Conferir as classes e métodos na versão em uso |
| Saída muito poluída | Callback `default` sem formatação | `callback_result_format = yaml` |
| Segredo apareceu na saída | Callback ou task sem `no_log` | `no_log: true`; revisar o código do callback |
| `ansible_connection` não é aplicado | Variável no lugar errado ou precedência | `ansible-inventory --host nome` para conferir |
| `free` desordena a execução | Estratégia sem sincronização | Voltar para `linear` onde houver dependências entre hosts |

---

## 19. Boas práticas

1. **Use o que já existe antes de criar:** `ansible-doc -t <tipo> -l` e as collections cobrem a maioria dos casos.
2. **Prefira o nome completo (FQCN)** para plugins embutidos e de collections.
3. **Use filtros e testes** para lógica pequena e reutilizável nas expressões, em vez de repetir `set_fact` e condições longas.
4. **Use `query()`** sempre que esperar uma lista, e `lookup()` para um valor único.
5. **Lembre-se de que lookups e plugins rodam na máquina de controle,** com as bibliotecas **dela**.
6. **Proteja comandos em `lookup('pipe')`** com o filtro `quote`, e não monte comandos com dados não confiáveis.
7. **Habilite `profile_tasks`** em desenvolvimento para achar gargalos.
8. **Documente seus plugins** (`DOCUMENTATION`, `EXAMPLES`, `RETURN`) e comente as decisões.
9. **Trate os erros com as exceções do Ansible,** com mensagens claras.
10. **Nunca imprima nem registre segredos** em callbacks e plugins.
11. **Comece local, publique depois:** plugins em pastas do projeto, e em uma collection quando outras equipes precisarem.
12. **Teste os plugins** com comandos ad-hoc, `-vvv`, `ansible-doc` e, em collections, `ansible-test sanity`.
13. **Mantenha a compatibilidade** com as versões do `ansible-core` e do Python que o seu time usa, registrando-as na documentação.
14. **Prefira um módulo** para ações no host remoto, e deixe os plugins para estender o próprio Ansible.

---

## Resumo

| Necessidade | Tipo | Exemplo |
|---|---|---|
| Transformar valores | `filter` | `{{ x \| para_gb }}` |
| Testar condições | `test` | `x is ip_privado` |
| Buscar dados na máquina de controle | `lookup` | `query('linhas_uteis', 'arq.txt')` |
| Ler variável de ambiente | `lookup` | `lookup('ansible.builtin.env', 'HOME')` |
| Gerar senha idempotente | `lookup` | `lookup('ansible.builtin.password', 'arq length=20')` |
| Medir o tempo das tasks | `callback` | `callbacks_enabled = ansible.posix.profile_tasks` |
| Mudar o formato da saída | `callback` (stdout) | `callback_result_format = yaml` |
| Enviar notificações | `callback` | `community.general.slack` |
| Mudar o tipo de conexão | `connection` | `ansible_connection=local` |
| Mudar o método de privilégio | `become` | `become_method: su` |
| Montar inventário de uma fonte | `inventory` | `plugin: amazon.aws.aws_ec2` |
| Guardar facts | `cache` | `fact_caching = ansible.builtin.jsonfile` |
| Distribuir as tasks de outro jeito | `strategy` | `strategy: free` |
| Lógica local antes do módulo | `action` | `copy`, `template`, `package` |
| Listar plugins | CLI | `ansible-doc -t <tipo> -l` |
| Ler a documentação de um plugin | CLI | `ansible-doc -t <tipo> nome` |
| Ver as configurações vigentes | CLI | `ansible-config dump --only-changed` |
| Onde ficam os plugins locais | Pastas | `filter_plugins/`, `lookup_plugins/`, `callback_plugins/` etc. |
| Distribuir os seus plugins | Collection | `plugins/<tipo>/` |
