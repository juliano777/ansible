# Capítulo: `delegate_to`

## 1. O que é o `delegate_to`

Normalmente, uma task roda **no host que está sendo processado** pelo play. Se o play tem `hosts: web`, cada task executa em cada servidor `web`.

O `delegate_to` muda isso: ele manda a task **ser executada em outro host**, mas **em nome do host original**. As variáveis, o contexto e o resultado continuam sendo os do host que estava sendo processado.

```yaml
- name: Gravar uma linha no relatório da máquina de controle
  ansible.builtin.lineinfile:
    path: ./relatorio.txt
    line: "{{ inventory_hostname }}: concluído"
    create: true
  delegate_to: localhost
```

Aqui, o play percorre os servidores `web`, mas a task de fato roda em `localhost` (a máquina onde o Ansible está instalado), uma vez para cada host do play, com `inventory_hostname` valendo o nome do host original.

### 1.1 Quando usar

| Situação | Exemplo |
|---|---|
| Executar algo na **máquina de controle** | Gravar relatórios, chamar APIs, rodar scripts locais |
| Atuar em um **balanceador** enquanto atualiza um servidor | Retirar do pool, atualizar, devolver ao pool |
| Registrar o host em um **servidor central** | Monitoramento, inventário, DNS |
| Executar algo em um **servidor de banco** a pedido de um servidor de aplicação | Criar usuário ou banco para a aplicação |
| Realizar tarefas em uma **CA** ou em um servidor de **artefatos** | Emitir certificados, publicar pacotes |
| Coletar **facts** de hosts fora do play | `setup` com `delegate_facts` |
| Sincronizar dados entre dois hosts | `synchronize` |

---

## 2. Como funciona

### 2.1 Quem executa e de quem são as variáveis

| Aspecto | Valor durante a task delegada |
|---|---|
| **Onde** a task executa | No host indicado em `delegate_to` |
| `inventory_hostname` | O host **original** (o que o play está processando) |
| Variáveis e facts disponíveis | Os do host **original** |
| Variáveis de conexão (`ansible_host`, `ansible_user`, `ansible_port`, `ansible_connection`, chave SSH) | As do host **delegado** (se não definidas lá, valem os padrões do play e do `ansible.cfg`) |
| `register` | Gravado no host **original** |
| Falha da task | Contada como falha do host **original** |

Ou seja, o host delegado é só **o lugar onde o comando roda**; o "dono" da task continua sendo o host original.

### 2.2 Como aparece na saída

A saída mostra a delegação com uma seta:

```
TASK [Gravar uma linha no relatório] ***********************
changed: [deb00 -> localhost]
changed: [deb02 -> localhost]
```

`deb00 -> localhost` significa: task do host `deb00`, executada em `localhost`.

### 2.3 Quantas vezes a task roda

Sem `run_once`, a task delegada roda **uma vez para cada host do play**. Se o play tem 10 servidores e você delega para um único host, a task roda 10 vezes nesse host (possivelmente em paralelo; ver seção 6).

---

## 3. Sintaxe e destinos possíveis

### 3.1 `localhost` (máquina de controle)

```yaml
- name: Chamar uma API a partir da máquina de controle
  ansible.builtin.uri:
    url: "https://api.exemplo.com/hosts/{{ inventory_hostname }}"
    method: PUT
  delegate_to: localhost
  become: false
```

Use `localhost` (e não `127.0.0.1`): o nome `localhost` usa por padrão a **conexão local**, sem SSH. Já `127.0.0.1` pode tentar conectar via SSH, conforme o inventário.

### 3.2 Um host ou grupo do inventário

```yaml
delegate_to: lb01
delegate_to: "{{ groups['lb'][0] }}"           # o primeiro host do grupo lb
delegate_to: "{{ groups['monitor'] | first }}" # idem
```

### 3.3 Um host definido por variável

```yaml
vars:
  servidor_ca: ca01.exemplo.com

tasks:
  - name: Emitir o certificado na CA
    ansible.builtin.command: /usr/local/bin/emitir {{ inventory_hostname }}
    delegate_to: "{{ servidor_ca }}"
```

### 3.4 Um host fora do inventário

É possível delegar a um host que não está no inventário (por exemplo, `delegate_to: servidor-externo.exemplo.com`), mas ele não terá variáveis de conexão do inventário: valerão os padrões. Sempre que possível, **declare o host no inventário**, com seus usuários e chaves.

### 3.5 `local_action` (forma antiga)

Em playbooks mais antigos você verá:

```yaml
- name: Gravar no relatório
  local_action:
    module: ansible.builtin.lineinfile
    path: ./relatorio.txt
    line: "{{ inventory_hostname }}"
```

É equivalente a `delegate_to: localhost`. Em código novo, prefira `delegate_to`, que mantém a task com a mesma sintaxe de qualquer outra.

---

## 4. Exemplos práticos

### 4.1 Tarefas na máquina de controle

**Gravar um relatório consolidado:**

```yaml
- name: Gravar uma linha por host
  ansible.builtin.lineinfile:
    path: ./relatorio.csv
    line: "{{ inventory_hostname }};{{ ansible_facts['distribution'] }};{{ ansible_facts['memtotal_mb'] }}"
    create: true
  delegate_to: localhost
  become: false
  throttle: 1
```

(O `throttle: 1` evita escrita simultânea no mesmo arquivo; ver seção 6.)

**Testar um serviço de fora, a partir da máquina de controle:**

```yaml
- name: Verificar se o site responde
  ansible.builtin.uri:
    url: "http://{{ ansible_host | default(inventory_hostname) }}/"
    status_code: 200
  delegate_to: localhost
  become: false
```

**Aguardar uma porta, vista de fora:**

```yaml
- name: Aguardar a porta 80 (vista da máquina de controle)
  ansible.builtin.wait_for:
    host: "{{ ansible_host | default(inventory_hostname) }}"
    port: 80
    timeout: 60
  delegate_to: localhost
  become: false
```

Esse teste valida que a porta está **acessível pela rede**, e não apenas ouvindo localmente no servidor.

### 4.2 Registrar cada host em um servidor central

```yaml
- name: Registrar o host no servidor de monitoramento
  ansible.builtin.lineinfile:
    path: /etc/monitor/hosts.list
    line: "{{ inventory_hostname }} {{ ansible_facts['default_ipv4']['address'] }}"
    create: true
  delegate_to: "{{ groups['monitor'][0] }}"
  become: true
  throttle: 1
```

Cada host do play adiciona a sua linha ao arquivo no servidor de monitoramento, um de cada vez.

### 4.3 Criar usuário e banco no servidor de banco, a pedido da aplicação

```yaml
- name: Criar o usuário da aplicação no PostgreSQL
  community.postgresql.postgresql_user:
    name: "{{ app_db_usuario }}"
    password: "{{ app_db_senha }}"
    state: present
  delegate_to: "{{ groups['db'][0] }}"
  become: true
  become_user: postgres
  no_log: true
  run_once: true
```

O play percorre os servidores de aplicação, mas a criação do usuário acontece **uma vez**, no servidor de banco. O `no_log` protege a senha (ver capítulo de Vault). O módulo exige a coleção `community.postgresql` e a biblioteca `psycopg2` no servidor de banco.

### 4.4 `delegate_to` com `loop`

O destino pode variar por item do loop. Exemplo: executar a mesma ação em **todos** os balanceadores, uma única vez:

```yaml
- name: Recarregar todos os balanceadores
  ansible.builtin.service:
    name: haproxy
    state: reloaded
  delegate_to: "{{ item }}"
  loop: "{{ groups['lb'] }}"
  loop_control:
    label: "{{ item }}"
  become: true
  run_once: true
```

Sem o `run_once`, cada host do play repetiria o loop inteiro, recarregando os balanceadores várias vezes.

Outro exemplo: coletar informações de serviços em cada servidor de banco, guardando-as como facts **dos próprios servidores de banco**:

```yaml
- name: Coletar os serviços de cada servidor de banco
  ansible.builtin.service_facts:
  delegate_to: "{{ item }}"
  delegate_facts: true
  loop: "{{ groups['db'] }}"
  run_once: true
```

Depois, os dados ficam em `hostvars['db01']['ansible_facts']['services']`, e assim por diante (ver seção 7.3 sobre `delegate_facts`).

### 4.5 Sincronizar dados entre dois hosts

```yaml
- name: Copiar o diretório de dados do servidor de origem
  ansible.posix.synchronize:
    src: /srv/dados/
    dest: /srv/dados/
  delegate_to: origem01
```

Com o `synchronize`, a delegação define a **origem** da cópia: os dados saem de `origem01` e vão para o host do play. É necessário ter `rsync` instalado nos dois lados e um caminho SSH entre eles (a conexão parte do host delegado). Requer a coleção `ansible.posix`.

### 4.6 Tarefas em uma CA ou servidor de artefatos

```yaml
- name: Gerar o certificado do host na CA
  ansible.builtin.command: >-
    /usr/local/bin/emitir-certificado --nome {{ inventory_hostname }}
  args:
    creates: "/etc/ca/emitidos/{{ inventory_hostname }}.crt"
  delegate_to: "{{ groups['ca'][0] }}"
  become: true

- name: Buscar o certificado emitido
  ansible.builtin.fetch:
    src: "/etc/ca/emitidos/{{ inventory_hostname }}.crt"
    dest: "certs/{{ inventory_hostname }}.crt"
    flat: true
  delegate_to: "{{ groups['ca'][0] }}"
  become: true
```

---

## 5. `delegate_to` com `run_once`

`run_once: true` faz a task executar **uma única vez** para todo o grupo de hosts, em vez de uma por host. Combinado com `delegate_to`, define **onde** essa única execução acontece:

```yaml
- name: Gerar o relatório final, uma única vez, na máquina de controle
  ansible.builtin.debug:
    msg: "Execução concluída em {{ ansible_play_hosts | length }} hosts"
  delegate_to: localhost
  run_once: true
```

Sem o `delegate_to`, o `run_once` executa a task no **primeiro host** do play; com ele, no host indicado.

Cuidados:

- O resultado de uma task com `run_once` e `register` fica disponível para **todos os hosts** do play.
- Com `serial`, o `run_once` executa **uma vez por lote** (e não uma vez no play inteiro).
- Se a task falhar, ela falha para todos os hosts do lote.

---

## 6. Concorrência: quando vários hosts delegam para o mesmo lugar

O Ansible executa as tasks em vários hosts **em paralelo** (até o limite de `forks`, 5 por padrão). Se dez hosts delegam a task para o mesmo destino, **dez execuções simultâneas** acontecem lá. Em tarefas que alteram o mesmo recurso, isso causa **condições de corrida**:

- dois `lineinfile` alterando o mesmo arquivo ao mesmo tempo (linhas perdidas ou arquivo corrompido);
- vários reinícios simultâneos de um serviço;
- chamadas a uma API que não suporta concorrência.

### 6.1 `throttle`

Limita quantas instâncias da task rodam ao mesmo tempo:

```yaml
- name: Adicionar o host ao arquivo central
  ansible.builtin.lineinfile:
    path: /etc/monitor/hosts.list
    line: "{{ inventory_hostname }}"
  delegate_to: "{{ groups['monitor'][0] }}"
  throttle: 1
```

Com `throttle: 1`, os hosts executam a task um por vez.

### 6.2 `run_once`

Quando basta **uma** execução para todos (por exemplo, reiniciar o balanceador uma vez), use `run_once: true`.

### 6.3 `serial` no play

```yaml
- name: Atualizar os servidores web, um de cada vez
  hosts: web
  serial: 1
```

Com `serial: 1`, o play processa **um host por vez**, e a delegação deixa de ser concorrente. É a base de atualizações contínuas (seção 10).

| Recurso | Alcance | Quando usar |
|---|---|---|
| `throttle: N` | Apenas aquela task | Evitar corrida em uma task específica |
| `run_once: true` | Apenas aquela task | A ação vale para todos e basta uma vez |
| `serial: N` | O play inteiro | Atualizações em lotes, uma etapa por vez |
| `forks` (no `ansible.cfg` ou `-f`) | Todo o Ansible | Ajustar o paralelismo geral |

---

## 7. Variáveis, facts e `register` em tasks delegadas

### 7.1 Quem é `inventory_hostname`

Em uma task delegada, `inventory_hostname` é o host **original**. Para saber o nome do host onde a task executa, guarde-o em uma variável:

```yaml
vars:
  balanceador: "{{ groups['lb'][0] }}"

tasks:
  - name: Mostrar quem é quem
    ansible.builtin.debug:
      msg: "Task do host {{ inventory_hostname }}, executada em {{ balanceador }}"
    delegate_to: "{{ balanceador }}"
```

### 7.2 Variáveis do host delegado: `hostvars`

Para usar dados do host delegado (como o IP), consulte `hostvars`:

```yaml
- name: Mostrar o IP do balanceador
  ansible.builtin.debug:
    msg: "{{ hostvars[balanceador]['ansible_host'] | default(balanceador) }}"
  delegate_to: "{{ balanceador }}"
```

Para facts do host delegado, eles precisam ter sido coletados antes (seção 7.3).

### 7.3 `delegate_facts`

Por padrão, os facts que uma task delegada produz (`setup`, `set_fact`, `package_facts`) são atribuídos ao host **original**. Com `delegate_facts: true`, passam a ser atribuídos ao host **delegado**.

Caso clássico: um play que atua nos servidores `web`, mas precisa dos facts dos servidores `db`:

```yaml
- name: Coletar os facts dos servidores de banco
  ansible.builtin.setup:
  delegate_to: "{{ item }}"
  delegate_facts: true
  loop: "{{ groups['db'] }}"
  run_once: true

- name: Usar o IP do banco na configuração da aplicação
  ansible.builtin.debug:
    msg: "Banco em {{ hostvars[groups['db'][0]]['ansible_facts']['default_ipv4']['address'] }}"
```

Sem `delegate_facts: true`, os facts dos hosts `db` seriam gravados como se pertencessem a cada servidor `web`, o que causa confusão difícil de depurar.

### 7.4 `register`

O `register` sempre fica associado ao host **original**:

```yaml
- name: Consultar o horário do balanceador
  ansible.builtin.command: date +%s
  register: hora_lb
  delegate_to: "{{ balanceador }}"
  changed_when: false

- name: Usar o resultado (no host original)
  ansible.builtin.debug:
    msg: "{{ inventory_hostname }} viu o horário {{ hora_lb.stdout }} no balanceador"
```

---

## 8. Conexão, `become` e interpretador Python

### 8.1 Variáveis de conexão

As variáveis de conexão (`ansible_host`, `ansible_user`, `ansible_port`, `ansible_ssh_private_key_file`, `ansible_connection`) vêm do **host delegado**. Por isso, um host delegado precisa estar acessível a partir da **máquina de controle** com as credenciais corretas, mesmo que o host original nunca converse com ele.

### 8.2 `become` em `localhost`

Em tasks delegadas a `localhost`, use `become: false`, a menos que realmente precise de privilégios na máquina de controle:

```yaml
- name: Gravar o relatório
  ansible.builtin.copy:
    dest: ./relatorio.txt
    content: "..."
  delegate_to: localhost
  become: false
```

Sem isso, o `become: true` do play tentaria usar `sudo` na máquina de controle e pediria senha ou falharia.

### 8.3 `become` no host delegado

O `become` se aplica ao host **onde a task executa**. Se o servidor delegado usa um método ou usuário diferente, declare-o no inventário (`ansible_become_user`, `ansible_become_method`) ou na própria task.

A senha informada com `-K` (`--ask-become-pass`) é a mesma para todos os hosts; se o host delegado tem senha de `sudo` diferente, defina `ansible_become_password` (de preferência com Vault).

### 8.4 Python e bibliotecas em `localhost`

Em tasks delegadas a `localhost`, o módulo roda com o interpretador Python da **máquina de controle** (o mesmo do Ansible, por exemplo o de um ambiente virtual). Qualquer biblioteca exigida pelo módulo (`requests`, `psycopg2`, `boto3`, `jmespath`) precisa estar instalada **ali**, e não nos hosts remotos.

```bash
pip install requests
```

Se o módulo reclama que falta uma biblioteca em uma task `delegate_to: localhost`, o problema está na máquina de controle.

---

## 9. `delegate_to` em blocos e handlers

### 9.1 Em um bloco

A diretiva vale para todas as tasks do bloco (ver capítulo de blocks):

```yaml
- name: Operações no servidor de monitoramento
  delegate_to: "{{ groups['monitor'][0] }}"
  become: true
  block:
    - name: Registrar o host
      ansible.builtin.lineinfile:
        path: /etc/monitor/hosts.list
        line: "{{ inventory_hostname }}"
      throttle: 1

    - name: Recarregar a configuração do monitoramento
      ansible.builtin.service:
        name: monitor
        state: reloaded
      run_once: true
```

### 9.2 Em handlers

Um handler também aceita `delegate_to`, útil para recarregar um serviço **em outro host** quando algo muda:

```yaml
tasks:
  - name: Atualizar a entrada do host no arquivo do balanceador
    ansible.builtin.lineinfile:
      path: /etc/haproxy/servidores.cfg
      line: "server {{ inventory_hostname }} {{ ansible_host }}:80 check"
    delegate_to: "{{ groups['lb'][0] }}"
    become: true
    throttle: 1
    notify: Recarregar o balanceador

handlers:
  - name: Recarregar o balanceador
    ansible.builtin.service:
      name: haproxy
      state: reloaded
    delegate_to: "{{ groups['lb'][0] }}"
    become: true
```

O handler roda uma vez (por regra dos handlers), no balanceador.

---

## 10. Exemplo completo: atualização contínua atrás de um balanceador

Cenário: atualizar os servidores web **um de cada vez**, retirando cada um do balanceador antes e devolvendo-o depois de confirmar que voltou a funcionar. Esse é o uso mais clássico do `delegate_to`.

```yaml
---
- name: Atualização contínua dos servidores web
  hosts: web
  gather_facts: true
  become: true
  serial: 1                       # um servidor por vez

  vars:
    balanceador: "{{ groups['lb'][0] }}"
    haproxy_backend: web
    haproxy_socket: /run/haproxy/admin.sock

    pacote_web:
      Debian: apache2
      RedHat: httpd

  tasks:
    - name: Validar que existe um balanceador no inventário
      ansible.builtin.assert:
        that: groups['lb'] | default([]) | length > 0
        fail_msg: "Nenhum host no grupo 'lb'"
      run_once: true
      tags: always

    - name: Atualizar o servidor com segurança
      tags: upgrade
      block:
        - name: Retirar o servidor do balanceador
          community.general.haproxy:
            state: disabled
            host: "{{ inventory_hostname }}"
            backend: "{{ haproxy_backend }}"
            socket: "{{ haproxy_socket }}"
            wait: true
          delegate_to: "{{ balanceador }}"

        - name: Atualizar o pacote do servidor web
          ansible.builtin.package:
            name: "{{ pacote_web[ansible_facts['os_family']] }}"
            state: latest

        - name: Reiniciar o serviço
          ansible.builtin.service:
            name: "{{ pacote_web[ansible_facts['os_family']] }}"
            state: restarted

        - name: Aguardar a porta 80, vista da máquina de controle
          ansible.builtin.wait_for:
            host: "{{ ansible_host | default(inventory_hostname) }}"
            port: 80
            timeout: 60
          delegate_to: localhost
          become: false

        - name: Devolver o servidor ao balanceador
          community.general.haproxy:
            state: enabled
            host: "{{ inventory_hostname }}"
            backend: "{{ haproxy_backend }}"
            socket: "{{ haproxy_socket }}"
            wait: true
          delegate_to: "{{ balanceador }}"

      rescue:
        - name: Manter o servidor fora do balanceador e avisar
          ansible.builtin.debug:
            msg: >-
              FALHA em {{ inventory_hostname }}: o servidor permanece FORA do balanceador.
              Motivo: {{ ansible_failed_result.msg | default('desconhecido') }}

        - name: Interromper a atualização
          ansible.builtin.fail:
            msg: "Atualização interrompida em {{ inventory_hostname }}"
```

### 10.1 Como funciona

1. `serial: 1` processa um servidor por vez; os demais continuam atendendo pelo balanceador.
2. A primeira task delegada (`delegate_to: lb`) coloca o servidor atual em modo `disabled` no HAProxy, **sem tocar nele**.
3. As tasks seguintes atualizam e reiniciam o servidor (sem delegação: rodam nele).
4. O `wait_for` delegado a `localhost` confirma que a porta 80 responde **vista de fora**.
5. A última task delegada devolve o servidor ao balanceador.
6. Se **qualquer** etapa falhar, o `rescue` avisa e **mantém o servidor fora do balanceador**, em vez de devolvê-lo em estado duvidoso, e o `fail` interrompe a atualização dos servidores seguintes (com o padrão de `max_fail_percentage`, a falha aborta o restante do play).

### 10.2 Observações

- O módulo `community.general.haproxy` exige a coleção `community.general` e acesso ao *socket* de administração do HAProxy (por isso o `become` do play se aplica ao `lb`). O valor de `host` deve ser o **nome do servidor como está na configuração do HAProxy**. Se o nome lá for diferente de `inventory_hostname`, use uma variável por host.
- Para outros balanceadores, a mesma estrutura funciona com o módulo ou a API correspondente (por exemplo, `ansible.builtin.uri` chamando a API do balanceador, com `delegate_to: localhost`).
- A etapa de reinício poderia ser um handler; aqui foi mantida como task explícita para que o `wait_for` e a devolução ao balanceador dependam dela de forma previsível.

### 10.3 Execuções

```bash
# Simulação
ansible-playbook -i hosts rolling.yml -K --check

# Um único servidor, para testar o procedimento
ansible-playbook -i hosts rolling.yml -K --limit web01 --tags upgrade

# Todos, um por vez
ansible-playbook -i hosts rolling.yml -K
```

---

## 11. Alternativas ao `delegate_to`

| Necessidade | Alternativa | Observação |
|---|---|---|
| Rodar um conjunto de tasks em **outro grupo** de hosts | Outro **play** com `hosts: lb` | Mais claro quando há muitas tasks para o outro host |
| Executar na máquina de controle um play inteiro | `hosts: localhost` com `connection: local` | Para playbooks que só tocam a máquina de controle |
| Uma única execução para todo o grupo | `run_once: true` | Combina com `delegate_to` |
| Usar dados de outro host em tasks do host atual | `hostvars[...]` | Não precisa executar nada lá |
| Adicionar hosts dinamicamente | `ansible.builtin.add_host` | Cria hosts e grupos em memória |
| Reorganizar o fluxo entre hosts diferentes | Vários plays em sequência | Pode usar `hosts: all` e `when` |

**Como escolher:** se é **uma ou duas tasks** pontuais em outro host, use `delegate_to`. Se são **muitas tasks** para o outro host, um play separado costuma ser mais legível.

Exemplo de play separado, equivalente a uma sequência de tasks delegadas:

```yaml
- name: Preparar o balanceador
  hosts: lb
  become: true
  tasks:
    - name: Recarregar o balanceador
      ansible.builtin.service:
        name: haproxy
        state: reloaded

- name: Atualizar os servidores web
  hosts: web
  become: true
  tasks:
    - name: Atualizar o pacote
      ansible.builtin.package:
        name: apache2
        state: latest
```

---

## 12. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| A task roda N vezes no host delegado | Sem `run_once`, roda uma vez por host do play | `run_once: true` se bastar uma vez |
| Arquivo corrompido ou linhas perdidas no destino | Escritas simultâneas de vários hosts | `throttle: 1` ou `serial: 1` |
| `sudo` pede senha na máquina de controle | `become: true` herdado do play em `delegate_to: localhost` | `become: false` na task |
| `Failed to connect` ao host delegado | O controle não alcança o host delegado, ou faltam usuário e chave | Conferir as variáveis de conexão do host delegado no inventário |
| Módulo reclama de biblioteca ausente em `localhost` | A biblioteca precisa estar na máquina de controle | `pip install` no ambiente do Ansible |
| `inventory_hostname` mostra o host "errado" | Em tasks delegadas, é o host **original** | Guardar o destino em uma variável |
| Facts do host delegado vêm misturados com os do original | Faltou `delegate_facts: true` | Usar `delegate_facts` |
| `hostvars[...]['ansible_facts']` está vazio | Facts do host não foram coletados na execução | `setup` com `delegate_facts: true`, ou cache de facts |
| `delegate_to: 127.0.0.1` tenta SSH | O IP não usa a conexão local por padrão | Usar `localhost` ou `ansible_connection=local` |
| Falha na task delegada aparece no host "errado" | A falha é atribuída ao host original | Ler a seta na saída (`deb00 -> lb01`) |
| `run_once` com `serial` executa várias vezes | Roda uma vez **por lote** | Usar `when: inventory_hostname == ansible_play_hosts_all[0]` |
| Task no balanceador falha por permissão | O `become` do play não vale para o `lb`, ou o usuário não acessa o socket | Ajustar `become` e o usuário do host delegado |
| `synchronize` com `delegate_to` copia no sentido errado | A delegação define a origem | Conferir `src` e `dest`, e o modo (`mode: push` ou `pull`) |
| Host fora do inventário sem variáveis de conexão | Delegação para um host desconhecido | Declarar o host no inventário |
| `--check` não reflete a delegação | Em `--check`, a task delegada também é simulada | Comportamento esperado |
| Pausa ou lentidão em delegações com muitos hosts | Delegação sequencial por `throttle` | Reavaliar se `throttle: 1` é necessário em toda a task |

---

## 13. Boas práticas

1. **Use `delegate_to: localhost`** (e não `127.0.0.1`) para tarefas na máquina de controle, com `become: false`.
2. **Combine com `run_once: true`** quando a ação deve acontecer uma única vez para todo o grupo.
3. **Proteja contra concorrência:** use `throttle: 1` ou `serial` quando vários hosts alteram o mesmo recurso.
4. **Declare os hosts delegados no inventário**, com suas variáveis de conexão.
5. **Guarde o destino em uma variável** (`balanceador: "{{ groups['lb'][0] }}"`) para deixar o código legível.
6. **Use `delegate_facts: true`** quando a task delegada gera facts que pertencem ao host delegado.
7. **Instale as bibliotecas Python na máquina de controle** quando delegar módulos a `localhost`.
8. **Use `block` e `rescue` em operações delegadas críticas** (como tirar um servidor do balanceador), para tratar a falha de forma segura.
9. **Em falha, deixe o servidor fora do balanceador;** devolver um servidor quebrado ao pool é pior que mantê-lo fora.
10. **Prefira um play separado** quando houver muitas tasks para o outro host.
11. **Use `no_log: true`** em tasks delegadas que manipulam segredos.
12. **Teste com `--check`**, `--limit` em um único host e `serial: 1` antes de aplicar em todos.
13. **Leia a saída:** a notação `host -> destino` mostra o que está sendo executado onde.

---

## Resumo

| Necessidade | Solução |
|---|---|
| Rodar a task em outro host | `delegate_to: host` |
| Rodar na máquina de controle | `delegate_to: localhost` + `become: false` |
| Rodar uma única vez para todo o grupo | `run_once: true` |
| Destino definido por variável ou grupo | `delegate_to: "{{ groups['lb'][0] }}"` |
| Destino variando por item | `delegate_to: "{{ item }}"` com `loop` |
| Evitar escrita simultânea no destino | `throttle: 1` |
| Atualizar um servidor por vez | `serial: 1` no play |
| Facts pertencem ao host delegado | `delegate_facts: true` |
| Dados de outro host sem executar nada nele | `hostvars['host']` |
| Variáveis de conexão usadas | As do host **delegado** |
| `inventory_hostname` na task delegada | O host **original** |
| `register` na task delegada | Fica no host **original** |
| Aplicar a vários passos | `block` com `delegate_to` |
| Reagir a uma mudança em outro host | Handler com `delegate_to` |
| Forma antiga | `local_action` (equivale a `delegate_to: localhost`) |
| Muitas tasks no outro host | Play separado com `hosts:` |
| Como aparece na saída | `host_original -> host_delegado` |
