# Capítulo: Handlers no Ansible (exemplo com `postgresql.conf`)

## 1. O que são handlers

Um **handler** é uma task especial que só executa quando é **notificada** por outra task, e somente se essa outra task **alterou algo** (`changed`). É o mecanismo ideal para ações como:

- reiniciar um serviço depois de alterar seu arquivo de configuração;
- recarregar a configuração (`reload`) depois de mudar regras de acesso;
- executar `update-ca-certificates`, `daemon-reload`, `sysctl --system`.

A ideia central: **"se mudou, então reaja"**. Se nada mudou, nada é reiniciado. Isso mantém o playbook idempotente e evita interrupções desnecessárias de serviço.

Estrutura básica:

```yaml
tasks:
  - name: Alterar a configuração
    ansible.builtin.lineinfile:
      path: /etc/exemplo.conf
      line: "opcao = valor"
    notify: Reiniciar o serviço       # dispara o handler pelo nome

handlers:
  - name: Reiniciar o serviço         # o nome precisa ser idêntico
    ansible.builtin.service:
      name: exemplo
      state: restarted
```

---

## 2. Regras de funcionamento

| Regra | Detalhe |
|---|---|
| Só roda se a task notificadora **alterou** algo | Task com resultado `ok` (sem mudança) não dispara o handler |
| Roda **uma única vez**, mesmo notificado várias vezes | Se três tasks notificam o mesmo handler, ele executa uma vez |
| Roda **no final do play** | Depois de todas as tasks (a menos que você use `meta: flush_handlers`) |
| A **ordem** é a da definição em `handlers:` | Não a ordem em que foram notificados |
| Roda **por host** | Só nos hosts em que a task notificadora alterou algo |
| O nome do `notify` deve ser **idêntico** | Maiúsculas, minúsculas e espaços importam |
| Handler inexistente gera **erro** | O Ansible avisa que não encontrou o handler solicitado |
| Em `--check`, os handlers também são **simulados** | O módulo reporta o que faria |
| Se o play **falha** antes do fim, handlers pendentes **não rodam** | A menos que `force_handlers: true` (seção 10) |

Os handlers aceitam as mesmas diretivas de uma task comum: `when`, `become`, `tags`, `vars`, `register`, `listen` e outras.

---

## 3. O cenário: `listen_addresses` no PostgreSQL

Por padrão, o PostgreSQL só aceita conexões locais (`listen_addresses = 'localhost'`). Para que ele aceite conexões de outras máquinas, é preciso mudar o parâmetro `listen_addresses` do arquivo `postgresql.conf` para `'*'` (todas as interfaces).

### 3.1 Três detalhes que importam

**1. O valor precisa estar entre aspas simples.** No `postgresql.conf`, um valor que não seja um identificador simples deve ser escrito entre aspas:

```
listen_addresses = '*'      # CORRETO
listen_addresses = *        # inválido: erro de sintaxe ao iniciar
```

**2. Mudar `listen_addresses` exige reinício (`restart`), não basta `reload`.** É um parâmetro lido apenas na partida do servidor. Já alterações no `pg_hba.conf` (quem pode conectar) são aplicadas com `reload`. Isso é um ótimo exemplo para usar **dois handlers diferentes**.

**3. Ouvir em todas as interfaces não basta para liberar o acesso.** O `pg_hba.conf` também precisa permitir a rede dos clientes, e o firewall precisa liberar a porta (5432 por padrão). Abrir só o `listen_addresses` e esquecer o resto resulta em "conexão recusada" ou "sem entrada no pg_hba.conf".

> **Segurança:** `'*'` expõe o serviço em todas as interfaces. Combine sempre com regras restritas no `pg_hba.conf` (por exemplo, apenas a sub-rede da aplicação) e com o firewall. Evite liberar `0.0.0.0/0`.

### 3.2 Caminhos e nomes por distribuição

Os caminhos e o nome do serviço mudam entre Debian e Red Hat. A tabela usa como referência o **PostgreSQL 16**; ajuste a versão e confira o seu ambiente.

| Item | Debian / Ubuntu | Red Hat (pacotes do repositório PGDG) |
|---|---|---|
| `postgresql.conf` | `/etc/postgresql/16/main/postgresql.conf` | `/var/lib/pgsql/16/data/postgresql.conf` |
| `pg_hba.conf` | `/etc/postgresql/16/main/pg_hba.conf` | `/var/lib/pgsql/16/data/pg_hba.conf` |
| Serviço | `postgresql` (ou `postgresql@16-main`) | `postgresql-16` |

Se você usa o módulo de AppStream do RHEL (`dnf module`), o serviço se chama `postgresql` e os arquivos ficam em `/var/lib/pgsql/data/`. No Red Hat, o cluster precisa ter sido **inicializado** (`initdb`) antes de existir um `postgresql.conf`.

---

## 4. Primeira versão: simples, para um único sistema

```yaml
---
- name: Liberar o PostgreSQL para conexões remotas
  hosts: debian
  become: true

  tasks:
    - name: Configurar listen_addresses
      ansible.builtin.lineinfile:
        path: /etc/postgresql/16/main/postgresql.conf
        regexp: '^\s*#?\s*listen_addresses\s*='
        line: "listen_addresses = '*'"
      notify: Reiniciar o PostgreSQL

  handlers:
    - name: Reiniciar o PostgreSQL
      ansible.builtin.service:
        name: postgresql
        state: restarted
```

### 4.1 Como a task funciona

- `regexp: '^\s*#?\s*listen_addresses\s*='` encontra a linha do parâmetro, **tanto comentada** (`#listen_addresses = 'localhost'`, que é o padrão do arquivo) **quanto ativa**. A linha encontrada é substituída por `line`.
- Se a linha já for exatamente `listen_addresses = '*'`, a task retorna `ok` (sem `changed`) e o handler **não** é disparado.
- O `line` está entre aspas duplas (YAML) com aspas simples dentro (PostgreSQL), para que o valor final no arquivo seja `listen_addresses = '*'`.
- O `regexp` usa aspas simples no YAML para que `\s` seja passado literalmente.

### 4.2 Comportamento nas execuções

**Primeira execução** (a linha precisa mudar):

```
TASK [Configurar listen_addresses] ***********************
changed: [deb00]

RUNNING HANDLER [Reiniciar o PostgreSQL] *****************
changed: [deb00]

PLAY RECAP ***********************************************
deb00 : ok=3  changed=2  unreachable=0  failed=0  skipped=0
```

**Segunda execução** (já está configurado):

```
TASK [Configurar listen_addresses] ***********************
ok: [deb00]

PLAY RECAP ***********************************************
deb00 : ok=2  changed=0  unreachable=0  failed=0  skipped=0
```

Nenhum handler rodou, e o serviço **não foi reiniciado**. Esse é o ponto principal dos handlers.

### 4.3 Simulando antes de aplicar

```bash
ansible-playbook -i hosts pg.yml -K --check --diff
```

O `--diff` mostra a linha que seria alterada no arquivo, e o `--check` simula também o handler. Use sempre antes de mexer na configuração do banco.

---

## 5. Segunda versão: Debian e Red Hat no mesmo playbook

Usando variáveis por família de SO (ver capítulos de variáveis e facts):

```yaml
---
- name: Liberar o PostgreSQL para conexões remotas
  hosts: all
  gather_facts: true
  become: true

  vars:
    pg_versao: 16
    pg_porta: 5432

    pg_por_so:
      Debian:
        conf: "/etc/postgresql/{{ pg_versao }}/main/postgresql.conf"
        servico: postgresql
      RedHat:
        conf: "/var/lib/pgsql/{{ pg_versao }}/data/postgresql.conf"
        servico: "postgresql-{{ pg_versao }}"

    pg: "{{ pg_por_so[ansible_facts['os_family']] }}"

  tasks:
    - name: Verificar se o postgresql.conf existe
      ansible.builtin.stat:
        path: "{{ pg.conf }}"
      register: pg_conf
      tags: always

    - name: Falhar com mensagem clara se o arquivo não existir
      ansible.builtin.assert:
        that: pg_conf.stat.exists
        fail_msg: "{{ pg.conf }} não existe em {{ inventory_hostname }} (o PostgreSQL está instalado e inicializado?)"
      tags: always

    - name: Configurar listen_addresses
      ansible.builtin.lineinfile:
        path: "{{ pg.conf }}"
        regexp: '^\s*#?\s*listen_addresses\s*='
        line: "listen_addresses = '*'"
        backup: true
      notify: Reiniciar o PostgreSQL
      tags: config

  handlers:
    - name: Reiniciar o PostgreSQL
      ansible.builtin.service:
        name: "{{ pg.servico }}"
        state: restarted
```

Detalhes:

- `pg` é escolhido pelo fact `os_family`, então as tasks e o handler usam `pg.conf` e `pg.servico` sem `when`.
- O `stat` com `assert` falha cedo e com uma mensagem útil se o PostgreSQL não estiver instalado ou inicializado.
- `backup: true` cria uma cópia datada do `postgresql.conf` **somente quando há alteração**.
- O handler usa a variável `pg.servico`, então o mesmo handler funciona nos dois sistemas.

---

## 6. Dois handlers: `restart` e `reload`

Agora vamos liberar uma rede cliente no `pg_hba.conf`. Essa alteração precisa apenas de `reload`, enquanto `listen_addresses` exige `restart`.

```yaml
---
- name: Liberar o PostgreSQL para conexões remotas
  hosts: all
  gather_facts: true
  become: true

  vars:
    pg_versao: 16
    rede_clientes: 192.168.1.0/24

    pg_por_so:
      Debian:
        conf: "/etc/postgresql/{{ pg_versao }}/main/postgresql.conf"
        hba: "/etc/postgresql/{{ pg_versao }}/main/pg_hba.conf"
        servico: postgresql
      RedHat:
        conf: "/var/lib/pgsql/{{ pg_versao }}/data/postgresql.conf"
        hba: "/var/lib/pgsql/{{ pg_versao }}/data/pg_hba.conf"
        servico: "postgresql-{{ pg_versao }}"

    pg: "{{ pg_por_so[ansible_facts['os_family']] }}"

  tasks:
    - name: Configurar listen_addresses (exige reinício)
      ansible.builtin.lineinfile:
        path: "{{ pg.conf }}"
        regexp: '^\s*#?\s*listen_addresses\s*='
        line: "listen_addresses = '*'"
        backup: true
      notify: Reiniciar o PostgreSQL
      tags: config

    - name: Permitir a rede dos clientes no pg_hba.conf (basta recarregar)
      ansible.builtin.lineinfile:
        path: "{{ pg.hba }}"
        regexp: '^host\s+all\s+all\s+{{ rede_clientes | regex_escape }}\s'
        line: "host    all    all    {{ rede_clientes }}    scram-sha-256"
        insertafter: EOF
        backup: true
      notify: Recarregar o PostgreSQL
      tags: acesso

  handlers:
    - name: Reiniciar o PostgreSQL
      ansible.builtin.service:
        name: "{{ pg.servico }}"
        state: restarted

    - name: Recarregar o PostgreSQL
      ansible.builtin.service:
        name: "{{ pg.servico }}"
        state: reloaded
```

### 6.1 Como os handlers se combinam

| O que mudou | Handlers executados |
|---|---|
| Nada | Nenhum |
| Só o `postgresql.conf` | Reiniciar |
| Só o `pg_hba.conf` | Recarregar |
| Os dois | Reiniciar e depois Recarregar (ordem da definição) |

Como o `restart` já faz o servidor reler o `pg_hba.conf`, o `reload` seguinte é redundante, mas inofensivo. Se quiser evitá-lo, veja a seção 8 (`listen`).

### 6.2 Cuidados com o `pg_hba.conf`

- A **ordem** das linhas importa: o PostgreSQL usa a **primeira** regra que casa. Acrescentar ao final (`insertafter: EOF`) funciona na maioria dos casos, mas uma regra `reject` anterior para a mesma rede teria prioridade.
- O `regexp` com `regex_escape` torna a task idempotente mesmo que o espaçamento da linha existente seja diferente.
- Escolha o método de autenticação conforme o seu ambiente (`scram-sha-256` é o padrão moderno; `md5` é legado).

---

## 7. Aplicando os handlers na hora e validando: `flush_handlers`

Por padrão, os handlers rodam no **fim do play**. Se você precisa que o reinício aconteça **antes** de uma verificação, use `meta: flush_handlers`, que executa agora todos os handlers pendentes:

```yaml
  tasks:
    - name: Configurar listen_addresses
      ansible.builtin.lineinfile:
        path: "{{ pg.conf }}"
        regexp: '^\s*#?\s*listen_addresses\s*='
        line: "listen_addresses = '*'"
        backup: true
      notify: Reiniciar o PostgreSQL

    - name: Aplicar os handlers agora
      ansible.builtin.meta: flush_handlers

    - name: Confirmar que o PostgreSQL ouve no IP do servidor
      ansible.builtin.wait_for:
        host: "{{ ansible_facts['default_ipv4']['address'] }}"
        port: 5432
        timeout: 30
```

Se o PostgreSQL não subir, ou subir apenas em `localhost`, o `wait_for` falha em até 30 segundos, e o problema aparece **durante** o playbook, e não depois, quando alguém tenta conectar.

Pontos importantes:

- `flush_handlers` executa **todos** os handlers notificados até aquele momento, não apenas um.
- Depois do flush, novas notificações voltam a ser acumuladas para o fim do play.
- É a forma correta de garantir que uma configuração está **ativa** antes das tasks seguintes que dependem dela.

---

## 8. `listen`: vários handlers para um evento

Com `listen`, os handlers respondem a um **tópico** em vez de a um nome específico. Uma única notificação dispara todos os handlers que "escutam" aquele tópico:

```yaml
  tasks:
    - name: Configurar listen_addresses
      ansible.builtin.lineinfile:
        path: "{{ pg.conf }}"
        regexp: '^\s*#?\s*listen_addresses\s*='
        line: "listen_addresses = '*'"
      notify: postgresql precisa reiniciar     # notifica o TÓPICO

  handlers:
    - name: Reiniciar o serviço do PostgreSQL
      ansible.builtin.service:
        name: "{{ pg.servico }}"
        state: restarted
      listen: postgresql precisa reiniciar

    - name: Aguardar a porta do PostgreSQL
      ansible.builtin.wait_for:
        port: 5432
        timeout: 30
      listen: postgresql precisa reiniciar
```

Vantagens:

- **Desacopla** a task dos handlers: você pode adicionar ou remover handlers sem editar quem notifica.
- Útil em **roles**, onde quem usa a role pode acrescentar seus próprios handlers ao mesmo tópico.
- Permite **encadear ações** (reiniciar, esperar a porta, avisar o monitoramento) com uma só notificação.

Os handlers do mesmo tópico executam na ordem em que aparecem em `handlers:`.

---

## 9. O problema do "handler perdido"

Este é o erro mais traiçoeiro com handlers. Veja a sequência:

1. A task altera o `postgresql.conf` (`changed`) e notifica o handler.
2. Uma task **posterior** falha (por exemplo, o `pg_hba.conf` não existe).
3. O play é interrompido nesse host, e o handler pendente **nunca executa**.
4. O arquivo já foi alterado. Na próxima execução, a task retorna `ok` (a linha já está correta), **não notifica** o handler, e o PostgreSQL **continua sem reiniciar**, com a configuração antiga em memória e a nova no disco.

O resultado é um servidor "configurado no papel" que não ouve em `'*'`.

### 9.1 Soluções

**1. `force_handlers: true` no play**: executa os handlers pendentes mesmo se o play falhar naquele host.

```yaml
- name: Liberar o PostgreSQL
  hosts: all
  become: true
  force_handlers: true
```

Também pode ser ativado na linha de comando:

```bash
ansible-playbook -i hosts pg.yml -K --force-handlers
```

**2. `flush_handlers` logo após a alteração**, como na seção 7: o reinício acontece antes de qualquer task que possa falhar.

**3. Decidir pelo estado real, e não pela mudança.** Em vez de depender só do `changed`, verifique se o servidor está de fato ouvindo no endereço desejado, e force o reinício caso não esteja:

```yaml
    - name: Verificar se o PostgreSQL ouve fora do localhost
      ansible.builtin.wait_for:
        host: "{{ ansible_facts['default_ipv4']['address'] }}"
        port: 5432
        timeout: 3
      register: ouvindo
      ignore_errors: true

    - name: Reiniciar se não estiver ouvindo
      ansible.builtin.service:
        name: "{{ pg.servico }}"
        state: restarted
      when: ouvindo is failed
```

(Pressupondo que o `listen_addresses` já foi configurado: se o arquivo está certo e a porta não responde no IP, falta reiniciar.)

**Recomendação:** use `force_handlers: true` em plays que alteram configuração de serviços, e `flush_handlers` quando a próxima etapa depende do serviço já estar atualizado.

---

## 10. Backup e rollback com `block` e `rescue`

Uma configuração inválida impede o PostgreSQL de subir. Combine a alteração com `block` / `rescue` (ver capítulo de blocks) para voltar atrás se o serviço não iniciar.

Neste cenário específico, em que o reinício e a verificação precisam fazer parte do mesmo bloco, é mais previsível usar uma **task `service` explícita** (condicionada ao `changed`) em vez de um handler. Assim, qualquer falha do reinício é tratada diretamente pelo `rescue`:

```yaml
  tasks:
    - name: Alterar o listen_addresses com possibilidade de rollback
      block:
        - name: Configurar listen_addresses
          ansible.builtin.lineinfile:
            path: "{{ pg.conf }}"
            regexp: '^\s*#?\s*listen_addresses\s*='
            line: "listen_addresses = '*'"
            backup: true
          register: alteracao

        - name: Reiniciar o PostgreSQL, se o arquivo mudou
          ansible.builtin.service:
            name: "{{ pg.servico }}"
            state: restarted
          when: alteracao is changed

        - name: Confirmar que o serviço está ativo
          ansible.builtin.wait_for:
            port: 5432
            timeout: 30

      rescue:
        - name: Restaurar o arquivo de backup
          ansible.builtin.copy:
            src: "{{ alteracao.backup }}"
            dest: "{{ pg.conf }}"
            remote_src: true
            mode: preserve
          when: alteracao.backup is defined

        - name: Reiniciar com a configuração original
          ansible.builtin.service:
            name: "{{ pg.servico }}"
            state: restarted

        - name: Sinalizar a falha
          ansible.builtin.fail:
            msg: "Alteração revertida em {{ inventory_hostname }}"
```

O `backup: true` do `lineinfile` registra o caminho da cópia em `alteracao.backup` (só existe quando houve alteração). Se o `restart` ou o `wait_for` falhar, o `rescue` restaura o arquivo e reinicia o serviço com a configuração anterior.

Esse é um caso em que a task explícita é preferível. Na maioria das situações, o handler continua sendo a escolha certa, por rodar uma única vez e só quando necessário.

---

## 11. Alternativas para alterar o `postgresql.conf`

### 11.1 Arquivo auxiliar em `conf.d`

Nos pacotes Debian, o `postgresql.conf` já contém `include_dir = 'conf.d'`. Em vez de editar o arquivo principal, você pode criar um arquivo próprio, o que facilita desfazer a mudança (basta remover o arquivo):

```yaml
- name: Criar o arquivo de configuração do Ansible
  ansible.builtin.copy:
    dest: "/etc/postgresql/{{ pg_versao }}/main/conf.d/10-listen.conf"
    content: |
      # Gerenciado pelo Ansible
      listen_addresses = '*'
    owner: postgres
    group: postgres
    mode: "0644"
  notify: Reiniciar o PostgreSQL
```

No Red Hat, a diretiva `include_dir` não vem habilitada por padrão; é preciso ativá-la no `postgresql.conf` antes.

### 11.2 Módulo `community.postgresql.postgresql_set`

A coleção `community.postgresql` oferece o módulo `postgresql_set`, que altera parâmetros via SQL (`ALTER SYSTEM`) e informa se um reinício é necessário:

```yaml
- name: Definir listen_addresses
  community.postgresql.postgresql_set:
    name: listen_addresses
    value: "*"
  become: true
  become_user: postgres
  register: pg_set
  notify: Reiniciar o PostgreSQL
```

O resultado costuma trazer o campo `restart_required`, que pode servir para decidir entre reiniciar e recarregar (confira a documentação da versão da coleção que você usa). Observe que esse módulo grava o valor em `postgresql.auto.conf`, e não no `postgresql.conf`. Requer a coleção instalada (`ansible-galaxy collection install community.postgresql`) e a biblioteca `psycopg2` no host. Ao usar `become_user: postgres` (usuário sem privilégios), o Ansible pode exigir o pacote `acl` ou `ANSIBLE_PIPELINING=True` para criar arquivos temporários.

### 11.3 Comparação

| Abordagem | Vantagem | Cuidado |
|---|---|---|
| `lineinfile` no `postgresql.conf` | Simples, sem dependências | Edita o arquivo principal; atenção à regex |
| Arquivo em `conf.d` (`copy` ou `template`) | Fácil de reverter; separa o que o Ansible gerencia | Precisa de `include_dir` habilitado |
| `postgresql_set` | Informa se precisa reiniciar | Exige coleção, `psycopg2` e conexão ao banco |

---

## 12. Handlers em roles

Em uma role, os handlers ficam em `handlers/main.yml`, e as tasks os notificam normalmente:

```
roles/
└── postgresql_remote/
    ├── defaults/main.yml
    ├── tasks/main.yml
    └── handlers/main.yml
```

`roles/postgresql_remote/handlers/main.yml`:

```yaml
---
- name: Reiniciar o PostgreSQL
  ansible.builtin.service:
    name: "{{ pg_servico }}"
    state: restarted

- name: Recarregar o PostgreSQL
  ansible.builtin.service:
    name: "{{ pg_servico }}"
    state: reloaded
```

`roles/postgresql_remote/tasks/main.yml`:

```yaml
---
- name: Configurar listen_addresses
  ansible.builtin.lineinfile:
    path: "{{ pg_conf }}"
    regexp: '^\s*#?\s*listen_addresses\s*='
    line: "listen_addresses = '{{ pg_listen_addresses }}'"
    backup: true
  notify: Reiniciar o PostgreSQL
```

`roles/postgresql_remote/defaults/main.yml`:

```yaml
---
pg_listen_addresses: "*"
```

Observações:

- Os handlers de uma role ficam disponíveis para **todo o play**, e podem ser notificados por tasks de outras roles.
- Para evitar conflito de nomes entre roles, use nomes específicos ou prefixos, ou use `listen` com tópicos próprios.
- `meta: flush_handlers` funciona dentro de roles.

---

## 13. Playbook completo

Juntando o que foi visto: variáveis por SO, verificação prévia, backup, `restart` e `reload` separados, `flush_handlers`, validação e `force_handlers`.

```yaml
---
- name: Liberar o PostgreSQL para conexões remotas
  hosts: all
  gather_facts: true
  become: true
  force_handlers: true

  vars:
    pg_versao: 16
    pg_porta: 5432
    rede_clientes: 192.168.1.0/24

    pg_por_so:
      Debian:
        conf: "/etc/postgresql/{{ pg_versao }}/main/postgresql.conf"
        hba: "/etc/postgresql/{{ pg_versao }}/main/pg_hba.conf"
        servico: postgresql
      RedHat:
        conf: "/var/lib/pgsql/{{ pg_versao }}/data/postgresql.conf"
        hba: "/var/lib/pgsql/{{ pg_versao }}/data/pg_hba.conf"
        servico: "postgresql-{{ pg_versao }}"

    pg: "{{ pg_por_so[ansible_facts['os_family']] }}"

  tasks:
    - name: Verificar os arquivos de configuração
      ansible.builtin.stat:
        path: "{{ item }}"
        get_checksum: false
        get_mime: false
      loop:
        - "{{ pg.conf }}"
        - "{{ pg.hba }}"
      register: pg_arquivos
      loop_control:
        label: "{{ item }}"
      tags: always

    - name: Falhar cedo se faltar algum arquivo
      ansible.builtin.assert:
        that: pg_arquivos.results | map(attribute='stat.exists') | min
        fail_msg: "Arquivos de configuração ausentes em {{ inventory_hostname }}"
      tags: always

    - name: Configurar listen_addresses (exige reinício)
      ansible.builtin.lineinfile:
        path: "{{ pg.conf }}"
        regexp: '^\s*#?\s*listen_addresses\s*='
        line: "listen_addresses = '*'"
        backup: true
      notify: Reiniciar o PostgreSQL
      tags: config

    - name: Permitir a rede dos clientes no pg_hba.conf (basta recarregar)
      ansible.builtin.lineinfile:
        path: "{{ pg.hba }}"
        regexp: '^host\s+all\s+all\s+{{ rede_clientes | regex_escape }}\s'
        line: "host    all    all    {{ rede_clientes }}    scram-sha-256"
        insertafter: EOF
        backup: true
      notify: Recarregar o PostgreSQL
      tags: acesso

    - name: Aplicar as alterações pendentes agora
      ansible.builtin.meta: flush_handlers
      tags:
        - config
        - acesso

    - name: Confirmar que o PostgreSQL ouve no IP do servidor
      ansible.builtin.wait_for:
        host: "{{ ansible_facts['default_ipv4']['address'] }}"
        port: "{{ pg_porta }}"
        timeout: 30
      tags:
        - config
        - acesso
        - verificar

  handlers:
    - name: Reiniciar o PostgreSQL
      ansible.builtin.service:
        name: "{{ pg.servico }}"
        state: restarted

    - name: Recarregar o PostgreSQL
      ansible.builtin.service:
        name: "{{ pg.servico }}"
        state: reloaded
```

### 13.1 Execuções

```bash
# Simular, vendo as diferenças nos arquivos
ansible-playbook -i hosts pg.yml -K --check --diff

# Aplicar em dois hosts
ansible-playbook -i hosts pg.yml -K --limit deb00,deb02

# Apenas a parte do postgresql.conf
ansible-playbook -i hosts pg.yml -K --tags config

# Apenas verificar a porta
ansible-playbook -i hosts pg.yml -K --tags verificar

# Mudando a rede liberada
ansible-playbook -i hosts pg.yml -K -e "rede_clientes=10.0.0.0/16"
```

Para processar **um host de cada vez** (reinícios escalonados), declare `serial: 1` no play, ao lado de `hosts:`. Com bancos de dados replicados, **reinicie um nó por vez** e confirme a saúde antes de seguir para o próximo.

---

## 14. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| O handler nunca roda | A task não alterou nada (`ok`), ou o nome em `notify` não é idêntico | Verificar `changed` e o texto exato do nome |
| Erro dizendo que o handler não foi encontrado | Nome do `notify` diferente do `name` do handler | Copiar o nome exatamente, incluindo maiúsculas |
| Configuração alterada, mas serviço não reiniciou | O play falhou antes do fim e o handler ficou pendente | `force_handlers: true`, ou `flush_handlers` |
| O serviço não sobe após a mudança | `listen_addresses = *` sem aspas, ou outro erro de sintaxe | Usar `'*'` entre aspas; consultar o log do PostgreSQL |
| Mudou `listen_addresses` e só fez `reload` | `listen_addresses` exige reinício | Handler com `state: restarted` |
| Alteração no `pg_hba.conf` não tem efeito | Faltou recarregar | Handler com `state: reloaded` |
| Conexão recusada de outra máquina | Firewall bloqueando a 5432, ou serviço ouvindo só em `localhost` | Liberar a porta e conferir `listen_addresses` |
| "no pg_hba.conf entry for host" | A rede do cliente não está no `pg_hba.conf` | Adicionar a regra e recarregar |
| Handler roda em todos os hosts | Todos tiveram alteração | Comportamento esperado; use `--limit` |
| Handler roda tarde demais | Os handlers rodam no fim do play | `meta: flush_handlers` |
| `flush_handlers` dispara handlers que eu não queria | Aplica todos os handlers pendentes | Reorganizar a ordem das tasks |
| `lineinfile` duplica a linha | `regexp` não casa com a linha existente | Revisar a expressão e testar com `--check --diff` |
| Backup não criado | `backup: true` só gera cópia quando há alteração | Comportamento esperado |
| Nome do serviço incorreto no Red Hat | Repositório PGDG usa `postgresql-16`; AppStream usa `postgresql` | Ajustar a variável `servico` |
| `become_user: postgres` falha ao criar arquivos temporários | Falta o pacote `acl` ou pipelining | Instalar `acl` ou habilitar pipelining |

---

## 15. Boas práticas

1. **Use handlers para qualquer ação que dependa de "mudou"**: reiniciar, recarregar, `daemon-reload`, regenerar índices e caches.
2. **Escolha `reload` quando for suficiente** e `restart` somente quando o parâmetro exigir (como `listen_addresses`). Isso reduz a interrupção do serviço.
3. **Use nomes descritivos e consistentes** (`Reiniciar o PostgreSQL`), e copie-os com exatidão no `notify`.
4. **Use `listen`** para dar nomes de tópico estáveis e permitir vários handlers por evento.
5. **Use `force_handlers: true`** em plays que alteram configurações de serviços, evitando o "handler perdido".
6. **Use `flush_handlers`** antes de verificações que dependem da configuração já estar ativa.
7. **Valide depois de reiniciar** (`wait_for`, `uri`, `pg_isready`), para falhar durante o playbook, e não depois.
8. **Faça backup do arquivo** (`backup: true`) e considere `block`/`rescue` para rollback em serviços críticos.
9. **Teste com `--check --diff`** antes de aplicar mudanças em configuração de banco de dados.
10. **Não reinicie serviços em tasks comuns** com `when: resultado is changed` se um handler resolve: o handler roda uma vez, no momento certo.
11. **Em ambientes com réplicas ou clusters**, reinicie **um nó por vez** (`serial: 1`) e confirme a saúde entre eles.
12. **Prefira `include_dir`/`conf.d`** quando disponível, para separar o que o Ansible gerencia do arquivo original.
13. **Mantenha `listen_addresses = '*'` acompanhado de restrições** no `pg_hba.conf` e no firewall.
14. **Em roles**, use prefixos nos nomes dos handlers ou tópicos `listen`, para evitar colisões.

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Executar ação só se algo mudou | `notify` + handler |
| Handler dispara uma única vez | Comportamento padrão |
| Rodar os handlers na hora | `meta: flush_handlers` |
| Executar handlers mesmo se o play falhar | `force_handlers: true` (ou `--force-handlers`) |
| Vários handlers para um evento | `listen` com tópico |
| Reiniciar serviço | `service: state: restarted` |
| Recarregar configuração | `service: state: reloaded` |
| Alterar uma linha do `postgresql.conf` | `lineinfile` com `regexp` |
| Valor do `listen_addresses` | `'*'` entre aspas simples |
| `listen_addresses` exige | `restart` |
| `pg_hba.conf` exige | `reload` |
| Backup antes de alterar | `backup: true` |
| Desfazer em caso de falha | `block` + `rescue` |
| Confirmar que a porta está ouvindo | `wait_for` com o IP do host |
| Ver o que mudaria | `--check --diff` |
| Handlers em roles | `roles/<nome>/handlers/main.yml` |
