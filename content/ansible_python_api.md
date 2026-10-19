# Capítulo: Usando o Ansible a partir de código Python

## 1. Introdução

O Ansible é escrito em Python, e isso desperta uma pergunta natural: **dá para chamar o Ansible de dentro de um programa Python?** Dá, e é útil em situações como:

- um **portal interno** em que o usuário clica em "criar servidor" e um playbook é executado;
- um **bot de chat** que dispara automações e responde com o resultado;
- um **sistema de tickets** ou de **inventário** que aciona o Ansible a cada mudança;
- um **pipeline** ou **orquestrador** que decide, em código, o que executar e como tratar os resultados;
- **testes automatizados** do seu próprio código de automação.

Este capítulo mostra as formas **suportadas e estáveis** de fazer isso, e explica por que **não** se deve construir sobre a API interna do Ansible.

> **Pré-requisito:** conhecimento básico de Python (funções, dicionários, listas, módulos). Se o seu público não programa, este capítulo pode ser tratado como leitura opcional.

### 1.1 Uma observação importante sobre a "API do Ansible"

O Ansible possui classes internas em Python (`TaskQueueManager`, `PlaybookExecutor`, `Play`, `ansible.cli`...) que os próprios comandos `ansible` e `ansible-playbook` usam. Elas existem e podem ser importadas, mas:

- **não são uma interface pública e estável**: não há garantia de compatibilidade entre versões do `ansible-core`;
- o código escrito sobre elas **tende a quebrar** quando o Ansible é atualizado;
- exigem muitas peças (inventário, carregador de arquivos, gerenciador de variáveis, fila de tarefas, callbacks) para um resultado simples.

Por isso, a recomendação é usar uma das interfaces suportadas, apresentadas abaixo. A API interna aparece na seção 11, apenas como curiosidade.

### 1.2 Os caminhos suportados

| Caminho | O que é | Quando usar |
|---|---|---|
| **`ansible-runner`** | Biblioteca e CLI oficiais para executar o Ansible de forma programática | **Escolha principal** para integrar o Ansible a código Python |
| **`subprocess` + `ansible-playbook`** | Executar o comando e ler a saída (de preferência em JSON) | Scripts pequenos e simples |
| **API REST do AWX / Automation Platform** | Disparar *job templates* e consultar resultados via HTTP | Quando a empresa já usa AWX ou Automation Platform |
| **Escrever módulos e plugins em Python** | Estender o Ansible com código seu | Quando falta um módulo (assunto de outro capítulo) |
| API interna (`TaskQueueManager`...) | Classes internas do Ansible | **Evitar** |

O **`ansible-runner`** é a base do AWX e do Automation Platform: eles o usam por baixo para executar cada job. Aprender a usá-lo é aprender como essas plataformas funcionam.

---

## 2. Preparando o ambiente

### 2.1 Instalação

Use um ambiente virtual, como no resto do material:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install ansible-core ansible-runner
```

O `ansible-runner` **não instala o Ansible por você**: ele chama o `ansible-playbook` e o `ansible` que estiverem disponíveis no ambiente. Por isso, `ansible-core` precisa estar instalado **no mesmo ambiente** (ou no `PATH`).

Verificação:

```bash
ansible --version
ansible-runner --version
python -c "import ansible_runner; print(ansible_runner.__file__)"
```

### 2.2 O que o `ansible-runner` faz

Ele **prepara um diretório de trabalho** (chamado *private data directory*), executa o Ansible com as opções que você informou, **captura tudo** (saída, eventos, estatísticas, facts) em arquivos estruturados e devolve um objeto com o resultado. Também permite receber **eventos em tempo real**, executar em segundo plano, cancelar e rodar dentro de contêineres.

---

## 3. O `private_data_dir` e a linha de comando

### 3.1 A estrutura do diretório

```
meu_job/                      # private_data_dir
├── env/
│   ├── extravars             # variáveis extras (YAML ou JSON)
│   ├── envvars               # variáveis de ambiente
│   ├── passwords             # respostas a prompts de senha
│   ├── cmdline               # argumentos extras da linha de comando
│   ├── settings              # configurações do runner
│   └── ssh_key               # chave SSH privada
├── inventory/
│   └── hosts                 # inventário
├── project/
│   ├── pg.yml                # playbooks
│   └── roles/                # roles
└── artifacts/                # criado na execução
    └── <ident>/
        ├── stdout            # saída completa
        ├── stderr
        ├── rc                # código de retorno
        ├── status            # successful, failed...
        ├── command           # comando executado
        ├── fact_cache/       # facts coletados, por host
        └── job_events/       # um arquivo JSON por evento
```

Quase tudo é opcional: você só precisa de um playbook e de um inventário, e esses podem ser passados diretamente como argumentos Python (seção 4).

### 3.2 Uso pela linha de comando

```bash
# Executar um playbook
ansible-runner run meu_job -p pg.yml

# Executar com uma identificação própria
ansible-runner run meu_job -p pg.yml --ident execucao_001

# Um módulo avulso (equivalente ao comando "ansible")
ansible-runner run meu_job -m ansible.builtin.ping --hosts all

# Uma role
ansible-runner run meu_job --role postgresql_remote --hosts db
```

Em seguida, os resultados estão em `meu_job/artifacts/<ident>/`. O formato dos arquivos é estável, e isso permite que **qualquer programa** (em qualquer linguagem) leia a saída: `rc`, `status`, `stdout` e os eventos em JSON.

---

## 4. Executando do Python: `ansible_runner.run()`

### 4.1 O exemplo mais simples

```python
import ansible_runner

resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
)

print("Status:", resultado.status)
print("Código de retorno:", resultado.rc)
```

Isso executa `meu_job/project/pg.yml` com o inventário de `meu_job/inventory/`, mostra a saída normal do Ansible no terminal e devolve um objeto `Runner`.

### 4.2 Usando os arquivos que você já tem

Em vez de copiar tudo para dentro do `private_data_dir`, aponte o `project_dir` e o inventário para o seu projeto existente:

```python
import tempfile
from pathlib import Path

import ansible_runner

projeto = Path("/home/tux/ansible")

with tempfile.TemporaryDirectory() as tmp:
    resultado = ansible_runner.run(
        private_data_dir=tmp,
        project_dir=str(projeto),
        playbook="pg.yml",
        inventory=str(projeto / "hosts"),
        limit="deb00,deb02",
        tags="config",
        extravars={"postgresql_remote_redes_clientes": ["192.168.1.0/24"]},
        quiet=True,
    )

print(resultado.status)
```

Usar um diretório temporário como `private_data_dir` evita acumular arquivos de execuções antigas. Se precisar guardar os resultados, use uma pasta fixa e gerencie a limpeza.

### 4.3 Playbook e inventário definidos no próprio código

Para casos simples (e testes), o playbook pode ser uma **lista de dicionários** e o inventário, um **dicionário**, sem nenhum arquivo:

```python
import ansible_runner

inventario = {
    "all": {
        "hosts": {
            "localhost": {"ansible_connection": "local"},
        }
    }
}

playbook = [
    {
        "name": "Teste inline",
        "hosts": "all",
        "gather_facts": False,
        "tasks": [
            {"name": "Ping", "ansible.builtin.ping": {}},
            {"name": "Mensagem", "ansible.builtin.debug": {"msg": "Olá do Python"}},
        ],
    }
]

resultado = ansible_runner.run(
    private_data_dir="/tmp/demo",
    playbook=playbook,
    inventory=inventario,
    quiet=True,
)
print(resultado.status, resultado.stats)
```

Os dicionários seguem exatamente a estrutura do YAML: o que você escreveria em um arquivo `.yml` vira dicionário Python.

### 4.4 Executando um módulo avulso (equivalente ao `ansible`)

```python
resultado = ansible_runner.run(
    private_data_dir="/tmp/demo",
    inventory=inventario,
    host_pattern="all",
    module="ansible.builtin.command",
    module_args="hostname -f",
    quiet=True,
)
```

### 4.5 Executando uma role

```python
resultado = ansible_runner.run(
    private_data_dir="/tmp/demo",
    inventory=str(projeto / "hosts"),
    host_pattern="db",
    role="postgresql_remote",
    roles_path=[str(projeto / "roles")],
    extravars={"postgresql_remote_redes_clientes": ["192.168.1.0/24"]},
    quiet=True,
)
```

### 4.6 Principais parâmetros de `run()`

| Parâmetro | Equivale a | Descrição |
|---|---|---|
| `private_data_dir` | (diretório de trabalho) | Onde o runner guarda os arquivos e os resultados |
| `project_dir` | (pasta dos playbooks) | Usa um projeto existente em vez de `private_data_dir/project` |
| `playbook` | `pg.yml` | Caminho do playbook, ou lista de plays |
| `inventory` | `-i` | Caminho, texto ou dicionário de inventário |
| `host_pattern` | (alvo no modo ad-hoc ou role) | Padrão de hosts |
| `module`, `module_args` | `ansible -m ... -a ...` | Módulo avulso e seus argumentos |
| `role` e `roles_path` | `--role` | Executa uma role |
| `limit` | `--limit` | Restringe os hosts |
| `tags`, `skip_tags` | `--tags`, `--skip-tags` | Seleção de tasks |
| `extravars` | `-e` | Variáveis extras (dicionário) |
| `envvars` | (ambiente) | Variáveis de ambiente (dicionário) |
| `cmdline` | (texto livre) | Argumentos extras, como `"--check --diff"` |
| `verbosity` | `-v` a `-vvvvv` | Nível de detalhe (0 a 5) |
| `forks` | `-f` | Paralelismo |
| `passwords` | (prompts) | Respostas a pedidos de senha |
| `ssh_key` | `--private-key` | Conteúdo da chave SSH |
| `timeout` | (tempo máximo) | Cancela após N segundos |
| `ident` | (identificador) | Nome da pasta de artefatos da execução |
| `quiet` | (sem saída no terminal) | Não imprime a saída do Ansible |
| `event_handler` | (callback) | Função chamada a cada evento |
| `status_handler` | (callback) | Função chamada a cada mudança de estado |
| `finished_callback` | (callback) | Função chamada ao terminar |
| `cancel_callback` | (callback) | Função que, se devolver verdadeiro, cancela a execução |

A lista completa e os detalhes de cada um estão na documentação do `ansible-runner` da versão que você instalou.

### 4.7 Outras funções úteis da biblioteca

Além de `run()`, o módulo oferece, entre outras:

| Função | Para quê |
|---|---|
| `run_async()` | Executa em segundo plano (seção 7) |
| `run_command()` | Executa outros comandos do ecossistema Ansible (`ansible-doc`, `ansible-galaxy`...) |
| `get_inventory()` | Obtém o inventário já processado |
| `get_ansible_config()` | Lista as configurações do Ansible |
| `get_plugin_docs()`, `get_plugin_list()` | Documentação e listas de plugins |
| `get_role_list()`, `get_role_argspec()` | Informações sobre roles |

(Os nomes e a disponibilidade podem variar entre versões; consulte a documentação instalada.)

---

## 5. Lendo o resultado

`ansible_runner.run()` devolve um objeto `Runner` com tudo o que aconteceu.

### 5.1 Status e código de retorno

```python
resultado.status   # "successful", "failed", "canceled" ou "timeout"
resultado.rc       # código de retorno do ansible-playbook
```

| `status` | Significado |
|---|---|
| `successful` | Terminou sem falhas |
| `failed` | Terminou com falha em algum host, ou erro |
| `canceled` | Foi cancelado (por `cancel_callback` ou por você) |
| `timeout` | Passou do tempo máximo (`timeout`) |

| `rc` | Significado |
|---|---|
| `0` | Sucesso |
| `2` | Falha em um ou mais hosts |
| Outros valores diferentes de zero | Erro de sintaxe, host inalcançável, interrupção ou erro inesperado |

Os valores exatos dos códigos intermediários variam entre versões. Para decisões em código, prefira usar `status` e as estatísticas.

### 5.2 Estatísticas por host (`stats`)

```python
resultado.stats
```

```python
{
    "ok":        {"deb00": 8, "deb02": 8},
    "changed":   {"deb00": 2},
    "failures":  {"deb02": 1},
    "dark":      {},          # hosts inalcançáveis (unreachable)
    "skipped":   {"deb00": 1},
    "rescued":   {},
    "ignored":   {},
    "processed": {"deb00": 1, "deb02": 1},
}
```

É o mesmo resumo do `PLAY RECAP`, em um dicionário organizado **por tipo de contagem** e, dentro de cada tipo, **por host**. Um host que não teve falhas simplesmente não aparece em `failures`.

Exemplo de uso:

```python
falharam = list(resultado.stats["failures"])
inalcancaveis = list(resultado.stats["dark"])

if falharam or inalcancaveis:
    print("Com problemas:", falharam + inalcancaveis)
```

### 5.3 A saída completa

```python
texto = resultado.stdout.read()
```

`resultado.stdout` é um objeto parecido com um arquivo. Os mesmos dados ficam gravados em `artifacts/<ident>/stdout`.

### 5.4 Facts

Se o play coletou facts (`gather_facts: true`), o runner os guarda em cache e você pode lê-los depois da execução:

```python
facts = resultado.get_fact_cache("deb00")
print(facts.get("ansible_distribution"))
```

### 5.5 Uma função que resume tudo

```python
def executar_playbook(**parametros):
    """Executa o playbook e devolve um resumo em dicionário."""
    resultado = ansible_runner.run(quiet=True, **parametros)
    return {
        "status": resultado.status,
        "rc": resultado.rc,
        "ok": sorted(resultado.stats.get("ok", {})),
        "alterados": sorted(resultado.stats.get("changed", {})),
        "falhas": sorted(resultado.stats.get("failures", {})),
        "inalcancaveis": sorted(resultado.stats.get("dark", {})),
    }
```

Esse dicionário é fácil de transformar em JSON para devolver em uma API, ou em uma mensagem para um bot.

---

## 6. Eventos: acompanhando a execução

Cada acontecimento (início de play, início de task, resultado em um host, fim) gera um **evento**: um dicionário com os detalhes. É a forma de reagir **durante** a execução e de ler os dados que as tasks produziram.

### 6.1 Percorrendo os eventos depois do fim

```python
for evento in resultado.events:
    print(evento["event"], evento.get("event_data", {}).get("host"))
```

Também é possível filtrar por host:

```python
for evento in resultado.host_events("deb00"):
    ...
```

### 6.2 Tratando eventos em tempo real

```python
def tratar_evento(evento):
    tipo = evento.get("event")
    dados = evento.get("event_data", {})

    if tipo == "playbook_on_task_start":
        print(f"==> {dados.get('task')}")
    elif tipo == "runner_on_ok":
        print(f"    ok: {dados.get('host')}")
    elif tipo == "runner_on_failed":
        print(f"    FALHA: {dados.get('host')}")
    return True   # True: o evento continua sendo gravado em disco


resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    event_handler=tratar_evento,
    quiet=True,
)
```

A função recebe o evento assim que ele ocorre. Se ela devolver `False`, o evento **não** é gravado em `job_events/`.

### 6.3 Principais tipos de evento

| Evento | Quando ocorre |
|---|---|
| `playbook_on_start` | Início do playbook |
| `playbook_on_play_start` | Início de cada play |
| `playbook_on_task_start` | Início de cada task |
| `runner_on_start` | Uma task começa em um host |
| `runner_on_ok` | Task concluída com sucesso em um host |
| `runner_on_failed` | Task falhou em um host |
| `runner_on_skipped` | Task pulada em um host |
| `runner_on_unreachable` | Host inalcançável |
| `runner_item_on_ok`, `runner_item_on_failed` | Resultado de cada item de um `loop` |
| `playbook_on_stats` | Fim do playbook, com o resumo |
| `verbose` | Mensagens detalhadas (`-v`) |

### 6.4 O que há dentro de um evento

```python
{
    "event": "runner_on_ok",
    "uuid": "...",
    "counter": 12,
    "created": "2026-10-09T12:34:56.789",
    "stdout": "ok: [deb00]",
    "event_data": {
        "host": "deb00",
        "task": "Obter o hostname",
        "play": "Exemplo",
        "role": "postgresql_remote",       # quando a task vem de uma role
        "task_action": "ansible.builtin.command",
        "res": {                           # o resultado do módulo
            "changed": False,
            "stdout": "deb00.exemplo.com",
            "rc": 0,
        },
    },
}
```

O campo `res` é o **mesmo resultado** que uma variável registrada teria (o dicionário que você viu no capítulo de `register`). Isso permite ler dados produzidos pelo playbook diretamente no Python.

### 6.5 Exemplo: coletar a saída de um comando de cada host

```python
import ansible_runner

hostnames = {}


def coletar(evento):
    dados = evento.get("event_data", {})
    if evento.get("event") == "runner_on_ok" and dados.get("task") == "Obter o hostname":
        hostnames[dados["host"]] = dados["res"]["stdout"]
    return True


playbook = [
    {
        "hosts": "all",
        "gather_facts": False,
        "tasks": [
            {
                "name": "Obter o hostname",
                "ansible.builtin.command": "hostname -f",
                "changed_when": False,
            }
        ],
    }
]

ansible_runner.run(
    private_data_dir="/tmp/demo",
    playbook=playbook,
    inventory="/home/tux/ansible/hosts",    # caminho completo do inventário
    event_handler=coletar,
    quiet=True,
)

print(hostnames)
# {'deb00': 'deb00.exemplo.com', 'deb02': 'deb02.exemplo.com'}
```

Esse é o mesmo exercício do início do material (capturar a saída de um comando), agora com o resultado disponível como dicionário Python.

### 6.6 Exemplo: relatório de falhas

```python
falhas = []


def registrar_falhas(evento):
    tipo = evento.get("event")
    dados = evento.get("event_data", {})
    if tipo in ("runner_on_failed", "runner_on_unreachable"):
        falhas.append(
            {
                "host": dados.get("host"),
                "task": dados.get("task"),
                "motivo": dados.get("res", {}).get("msg", "sem mensagem"),
            }
        )
    return True
```

### 6.7 Cuidados com eventos e dados sensíveis

- Tasks com `no_log: true` têm o campo `res` **censurado** nos eventos, o que protege segredos.
- Tasks **sem** `no_log` expõem os parâmetros e os resultados completos nos eventos, nos arquivos `job_events/` e no `stdout`.
- O seu `event_handler` **não deve** gravar em log o evento inteiro sem filtrar.

---

## 7. Execução em segundo plano, cancelamento e tempo limite

### 7.1 Em segundo plano: `run_async()`

```python
thread, runner = ansible_runner.run_async(
    private_data_dir="meu_job",
    playbook="pg.yml",
    quiet=True,
)

# ... o programa continua fazendo outras coisas ...
print("Status parcial:", runner.status)

thread.join()                    # aguarda o fim
print("Final:", runner.status, runner.rc)
```

É o que um serviço web usa para disparar um job e responder logo ao usuário, consultando o andamento depois.

### 7.2 Acompanhando as mudanças de estado

```python
def ao_mudar_estado(dados_status, configuracao):
    print("Estado:", dados_status["status"])   # starting, running, successful, failed...


ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    status_handler=ao_mudar_estado,
    finished_callback=lambda runner: print("Terminou:", runner.status),
    quiet=True,
)
```

### 7.3 Cancelando

O `cancel_callback` é consultado periodicamente; se devolver `True`, a execução é cancelada:

```python
import time

inicio = time.time()


def deve_cancelar():
    return time.time() - inicio > 300      # cancela depois de 5 minutos


resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    cancel_callback=deve_cancelar,
    quiet=True,
)
print(resultado.status)    # "canceled"
```

### 7.4 Tempo máximo

```python
resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    timeout=600,                           # segundos
    quiet=True,
)
print(resultado.status)    # "timeout" se estourar
```

---

## 8. Credenciais, Vault e segurança

### 8.1 Variáveis de ambiente

```python
resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    envvars={
        "ANSIBLE_VAULT_PASSWORD_FILE": "/etc/automacao/.vault_pass",
        "ANSIBLE_NOCOLOR": "1",
    },
    quiet=True,
)
```

Evite "resolver" problemas de SSH desativando a verificação de chaves de host (`ANSIBLE_HOST_KEY_CHECKING=False`) em automações reais: isso elimina a proteção contra servidores falsos. Registre as chaves dos hosts no `known_hosts` do usuário de serviço.

### 8.2 Chave SSH

```python
chave = Path("/etc/automacao/id_ed25519").read_text()

resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    ssh_key=chave,
    quiet=True,
)
```

O runner grava a chave em um arquivo temporário com permissões restritas durante a execução.

### 8.3 Senhas solicitadas (`passwords`)

O parâmetro `passwords` associa **expressões regulares dos prompts** às respostas:

```python
resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    cmdline="--ask-become-pass",
    passwords={r"^BECOME password.*:\s*?$": senha_sudo},
    quiet=True,
)
```

Funciona, mas para automação o ideal é **evitar prompts**: use chaves SSH e um usuário com `sudo` sem senha (`NOPASSWD`) restrito aos comandos necessários, e o `ANSIBLE_VAULT_PASSWORD_FILE` para o Vault.

### 8.4 Onde os segredos podem vazar

| Origem | O que fazer |
|---|---|
| `extravars` com senhas | Ficam gravadas em `env/extravars` e nos artefatos; evite, ou use diretório temporário que será apagado |
| `stdout` e `job_events` | Contêm a saída de tasks sem `no_log`; use `no_log: true` e proteja os artefatos |
| Logs do seu programa | Não registre eventos nem `extravars` inteiros |
| Arquivos de senha | Permissões restritas (`600`), fora do Git |
| Variáveis de ambiente | Podem aparecer em listagens de processos; prefira arquivos de senha |

### 8.5 Boas práticas de segurança

- **Valide qualquer dado vindo de usuários** antes de passá-lo como `extravars`, `limit`, `tags` ou `cmdline` (tipo, tamanho, lista de valores permitidos). Um valor malicioso em `limit` pode fazer o playbook atingir hosts que não deveria.
- **Nunca monte `cmdline` por concatenação** com texto do usuário.
- Execute com um **usuário de serviço dedicado**, com o mínimo de permissões.
- **Apague** os diretórios de artefatos que contenham dados sensíveis (`tempfile.TemporaryDirectory()`).
- Aplique `no_log: true` nas tasks que manipulam segredos (ver capítulo de Vault).

---

## 9. Contêineres e *execution environments*

O `ansible-runner` pode executar o Ansible **dentro de um contêiner**, usando uma imagem que já contém o `ansible-core`, as collections e as bibliotecas Python necessárias (os chamados *execution environments*). Isso garante que o código roda **da mesma forma** em qualquer máquina.

```python
resultado = ansible_runner.run(
    private_data_dir="meu_job",
    playbook="pg.yml",
    process_isolation=True,
    process_isolation_executable="podman",       # ou "docker"
    container_image="registro.exemplo.com/ee-minha-empresa:1.0",
    quiet=True,
)
```

Vantagens: ambiente reproduzível, sem conflito de versões de Python e de collections com o resto do sistema. A imagem costuma ser construída com a ferramenta `ansible-builder`, e a execução manual, com o `ansible-navigator`. Os detalhes de construção das imagens fogem do escopo deste capítulo.

---

## 10. Outros caminhos suportados

### 10.1 `subprocess` com `ansible-playbook`

Para um script pequeno, chamar o comando e ler a saída em JSON basta:

```python
import json
import os
import subprocess

ambiente = {
    **os.environ,
    "ANSIBLE_STDOUT_CALLBACK": "ansible.posix.json",
    "ANSIBLE_NOCOLOR": "1",
}

processo = subprocess.run(
    ["ansible-playbook", "-i", "hosts", "pg.yml", "--limit", "deb00,deb02"],
    capture_output=True,
    text=True,
    env=ambiente,
    timeout=900,
    check=False,
)

if processo.returncode == 0:
    print("Sucesso")

try:
    dados = json.loads(processo.stdout)
    for host, contagem in dados["stats"].items():
        print(host, contagem)
except json.JSONDecodeError:
    print("Saída não é JSON; veja o erro:")
    print(processo.stderr or processo.stdout)
```

Pontos de atenção:

- O callback `ansible.posix.json` exige a collection `ansible.posix`.
- Passe os argumentos **como lista**, **nunca** como uma string única com `shell=True`: isso evita injeção de comandos.
- A saída JSON só é válida se **nada mais** for impresso em `stdout`. Avisos e erros costumam ir para `stderr`.
- Sempre defina `timeout` e examine o `returncode`.

Comparado ao `ansible-runner`, falta o tratamento de eventos em tempo real, o cancelamento limpo e a organização dos artefatos.

### 10.2 API REST do AWX ou do Automation Platform

Se a sua empresa já usa o AWX ou o Automation Platform, o Python **não executa o Ansible**: apenas dispara um *job template* e consulta o resultado.

```python
import time

import requests

BASE = "https://awx.exemplo.com/api/v2"
CABECALHOS = {"Authorization": f"Bearer {TOKEN}"}

# 1. Disparar o job template
resposta = requests.post(
    f"{BASE}/job_templates/42/launch/",
    headers=CABECALHOS,
    json={"extra_vars": {"postgresql_remote_redes_clientes": ["192.168.1.0/24"]},
          "limit": "deb00"},
    timeout=30,
)
resposta.raise_for_status()
job_id = resposta.json()["id"]

# 2. Acompanhar o andamento
while True:
    job = requests.get(f"{BASE}/jobs/{job_id}/", headers=CABECALHOS, timeout=30).json()
    if job["status"] in ("successful", "failed", "error", "canceled"):
        break
    time.sleep(5)

print("Resultado:", job["status"])

# 3. Ler a saída
saida = requests.get(f"{BASE}/jobs/{job_id}/stdout/?format=txt", headers=CABECALHOS, timeout=30)
print(saida.text)
```

Observações:

- O prefixo da API (`/api/v2`) e a autenticação variam conforme a plataforma e a versão (AWX, Automation Platform 2.4, 2.5...). Consulte a documentação da sua instalação.
- O *job template* precisa permitir `extra_vars` e `limit` na execução ("Prompt on launch") para aceitar esses parâmetros.
- A própria comunidade Ansible oferece a collection `awx.awx` (e a `ansible.controller`), com módulos que fazem essas chamadas de dentro de um playbook.
- A CLI `awx` e a biblioteca `awxkit` também existem para esse fim.

### 10.3 Resumo da escolha

| Situação | Caminho |
|---|---|
| Integração de médio e grande porte, com eventos e cancelamento | `ansible-runner` |
| Script rápido e pontual | `subprocess` |
| A empresa já usa AWX ou Automation Platform | API REST |
| Falta um módulo e a lógica precisa rodar **no host** | Escrever um módulo |
| Falta um comportamento **no controlador** (filtro, lookup, callback) | Escrever um plugin (capítulo anterior) |

---

## 11. A API interna (somente para conhecer)

Por completude, segue um esboço do que seria executar um play usando as classes internas, no estilo do exemplo da documentação da *Python API*:

```python
from ansible import context
from ansible.executor.task_queue_manager import TaskQueueManager
from ansible.inventory.manager import InventoryManager
from ansible.module_utils.common.collections import ImmutableDict
from ansible.parsing.dataloader import DataLoader
from ansible.playbook.play import Play
from ansible.plugins.callback import CallbackBase
from ansible.vars.manager import VariableManager


class Coletor(CallbackBase):
    def v2_runner_on_ok(self, result, **kwargs):
        print(result._host.get_name(), "->", result._result.get("ping"))


context.CLIARGS = ImmutableDict(
    connection="local", forks=5, become=None, become_method=None,
    become_user=None, check=False, diff=False, verbosity=0,
)

carregador = DataLoader()
inventario = InventoryManager(loader=carregador, sources=["localhost,"])
variaveis = VariableManager(loader=carregador, inventory=inventario)

play = Play().load(
    {
        "name": "teste",
        "hosts": "localhost",
        "gather_facts": "no",
        "tasks": [{"action": {"module": "ansible.builtin.ping"}}],
    },
    variable_manager=variaveis,
    loader=carregador,
)

tqm = TaskQueueManager(
    inventory=inventario, variable_manager=variaveis, loader=carregador,
    passwords={}, stdout_callback=Coletor(),
)
try:
    tqm.run(play)
finally:
    tqm.cleanup()
    carregador.cleanup_all_tmp_files()
```

Repare no volume de peças para executar **uma única task de ping**: carregador de arquivos, inventário, gerenciador de variáveis, play, fila de tarefas, callback, limpeza. Os nomes, os argumentos e o comportamento desses objetos mudam entre versões do `ansible-core`, e o exemplo acima serve como ilustração: pode exigir ajustes na sua versão.

**Não use esse caminho em produção.** O `ansible-runner` faz o mesmo (e muito mais) sobre uma interface estável.

---

## 12. Exemplo completo: um executor de playbooks em Python

Um script de linha de comando que executa o `pg.yml` do projeto (a role `postgresql_remote` dos capítulos anteriores), mostra o progresso em tempo real, valida a entrada e termina com um resumo e um código de saída adequado, para uso em pipelines.

### 12.1 `executar_pg.py`

```python
#!/usr/bin/env python3
"""Executa o playbook pg.yml com ansible-runner e mostra um resumo."""

from __future__ import annotations

import argparse
import ipaddress
import re
import sys
import tempfile
from pathlib import Path

import ansible_runner

PROJETO = Path("/home/tux/ansible")
PADRAO_LIMIT = re.compile(r"^[A-Za-z0-9_.,\-]+$")   # nomes de hosts e grupos, separados por vírgula


def validar_redes(valores: list[str]) -> list[str]:
    """Aceita apenas redes CIDR privadas válidas."""
    redes = []
    for valor in valores:
        try:
            rede = ipaddress.ip_network(valor, strict=False)
        except ValueError:
            raise SystemExit(f"Rede inválida: {valor}")
        if not rede.is_private:
            raise SystemExit(f"A rede {valor} não é privada")
        redes.append(str(rede))
    return redes


def criar_manipulador(falhas: list[dict]):
    """Cria o tratador de eventos: mostra o progresso e registra as falhas."""

    def tratar(evento: dict) -> bool:
        tipo = evento.get("event")
        dados = evento.get("event_data", {})

        if tipo == "playbook_on_task_start":
            print(f"==> {dados.get('task')}")
        elif tipo == "runner_on_ok":
            alterado = dados.get("res", {}).get("changed")
            print(f"    {'alterado' if alterado else 'ok':9} {dados.get('host')}")
        elif tipo in ("runner_on_failed", "runner_on_unreachable"):
            motivo = dados.get("res", {}).get("msg", "sem mensagem")
            print(f"    FALHA     {dados.get('host')}: {motivo}")
            falhas.append(
                {"host": dados.get("host"), "task": dados.get("task"), "motivo": motivo}
            )
        return True

    return tratar


def main() -> int:
    parser = argparse.ArgumentParser(description="Libera o PostgreSQL para redes de clientes")
    parser.add_argument("--rede", action="append", required=True, help="rede CIDR (pode repetir)")
    parser.add_argument("--limit", default="db", help="hosts ou grupos (padrão: db)")
    parser.add_argument("--tags", default=None, help="tags a executar")
    parser.add_argument("--check", action="store_true", help="apenas simular (--check --diff)")
    args = parser.parse_args()

    if not PADRAO_LIMIT.match(args.limit):
        raise SystemExit("Valor de --limit contém caracteres não permitidos")

    redes = validar_redes(args.rede)
    falhas: list[dict] = []

    with tempfile.TemporaryDirectory(prefix="runner_") as tmp:
        resultado = ansible_runner.run(
            private_data_dir=tmp,
            project_dir=str(PROJETO),
            playbook="pg.yml",
            inventory=str(PROJETO / "hosts"),
            limit=args.limit,
            tags=args.tags,
            extravars={"postgresql_remote_redes_clientes": redes},
            envvars={"ANSIBLE_VAULT_PASSWORD_FILE": "/etc/automacao/.vault_pass"},
            cmdline="--check --diff" if args.check else None,
            event_handler=criar_manipulador(falhas),
            timeout=1800,
            quiet=True,
        )

    # Resumo final
    print("\n=== RESUMO ===")
    print(f"Status: {resultado.status} (rc={resultado.rc})")
    for tipo in ("ok", "changed", "failures", "dark", "skipped"):
        hosts = resultado.stats.get(tipo, {})
        if hosts:
            detalhes = ", ".join(f"{h}={n}" for h, n in sorted(hosts.items()))
            print(f"{tipo:9}: {detalhes}")

    if falhas:
        print("\nFalhas:")
        for falha in falhas:
            print(f" - {falha['host']} | {falha['task']} | {falha['motivo']}")

    return 0 if resultado.status == "successful" else 1


if __name__ == "__main__":
    sys.exit(main())
```

### 12.2 Pontos de atenção do exemplo

- **Validação de entrada:** as redes são verificadas com o módulo `ipaddress` (válidas e privadas), e o `--limit` passa por uma expressão regular. Os dados nunca chegam ao Ansible sem validação.
- **Diretório temporário:** o `private_data_dir` é apagado ao fim, junto com os artefatos (que podem conter dados sensíveis).
- **Vault por arquivo:** a senha vem de um arquivo com permissão restrita, e não de prompt.
- **`--check --diff` opcional:** a simulação reaproveita todo o resto do fluxo.
- **Progresso em tempo real:** o `event_handler` imprime o andamento de cada task e host, e registra as falhas.
- **Código de saída:** `0` se tudo correu bem, `1` em caso de falha, o que permite usar o script em um pipeline.
- **Usuário e privilégios:** o script pressupõe um usuário de automação com chave SSH e `sudo` sem senha nos hosts, sem prompts.

### 12.3 Execuções

```bash
# Simular
python executar_pg.py --rede 192.168.1.0/24 --check

# Aplicar em dois hosts
python executar_pg.py --rede 192.168.1.0/24 --rede 10.0.0.0/16 --limit deb00,deb02

# Só a parte de configuração
python executar_pg.py --rede 192.168.1.0/24 --tags config

# Uso em pipeline
python executar_pg.py --rede 192.168.1.0/24 && echo "Concluído" || echo "Falhou"
```

---

## 13. Testando o código que usa o Ansible

Como o `ansible-runner` aceita playbook e inventário como estruturas Python e permite `connection: local`, é fácil testar a sua integração **sem nenhum servidor**.

### 13.1 Teste com `pytest` e `localhost`

```python
import ansible_runner

INVENTARIO = {"all": {"hosts": {"localhost": {"ansible_connection": "local"}}}}


def executar(tasks, tmp_path, **kwargs):
    playbook = [{"hosts": "all", "gather_facts": False, "tasks": tasks}]
    return ansible_runner.run(
        private_data_dir=str(tmp_path),
        playbook=playbook,
        inventory=INVENTARIO,
        quiet=True,
        **kwargs,
    )


def test_ping_local(tmp_path):
    resultado = executar([{"ansible.builtin.ping": {}}], tmp_path)
    assert resultado.status == "successful"
    assert resultado.stats["ok"]["localhost"] == 1


def test_falha_e_detectada(tmp_path):
    resultado = executar([{"ansible.builtin.fail": {"msg": "erro de teste"}}], tmp_path)
    assert resultado.status == "failed"
    assert "localhost" in resultado.stats["failures"]


def test_eventos_trazem_o_resultado(tmp_path):
    coletados = []

    def tratar(evento):
        if evento.get("event") == "runner_on_ok":
            coletados.append(evento["event_data"]["res"])
        return True

    executar(
        [{"ansible.builtin.command": "echo ola", "changed_when": False}],
        tmp_path,
        event_handler=tratar,
    )
    assert coletados[0]["stdout"] == "ola"
```

O `tmp_path` do `pytest` fornece um diretório temporário para cada teste.

### 13.2 O que testar

| Caso | Verificação |
|---|---|
| Playbook converge | `status == "successful"` |
| Falhas são detectadas | `status == "failed"` e `stats["failures"]` |
| Seu tratador de eventos | Passe eventos de exemplo (dicionários) diretamente à função |
| Validação de entrada | Chame a função de validação com valores válidos e inválidos |
| Idempotência | Execute duas vezes e confirme `changed` vazio na segunda |
| Tempo limite e cancelamento | Use `timeout` curto com uma task `pause` ou `wait_for` |

### 13.3 Testando a função de eventos isoladamente

Como `tratar(evento)` é uma função comum, ela pode ser testada **sem executar o Ansible**:

```python
def test_falha_registrada():
    falhas = []
    tratar = criar_manipulador(falhas)

    tratar({
        "event": "runner_on_failed",
        "event_data": {"host": "deb00", "task": "Reiniciar", "res": {"msg": "falhou"}},
    })

    assert falhas == [{"host": "deb00", "task": "Reiniciar", "motivo": "falhou"}]
```

---

## 14. Ideias de integração

| Integração | Como |
|---|---|
| **Portal web** (Flask, FastAPI, Django) | Endpoint que chama `run_async()`, devolve o identificador e outro endpoint consulta o `status` e os eventos |
| **Bot de chat** (Slack, Teams, Telegram) | Comando que valida parâmetros, executa o playbook e responde com o resumo (`stats`) |
| **Sistema de tickets** | Webhook que, ao aprovar um chamado, executa uma automação e registra o resultado |
| **Pipeline CI/CD** | Script como o da seção 12, com código de saída |
| **Inventário dinâmico** | Programa que lê um CMDB e gera o dicionário de `inventory` |
| **Relatórios** | Execução agendada que usa `stats` e `get_fact_cache()` para montar planilhas |
| **Orquestração com lógica** | Python decide a sequência (por exemplo, atualizar o banco e só depois a aplicação), e chama o Ansible a cada etapa |

Em integrações web, **nunca** execute o playbook na própria requisição HTTP: use `run_async()` ou uma fila de tarefas (como Celery ou RQ), para não prender o servidor.

---

## 15. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `ansible-playbook: command not found` | `ansible-core` não está no ambiente em que o runner executa | Instalar no mesmo `venv` ou ajustar o `PATH` |
| `ModuleNotFoundError: ansible_runner` | Biblioteca não instalada neste ambiente | `pip install ansible-runner` |
| O playbook não é encontrado | O caminho é relativo a `private_data_dir/project` | Usar `project_dir` ou colocar o playbook em `project/` |
| O inventário não é carregado | Caminho incorreto, ou inventário esperado em `inventory/` | Informar `inventory=` com o caminho completo ou o dicionário |
| Saída de Ansible aparece no terminal | `quiet` não foi definido | `quiet=True` |
| `status` é `failed`, mas não sei o motivo | Os detalhes estão nos eventos e no `stdout` | Ler `runner_on_failed` e `resultado.stdout.read()` |
| Prompts travam a execução | O playbook pede senha ou confirmação (`vars_prompt`, `-K`) | Passar valores por `extravars` e `passwords`, ou eliminar o prompt |
| `event_handler` não é chamado | A função lançou exceção ou o tipo de evento está incorreto | Tratar exceções e conferir o nome do evento |
| `res` vem censurado | A task tem `no_log: true` | Esperado; use outro meio para obter o dado, sem expor segredos |
| Pasta de artefatos cresce sem parar | Execuções acumulando em um diretório fixo | Diretório temporário ou limpeza periódica |
| Segredos apareceram nos artefatos | `extravars` e tasks sem `no_log` | Evitar segredos em `extravars`, usar `no_log` e apagar os artefatos |
| Dois jobs usam o mesmo diretório e se misturam | Mesmo `private_data_dir` e `ident` | `ident` único por execução, ou um diretório por job |
| O programa trava ao executar no servidor web | Playbook executado dentro da requisição | `run_async()` ou fila de tarefas |
| Collections não são encontradas | Ambiente do runner sem as collections | Instalar com `ansible-galaxy` no mesmo ambiente, ou usar um *execution environment* |
| Resultado diferente de executar no terminal | Variáveis de ambiente, `ansible.cfg` ou diretório de trabalho diferentes | Definir `envvars` e `project_dir`, e conferir qual `ansible.cfg` é lido |
| `json.JSONDecodeError` no `subprocess` | Saída contém algo além do JSON | Ver `stderr`, desativar avisos, ou usar o `ansible-runner` |

---

## 16. Boas práticas

1. **Prefira o `ansible-runner`** a chamar a API interna do Ansible; ele é a interface suportada e estável.
2. **Use `subprocess` apenas para scripts pequenos**, sempre com lista de argumentos (nunca `shell=True` com dados de fora), `timeout` e verificação do `returncode`.
3. **Valide toda entrada de usuário** antes de passar a `extravars`, `limit`, `tags` e `cmdline`.
4. **Use diretórios temporários** para `private_data_dir`, e apague os artefatos que tenham dados sensíveis.
5. **Evite segredos em `extravars`;** use Vault, arquivos de senha com permissão restrita e `no_log: true`.
6. **Elimine prompts** (chaves SSH, `sudo` sem senha restrito, arquivo de senha do Vault): automação não deve esperar por entrada humana.
7. **Use `event_handler`** para acompanhar o progresso e coletar resultados, em vez de interpretar o texto do `stdout`.
8. **Decida com `status` e `stats`,** e não com a leitura de texto da saída.
9. **Use `run_async()`, `timeout` e `cancel_callback`** em serviços e integrações web.
10. **Dê um `ident` único** a cada execução, para rastrear e auditar.
11. **Execute com um usuário de serviço dedicado** e com o mínimo de privilégios.
12. **Considere *execution environments*** para que o código rode de forma idêntica em qualquer máquina.
13. **Teste a integração** com `pytest`, inventário `localhost` e playbooks inline; teste as funções de tratamento de eventos isoladamente.
14. **Mantenha o playbook como fonte da lógica:** o Python orquestra e trata resultados, mas as regras de configuração continuam em playbooks e roles.
15. **Registre (em log) o que foi executado**, por quem e com quais parâmetros (sem segredos), para auditoria.

---

## Resumo

| Necessidade | Solução |
|---|---|
| Executar um playbook de dentro do Python | `ansible_runner.run(private_data_dir=..., playbook=...)` |
| Instalar | `pip install ansible-runner` (e `ansible-core` no mesmo ambiente) |
| Usar um projeto existente | `project_dir=` e `inventory=` |
| Playbook e inventário sem arquivos | `playbook=[...]` e `inventory={...}` |
| Um módulo avulso | `host_pattern=`, `module=`, `module_args=` |
| Uma role | `role=`, `roles_path=`, `host_pattern=` |
| Passar variáveis | `extravars={...}` |
| Restringir hosts e tasks | `limit=`, `tags=`, `skip_tags=` |
| Simular | `cmdline="--check --diff"` |
| Resultado final | `resultado.status`, `resultado.rc` |
| Resumo por host | `resultado.stats` (`ok`, `changed`, `failures`, `dark`...) |
| Saída completa | `resultado.stdout.read()` |
| Facts | `resultado.get_fact_cache("host")` |
| Reagir em tempo real | `event_handler=funcao` |
| Ler o resultado de uma task | Evento `runner_on_ok` → `event_data["res"]` |
| Executar em segundo plano | `ansible_runner.run_async()` |
| Cancelar ou limitar o tempo | `cancel_callback=`, `timeout=` |
| Credenciais | `envvars`, `ssh_key`, `passwords` (de preferência, sem prompts) |
| Contêineres | `process_isolation=True`, `container_image=` |
| Sem dependências extras | `subprocess` + `ansible-playbook` + callback JSON |
| Integrar com AWX ou Automation Platform | API REST (`/job_templates/<id>/launch/`) |
| Testar | `pytest` + inventário `localhost` + `tmp_path` |
| API interna (`TaskQueueManager`) | Evitar: não é uma interface estável |
