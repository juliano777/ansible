# Capítulo: `ansible-console`

## 1. O que é o `ansible-console`

O `ansible-console` é um **console interativo** (um REPL, como o interpretador do Python) para executar **tarefas do Ansible, uma de cada vez**, sobre um conjunto de hosts. Em vez de digitar um comando completo do `ansible` a cada tentativa, você abre uma **sessão** e vai digitando módulos e comandos, vendo o resultado de cada um na hora.

```
$ ansible-console -i hosts
Welcome to the ansible console. Type help or ? to list commands.

tux@all (4)[f:5]$ ping
deb00 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
...
```

Ele combina o poder do **ad-hoc** (`ansible host -m módulo -a args`) com a comodidade de uma sessão: você **troca de grupo de hosts**, liga e desliga o `become`, muda o paralelismo, ativa o modo `--check`, tudo sem reiniciar nada, e conta com **completar com a tecla Tab** e **histórico**.

### 1.1 Quando usar

| Situação | Exemplo |
|---|---|
| **Diagnóstico** em vários servidores | Ver carga, espaço em disco, versão de um pacote |
| **Exploração** de módulos e parâmetros | Testar o que um módulo faz antes de colocá-lo no playbook |
| **Correções pontuais** | Reiniciar um serviço em lotes, limpar um cache |
| **Aprendizado** | Experimentar `setup`, `stat`, `lineinfile` e ver o resultado |
| **Consultas rápidas** | `uptime`, `df -h`, `systemctl status` em todos os hosts |
| **Testes** de conectividade e permissões | `ping`, `become yes` + `whoami` |

### 1.2 Comparação com `ansible` e `ansible-playbook`

| | `ansible` (ad-hoc) | `ansible-console` | `ansible-playbook` |
|---|---|---|---|
| Uso | Um comando por vez, no shell | **Sessão interativa** | Automação completa e repetível |
| Várias tasks | Várias chamadas | Uma por linha, na sessão | Lista de tasks |
| Condições, loops, handlers, `register` | Não | **Não** | Sim |
| Trocar de hosts e opções | Reexecutar o comando | **`cd`, `become`, `forks`...** | Editar o playbook |
| Completar com Tab | Não | **Sim** | Não |
| Repetível e versionável | Parcial | **Não** | **Sim** |
| Ideal para | Comandos pontuais e scripts | **Explorar e diagnosticar** | O que vai para produção |

A regra de ouro: o `ansible-console` é para **descobrir** e **investigar**; o que funcionar e precisar se repetir deve virar **playbook** (seção 11).

---

## 2. Iniciando

```bash
ansible-console -i hosts                  # todos os hosts do inventário
ansible-console -i hosts db               # já começa no grupo db
ansible-console -i hosts 'db:&debian'     # interseção de grupos
ansible-console -i hosts --limit deb00,deb02
ansible-console -i hosts -b -K            # com become, pedindo a senha do sudo
```

Se o `ansible.cfg` do projeto define o inventário (`inventory = ./hosts`), o `-i` pode ser omitido.

> **Cuidado:** sem argumento, o padrão é **todos os hosts** (`all`). Comece sempre restringindo ao grupo que você quer atingir.

### 2.1 Opções da linha de comando

As opções são as mesmas do `ansible` ad-hoc. As principais:

| Opção | Efeito |
|---|---|
| `-i`, `--inventory` | Inventário (arquivo, diretório ou lista) |
| `-l`, `--limit` | Restringe os hosts |
| `-u`, `--user` | Usuário de conexão |
| `-b`, `--become` | Começa com elevação de privilégio ativada |
| `--become-user`, `--become-method` | Usuário e método da elevação |
| `-K`, `--ask-become-pass` | Pede a senha do `sudo` |
| `-k`, `--ask-pass` | Pede a senha da conexão SSH |
| `--private-key` | Chave SSH |
| `-c`, `--connection` | Tipo de conexão (`ssh`, `local`...) |
| `-f`, `--forks` | Paralelismo (padrão: 5) |
| `-T`, `--timeout` | Tempo limite da conexão |
| `-C`, `--check` | Começa em modo simulação |
| `-D`, `--diff` | Mostra as diferenças de arquivos |
| `--step` | Pede confirmação antes de cada tarefa |
| `-e`, `--extra-vars` | Variáveis extras |
| `--ask-vault-pass`, `--vault-password-file`, `--vault-id` | Senha do Vault |
| `-M`, `--module-path` | Pasta de módulos extra |
| `--playbook-dir` | Pasta do projeto (para `group_vars`, `host_vars` e plugins locais) |
| `-v` a `-vvvvv` | Verbosidade |

### 2.2 A anatomia do prompt

```
tux@db (2)[f:5]$
```

| Parte | Significado |
|---|---|
| `tux` | Usuário de conexão (`remote_user`) |
| `db` | **Padrão de hosts** atual (o "diretório de trabalho") |
| `(2)` | Quantos hosts o padrão seleciona |
| `[f:5]` | Número de *forks* (paralelismo) |
| `$` | `become` desligado |
| `#` | `become` ligado como `root` |

O prompt é o seu painel de controle: ele mostra **onde** e **com que poder** o próximo comando vai agir. **Leia-o antes de dar Enter** em qualquer comando que altere algo.

---

## 3. Comandos internos

Dentro da sessão, algumas palavras são comandos do próprio console (não módulos):

| Comando | O que faz | Exemplo |
|---|---|---|
| `cd PADRÃO` | Muda o padrão de hosts | `cd db` |
| `cd` (sem argumento) | Volta para todos os hosts | `cd` |
| `list` | Lista os hosts do padrão atual | `list` |
| `list groups` | Lista os grupos do inventário | `list groups` |
| `become yes` / `become no` | Liga e desliga a elevação | `become yes` |
| `become_user USUÁRIO` | Define o usuário da elevação | `become_user postgres` |
| `become_method MÉTODO` | Define o método (`sudo`, `su`...) | `become_method su` |
| `remote_user USUÁRIO` | Muda o usuário de conexão | `remote_user admin` |
| `forks N` | Número de execuções em paralelo | `forks 10` |
| `check yes` / `check no` | Modo simulação | `check yes` |
| `diff yes` / `diff no` | Mostra as diferenças | `diff yes` |
| `timeout N` | Tempo limite das conexões (segundos) | `timeout 30` |
| `verbosity N` | Nível de detalhe (0 a 6) | `verbosity 2` |
| `collections LISTA` | Collections usadas para nomes curtos de módulos | `collections community.general,ansible.posix` |
| `shell COMANDO` | Executa um comando com o módulo `shell` | `shell df -h` |
| `help` ou `?` | Lista os comandos | `help` |
| `help MÓDULO` | Resumo e parâmetros de um módulo | `help lineinfile` |
| `exit`, `quit` ou Ctrl+D | Sai do console | `exit` |

(Os comandos disponíveis podem variar um pouco entre versões do `ansible-core`; `help` mostra os da sua instalação.)

---

## 4. Executando módulos e comandos

### 4.1 Módulo com argumentos

A sintaxe é a do ad-hoc, sem o `-m` e o `-a`: o nome do módulo seguido dos argumentos em `chave=valor`.

```
tux@debian (2)[f:5]$ ping
tux@debian (2)[f:5]$ setup filter=ansible_distribution*
tux@debian (2)[f:5]$ stat path=/etc/hosts get_checksum=no
tux@debian (2)[f:5]$ debug msg="Estou em {{ inventory_hostname }}"
tux@debian (2)[f:5]$ file path=/tmp/teste state=touch mode=0644
tux@debian (2)[f:5]$ lineinfile path=/tmp/teste line="olá mundo" create=yes
```

Valores com espaços vão entre aspas. Como não há shell local interpretando a linha, as aspas e os caracteres especiais dão menos problema do que em `ansible -a '...'`.

### 4.2 Comando de shell

Se a primeira palavra **não** for um módulo conhecido, o console executa a linha com o módulo **`shell`**:

```
tux@db (2)[f:5]$ uptime
tux@db (2)[f:5]$ df -h /
tux@db (2)[f:5]$ systemctl status ssh | head -5
```

Pipes e redirecionamentos funcionam, por ser o módulo `shell`.

Para **forçar** o `shell` (por exemplo, quando o comando tem o mesmo nome de um módulo, como `ping` ou `stat`), use o comando `shell`:

```
tux@db (2)[f:5]$ shell stat /etc/hosts
```

Sem o `shell`, `stat` seria interpretado como o módulo `stat` do Ansible.

### 4.3 O resultado

```
deb00 | CHANGED | rc=0 >>
 14:20:11 up 3 days,  2:11,  1 user,  load average: 0.00, 0.02, 0.00
rh01 | CHANGED | rc=0 >>
 14:20:11 up 5 days,  4:09,  0 users,  load average: 0.08, 0.03, 0.01
```

(Ilustrativo.) O formato é o do ad-hoc: o host, o estado (`SUCCESS`, `CHANGED`, `FAILED`, `UNREACHABLE`) e a saída.

O comando `shell` sempre aparece como `CHANGED`, pois o Ansible não sabe se ele alterou algo. Isso é normal; só importa quando você estiver usando o console para **verificar idempotência**.

### 4.4 Nomes curtos e collections

Módulos do núcleo (`ping`, `copy`, `file`, `package`, `service`...) funcionam com o nome curto. Para módulos de **collections**, use o nome completo, ou diga ao console quais collections consultar:

```
tux@db (2)[f:5]$ community.postgresql.postgresql_ping db=postgres
tux@db (2)[f:5]$ collections community.postgresql,ansible.posix
tux@db (2)[f:5]$ postgresql_ping db=postgres
```

### 4.5 Completar com Tab

O console completa com a tecla **Tab**:

- **nomes de módulos:** digite `lin` e Tab para ver `lineinfile`;
- **parâmetros do módulo:** depois do nome do módulo, Tab sugere os nomes de parâmetros (`path=`, `line=`...);
- **comandos do console:** `bec` e Tab para `become`.

É a melhor forma de **descobrir** o que um módulo aceita sem sair da sessão.

### 4.6 Ajuda sobre um módulo

```
tux@db (2)[f:5]$ help lineinfile
```

Mostra a **descrição curta** e a **lista de parâmetros** do módulo. Para a documentação completa (exemplos, valores de retorno), use o `ansible-doc` em outro terminal (ver capítulo anterior).

### 4.7 Comentários

Linhas que começam com `#` são ignoradas, o que é útil para anotar a sessão se você copiar o histórico depois.

### 4.8 Variáveis e templates

As expressões Jinja2 funcionam e são avaliadas **para cada host**:

```
tux@db (2)[f:5]$ debug msg="{{ inventory_hostname }} tem o IP {{ ansible_host }}"
```

Variáveis do **inventário** (`ansible_host`, `group_vars`, `host_vars`) estão disponíveis. Os **facts** não são coletados automaticamente a cada comando, e variáveis criadas em um comando **não persistem** para o seguinte (cada linha é uma execução independente). Para reaproveitar facts entre comandos, ative o cache de facts (ver capítulo de facts).

---

## 5. Selecionando hosts

### 5.1 `cd` e `list`

O padrão de hosts funciona como um "diretório atual":

```
tux@all (4)[f:5]$ list groups
all
db
debian
redhat
servidores
ungrouped
web

tux@all (4)[f:5]$ cd db
tux@db (2)[f:5]$ list
deb00
rh01

tux@db (2)[f:5]$ cd
tux@all (4)[f:5]$
```

**Boa prática:** sempre dê `list` depois de um `cd`, antes de qualquer comando que altere algo, para ver exatamente quais hosts serão atingidos.

### 5.2 Padrões

O `cd` aceita os mesmos padrões do inventário (ver capítulo do `ansible-inventory`):

```
cd web:db               # união
cd db:&debian           # interseção
cd servidores:!redhat   # exclusão
cd deb*                 # curinga
cd ~deb0[0-9]           # expressão regular
cd deb00                # um host só
```

Se o padrão não selecionar nenhum host, o prompt mostra `(0)`, e um comando digitado avisa que nenhum host foi encontrado.

---

## 6. Configurando a sessão

### 6.1 Elevação de privilégio

```
tux@db (2)[f:5]$ shell whoami
deb00 | CHANGED | rc=0 >>
tux

tux@db (2)[f:5]$ become yes
tux@db (2)[f:5]# shell whoami
deb00 | CHANGED | rc=0 >>
root

tux@db (2)[f:5]# become_user postgres
tux@db (2)[f:5]$ shell whoami
...postgres
```

Observe o prompt: `$` sem privilégio, `#` como `root`. A senha do `sudo`, se necessária, é informada ao iniciar o console, com `-K`.

### 6.2 Paralelismo e lotes

```
tux@db (2)[f:5]$ forks 10        # até 10 hosts ao mesmo tempo
tux@db (2)[f:5]$ forks 1         # um host por vez
```

Com `forks 1`, o comando roda em um host, termina, e só então segue para o próximo (na ordem do inventário). É a forma de fazer **reinícios escalonados** com mais segurança no console (seção 8.4). Para voltar ao paralelismo normal, use `forks 5` (ou o valor que preferir). Note que o `forks` limita quantos hosts são processados **ao mesmo tempo**, mas não oferece lotes ordenados com verificação entre eles; para isso, use um playbook com `serial:` (seção 11).

### 6.3 Simulação (`check`) e diferenças (`diff`)

```
tux@db (2)[f:5]$ check yes
tux@db (2)[f:5]$ diff yes
tux@db (2)[f:5]$ lineinfile path=/etc/hosts line="10.0.0.99 teste"
```

Com `check yes`, os módulos que suportam o modo simulação informam o que **fariam**, sem alterar nada. O comando `shell` e o `command` são **pulados** em modo simulação (ver capítulo de `ansible-doc`, seção sobre ATTRIBUTES). Volte com `check no` quando quiser executar de verdade.

### 6.4 Tempo, detalhes e conexão

```
tux@db (2)[f:5]$ timeout 30
tux@db (2)[f:5]$ verbosity 2      # mais detalhes, como -vv
tux@db (2)[f:5]$ remote_user admin
```

### 6.5 Resumo do estado atual

Não existe um comando que liste todas as opções ao mesmo tempo, mas o **prompt** mostra o essencial (usuário, padrão, quantidade de hosts, *forks* e privilégio). Para confirmar o restante (check, diff), repita o comando sem argumento ou anote os que você alterou.

---

## 7. Uma sessão de exemplo

Investigando e corrigindo um problema de espaço em disco nos servidores Debian, passo a passo (saídas ilustrativas e resumidas):

```
$ ansible-console -i hosts debian -K
BECOME password:
Welcome to the ansible console. Type help or ? to list commands.

tux@debian (2)[f:5]$ list
deb00
deb02

tux@debian (2)[f:5]$ ping
deb00 | SUCCESS => { "changed": false, "ping": "pong" }
deb02 | SUCCESS => { "changed": false, "ping": "pong" }

tux@debian (2)[f:5]$ df -h /
deb00 | CHANGED | rc=0 >>
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1        20G   19G  500M  98% /
deb02 | CHANGED | rc=0 >>
/dev/vda1        20G   11G  8.0G  58% /

tux@debian (2)[f:5]$ cd deb00
tux@deb00 (1)[f:5]$ become yes
tux@deb00 (1)[f:5]# du -xh /var --max-depth=1 | sort -h | tail -3
deb00 | CHANGED | rc=0 >>
1.2G    /var/log
3.4G    /var/cache
5.1G    /var

tux@deb00 (1)[f:5]# check yes
tux@deb00 (1)[f:5]# apt autoclean=yes
deb00 | CHANGED => { "changed": true, "msg": "..." }      # simulado

tux@deb00 (1)[f:5]# check no
tux@deb00 (1)[f:5]# apt autoclean=yes
deb00 | CHANGED => { "changed": true, "msg": "..." }

tux@deb00 (1)[f:5]# df -h /
deb00 | CHANGED | rc=0 >>
/dev/vda1        20G   15G  4.2G  78% /

tux@deb00 (1)[f:5]# exit
```

O que a sessão mostra:

1. O console começa restrito ao grupo `debian`.
2. `list` e `ping` confirmam alvos e conectividade.
3. `df -h /` (a primeira palavra não é um módulo, então vira `shell`) revela o problema em `deb00`.
4. `cd deb00` restringe a **um único host** antes de qualquer alteração.
5. `become yes` liga o privilégio (o prompt passa a `#`).
6. `check yes` simula antes de aplicar; `check no` aplica.
7. Verifica-se o resultado com um novo `df`.

---

## 8. Receitas práticas

### 8.1 Diagnóstico geral

```
cd servidores
uptime
free -m
df -h /
systemctl --failed
setup filter=ansible_memtotal_mb
```

### 8.2 Pacotes

```
cd debian
become yes
package name=htop state=present
apt update_cache=yes cache_valid_time=3600
shell apt list --upgradable 2>/dev/null | head
```

### 8.3 Serviços

```
cd db
become yes
service name=postgresql state=started
shell systemctl status postgresql --no-pager | head -5
```

(O nome do serviço pode variar entre Debian e Red Hat; use `cd debian` e `cd redhat` separadamente se for diferente.)

### 8.4 Reinício escalonado

```
cd web
become yes
forks 1
service name=apache2 state=restarted
wait_for port=80 timeout=30
```

Com `forks 1`, o reinício é feito um host por vez. Mas atenção: o console executa **cada linha para todos os hosts do padrão** antes de ir para a próxima; ou seja, o `wait_for` só roda depois que **todos** já foram reiniciados. Para reiniciar **e** verificar um host de cada vez, faça o procedimento host por host com `cd` (por exemplo, `cd web01`, reiniciar, verificar, `cd web02`...), ou use um playbook com `serial: 1`.

### 8.5 Arquivos

```
stat path=/etc/ssh/sshd_config get_checksum=no
copy src=/home/tux/banner.txt dest=/etc/issue.net mode=0644
lineinfile path=/etc/ssh/sshd_config regexp='^#?PermitRootLogin' line='PermitRootLogin no'
fetch src=/var/log/syslog dest=/tmp/logs/ flat=no
```

### 8.6 Descobrir informações do host

```
setup filter=ansible_distribution*
setup filter=ansible_default_ipv4
setup gather_subset=network filter=ansible_interfaces
```

### 8.7 Testar permissões e conectividade

```
ping
become yes
shell id
shell sudo -n true && echo "sudo sem senha: ok"
wait_for host=192.168.1.10 port=5432 timeout=5
```

### 8.8 Explorar um módulo novo

```
help stat
stat path=/etc/hosts            # veja os campos que ele devolve
stat path=/nao-existe           # veja o retorno quando não existe
```

Ver a saída real de um módulo, com casos diferentes, é a melhor forma de entender os campos que o `register` terá.

---

## 9. Histórico, atalhos e conforto

| Recurso | Como usar |
|---|---|
| **Histórico** | Seta para cima e para baixo percorre os comandos anteriores |
| **Busca no histórico** | Ctrl+R, digitando parte do comando (se o `readline` do sistema suporta) |
| **Completar** | Tab (módulos, parâmetros e comandos do console) |
| **Cancelar a linha** | Ctrl+C |
| **Sair** | `exit`, `quit` ou Ctrl+D |
| **Limpar a tela** | Ctrl+L |

O histórico costuma ficar guardado entre sessões em um arquivo no diretório do usuário (por exemplo, `~/.ansible-console_history`), então comandos de hoje ficam disponíveis amanhã. O arquivo pode conter informações sensíveis digitadas na linha de comando (senhas em argumentos, por exemplo); trate-o com o cuidado que daria ao histórico do shell.

---

## 10. Segurança e prevenção de acidentes

O console é poderoso: **um comando afeta todos os hosts do padrão atual**, na hora, sem arquivo de playbook para revisar. Alguns cuidados:

### 10.1 Antes de cada comando que altera algo

1. **Leia o prompt:** padrão de hosts, quantidade `(N)` e `$` ou `#`.
2. **Dê `list`** para ver exatamente quem será atingido.
3. **Use `check yes`** primeiro, quando o módulo suportar.
4. Em operações arriscadas, restrinja a **um host** (`cd deb00`) ou reduza o paralelismo com `forks 1`.
5. Prefira **módulos** (`package`, `service`, `lineinfile`) a `shell`: são idempotentes e informam o que mudou.

### 10.2 Comandos de risco

| Comando | Risco | Alternativa |
|---|---|---|
| `shell rm -rf ...` | Apaga dados em todos os hosts | `file path=... state=absent`, em um host, com `check yes` antes |
| `shell reboot` | Reinicia todos ao mesmo tempo | `forks 1` e `reboot` (módulo), host por host |
| `shell systemctl stop ...` em `all` | Derruba um serviço em toda a frota | Restringir com `cd` |
| `become yes` em `all` | Privilégio máximo em todos os hosts | Ativar só ao precisar, em um grupo restrito |

### 10.3 Auditoria

Sessões interativas são difíceis de auditar. Para ter um registro do que foi feito:

- Configure `log_path` no `ansible.cfg` para gravar a execução dos comandos do Ansible em um arquivo:

```ini
[defaults]
log_path = ~/ansible_console.log
```

- Mantenha o histórico do console (seção 9) e os logs de `sudo` e do `auditd` nos hosts.
- Para mudanças que precisam de **aprovação e rastreabilidade**, use **playbooks versionados** no Git, e não o console.

### 10.4 Segredos

- Não digite senhas em argumentos de módulos (ficam no histórico e podem aparecer em logs).
- Use `-K` e `--ask-vault-pass` ao iniciar o console, e não dentro da sessão.
- Evite `verbosity` alto ao manipular dados sensíveis.

---

## 11. Do console para o playbook

O fluxo ideal: **descobrir no console, repetir no playbook**. Quando uma sequência de comandos funcionou, converta-a em tasks, com idempotência, `no_log` e testes.

### 11.1 O que a sessão do exemplo viraria

Sessão (resumo):

```
cd deb00
become yes
du -xh /var --max-depth=1 | sort -h | tail -3
apt autoclean=yes
df -h /
```

Playbook equivalente:

```yaml
---
- name: Liberar espaço em disco nos servidores Debian
  hosts: debian
  become: true
  gather_facts: false

  tasks:
    - name: Medir o uso da raiz antes
      ansible.builtin.shell: df --output=pcent / | tail -1 | tr -dc '0-9'
      register: uso_antes
      changed_when: false
      check_mode: false

    - name: Limpar o cache de pacotes obsoletos
      ansible.builtin.apt:
        autoclean: true
      when: uso_antes.stdout | int >= 80

    - name: Medir o uso da raiz depois
      ansible.builtin.shell: df --output=pcent / | tail -1 | tr -dc '0-9'
      register: uso_depois
      changed_when: false
      check_mode: false

    - name: Mostrar o resultado
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }}: {{ uso_antes.stdout }}% -> {{ uso_depois.stdout }}%"
```

O que o playbook ganha em relação à sessão: **condição** (só limpa se o uso for alto), **registro** do antes e do depois, **modo `--check`** funcionando, **repetibilidade** e **versionamento**.

### 11.2 Diferenças a lembrar ao converter

| Console | Playbook |
|---|---|
| `shell` é a escolha padrão | Prefira módulos (`package`, `service`, `file`) |
| Saída lida a olho | `register`, `assert` e `when` |
| Sem tratamento de erros | `block`, `rescue`, `failed_when` |
| Hosts escolhidos por `cd` | `hosts:` e `--limit` |
| `become yes` na sessão | `become: true` só onde necessário |
| Sem testes | `--check --diff`, Molecule |

---

## 12. Exemplo completo: do diagnóstico à correção

**Cenário:** usuários reclamam que a aplicação está lenta. Você tem 3 servidores web (`web`) e precisa descobrir a causa e corrigi-la sem derrubar o serviço.

```
$ ansible-console -i hosts web -K
```

**1. Confirmar alvo e conectividade**

```
tux@web (3)[f:5]$ list
tux@web (3)[f:5]$ ping
```

**2. Olhar carga e memória**

```
tux@web (3)[f:5]$ uptime
tux@web (3)[f:5]$ free -m
```

Um dos hosts, `web02`, está com carga alta.

**3. Isolar o host e investigar**

```
tux@web (3)[f:5]$ cd web02
tux@web02 (1)[f:5]$ shell ps aux --sort=-%cpu | head -5
tux@web02 (1)[f:5]$ shell systemctl status apache2 --no-pager | head -8
tux@web02 (1)[f:5]$ stat path=/var/log/apache2/error.log get_checksum=no
```

O log de erros está enorme e o processo do servidor web consome CPU em excesso.

**4. Ver o conteúdo (somente leitura)**

```
tux@web02 (1)[f:5]$ become yes
tux@web02 (1)[f:5]# shell tail -n 5 /var/log/apache2/error.log
```

**5. Simular a correção**

```
tux@web02 (1)[f:5]# check yes
tux@web02 (1)[f:5]# service name=apache2 state=restarted
```

**6. Aplicar e verificar**

```
tux@web02 (1)[f:5]# check no
tux@web02 (1)[f:5]# service name=apache2 state=restarted
tux@web02 (1)[f:5]# wait_for port=80 timeout=30
tux@web02 (1)[f:5]# uptime
```

**7. Aplicar a mesma correção, com cuidado, aos demais**

```
tux@web02 (1)[f:5]# cd web
tux@web (3)[f:5]# list
tux@web (3)[f:5]# forks 1
tux@web (3)[f:5]# service name=apache2 state=restarted
```

**8. Sair e registrar**

```
tux@web (3)[f:5]# exit
```

Em seguida, a sequência que funcionou (verificar carga, ver o log, reiniciar um por vez, validar a porta) é transformada em um playbook com `serial: 1`, `wait_for` e testes, e o procedimento passa a ser **repetível e revisado**, em vez de depender da memória de quem estava no console.

---

## 13. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `No host found` (ou `(0)` no prompt) | O padrão não seleciona hosts | `list groups`, `cd all` e conferir o nome |
| Comando age em hosts demais | Padrão `all` ao iniciar | Iniciar com um grupo, e usar `cd` e `list` |
| `Permission denied` ao alterar algo | `become` desligado (`$`) | `become yes` (e `-K` ao iniciar, se pedir senha) |
| Senha do `sudo` não foi pedida | Console iniciado sem `-K` | Reiniciar com `-K`, ou configurar `sudo` sem senha |
| `stat`, `ping` ou `copy` rodam como módulo, e eu queria o comando do sistema | A primeira palavra é um módulo | Usar `shell stat ...` |
| Um módulo de collection não é encontrado | Nome curto sem a collection | Nome completo, ou `collections nome` |
| `shell` mostra sempre `CHANGED` | O Ansible não sabe se houve mudança | Esperado; use módulos para saber o estado real |
| `check yes` não mostra nada para `shell` | `shell` e `command` são pulados em simulação | Usar módulos com suporte a `check` |
| Variável de um comando não existe no próximo | Cada comando é uma execução independente | Usar playbook, ou cache de facts |
| Facts indisponíveis | O console não coleta facts por conta própria | `setup` ou cache de facts |
| Parâmetro com espaço é cortado | Faltam aspas | `line="texto com espaço"` |
| `UNREACHABLE` | Problema de rede, chave ou usuário | `ping`, `verbosity 3` e conferir `remote_user` |
| Tab não completa | `readline` indisponível no Python do sistema | Instalar o suporte a `readline`, ou usar o `ansible-doc` |
| Quero rodar vários comandos de uma vez | O console executa uma linha por vez | Usar um playbook |
| Preciso de loops e condições | O console não tem essas construções | Usar um playbook |
| Dados sensíveis no histórico | Senhas digitadas em argumentos | Limpar o arquivo de histórico; usar `-K` e Vault |

---

## 14. Boas práticas

1. **Comece restrito:** inicie o console com o grupo desejado (`ansible-console -i hosts db`), e não com `all`.
2. **Leia o prompt** antes de cada comando de alteração: padrão, quantidade, `$` ou `#`.
3. **Use `list` depois de `cd`**, para ver quem será atingido.
4. **Simule primeiro** com `check yes`, quando o módulo suportar.
5. **Prefira módulos a `shell`**: são idempotentes e informam o que mudou.
6. **Reduza o paralelismo (`forks 1`) ou vá host por host (`cd`)** em operações arriscadas (reinícios, remoções), e confirme a saúde entre um host e outro; para lotes com verificação automática, use um playbook com `serial`.
7. **Ligue o `become` só quando precisar** e desligue em seguida.
8. **Use um host de teste primeiro**, depois o grupo.
9. **Não digite senhas em argumentos;** use `-K`, `--ask-vault-pass` e chaves SSH.
10. **Registre o que foi feito** (`log_path`, histórico, logs de `sudo`) quando houver exigência de rastreabilidade.
11. **Transforme em playbook** tudo o que precisar se repetir ou ser revisado.
12. **Não use o console como ferramenta de mudança em produção** sem processo: ele é excelente para investigar, e frágil para auditar.
13. **Use o `help MÓDULO` e o `ansible-doc`** para entender os parâmetros antes de executar.
14. **Aproveite o console para aprender:** explore módulos, veja os retornos, e leve o que entendeu para os playbooks.

---

## Resumo

| Necessidade | Como fazer no console |
|---|---|
| Abrir o console | `ansible-console -i hosts [padrão]` |
| Começar restrito a um grupo | `ansible-console -i hosts db` |
| Começar com privilégio e senha do `sudo` | `ansible-console -i hosts -b -K` |
| Ver os hosts atuais | `list` |
| Ver os grupos | `list groups` |
| Mudar o alvo | `cd padrão` |
| Voltar para todos | `cd` |
| Executar um módulo | `módulo chave=valor ...` |
| Executar um comando de shell | `comando ...` ou `shell comando ...` |
| Forçar o shell | `shell stat /etc/hosts` |
| Ligar e desligar o `become` | `become yes` / `become no` |
| Mudar o usuário do `become` | `become_user postgres` |
| Paralelismo | `forks N` |
| Um host por vez | `forks 1` |
| Simular | `check yes` / `check no` |
| Mostrar diferenças | `diff yes` |
| Mais detalhes | `verbosity N` |
| Módulos de uma collection (nome curto) | `collections nome` |
| Ajuda de um módulo | `help módulo` |
| Completar | Tab |
| Sair | `exit`, `quit` ou Ctrl+D |
| Registro do que foi executado | `log_path` no `ansible.cfg` e histórico do console |
| O que fazer com o que funcionou | Transformar em playbook |
