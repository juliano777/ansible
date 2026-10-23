# Capítulo: O módulo `ansible.builtin.stat`

## 1. O que é o `stat`

O módulo `ansible.builtin.stat` **consulta informações** sobre um arquivo, diretório, link simbólico ou sistema de arquivos no host gerenciado: se existe, de que tipo é, tamanho, permissões, dono, datas, checksum e mais. É o equivalente do comando `stat` do Linux, mas devolvendo os dados de forma estruturada, pronta para uso em condições.

Características importantes:

- **Somente leitura:** nunca altera nada e **nunca** retorna `changed`.
- **Funciona em `--check`:** por ser apenas consulta, roda normalmente no modo simulação (diferente de `command` e `shell`, que são pulados).
- **Executa no host remoto,** não na máquina de controle.
- O resultado é guardado com `register` e usado em `when`, mensagens e templates.

O uso mais comum, que já apareceu nos capítulos de `register` e de condicionais:

```yaml
- name: Verificar o arquivo
  ansible.builtin.stat:
    path: /etc/exemplo.conf
  register: arq

- name: Criar se não existir
  ansible.builtin.copy:
    dest: /etc/exemplo.conf
    content: "configuracao=padrao\n"
    mode: "0644"
  when: not arq.stat.exists
```

---

## 2. Parâmetros

| Parâmetro | Padrão | Descrição |
|---|---|---|
| `path` | (obrigatório) | Caminho do arquivo, diretório ou link a consultar |
| `follow` | `false` | Se `true`, segue links simbólicos e reporta o **destino** |
| `get_checksum` | `true` | Calcula o checksum (apenas arquivos regulares) |
| `checksum_algorithm` | `sha1` | Algoritmo: `md5`, `sha1`, `sha224`, `sha256`, `sha384`, `sha512` |
| `get_mime` | `true` | Detecta o tipo MIME e o charset |
| `get_attributes` | `true` | Lê atributos do sistema de arquivos (como os de `lsattr`) |

Exemplo com ajustes de desempenho e algoritmo:

```yaml
- name: Checksum SHA-256 de um arquivo
  ansible.builtin.stat:
    path: /usr/local/bin/app
    checksum_algorithm: sha256
    get_mime: false
    get_attributes: false
  register: bin_app
```

> **Desempenho:** o checksum lê o arquivo inteiro. Em arquivos grandes, ou em muitos arquivos, use `get_checksum: false` quando só precisar saber se existe.

---

## 3. A estrutura do resultado

Rodando de forma ad-hoc para ver o retorno:

```bash
ansible deb00 -i hosts -m ansible.builtin.stat -a "path=/etc/hosts"
```

Resultado (resumido):

```json
{
    "changed": false,
    "stat": {
        "exists": true,
        "path": "/etc/hosts",
        "isreg": true,
        "isdir": false,
        "islnk": false,
        "mode": "0644",
        "uid": 0,
        "gid": 0,
        "pw_name": "root",
        "gr_name": "root",
        "size": 221,
        "mtime": 1760000000.0,
        "checksum": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b",
        "mimetype": "text/plain",
        "readable": true,
        "writeable": true,
        "executable": false
    }
}
```

Note que os dados ficam dentro da chave **`stat`**. Com `register: arq`, o acesso é `arq.stat.exists`, `arq.stat.size` e assim por diante.

### 3.1 Atributos mais usados

| Atributo | Tipo | Descrição |
|---|---|---|
| `exists` | booleano | Se o caminho existe (**sempre presente**) |
| `isreg` | booleano | É arquivo regular |
| `isdir` | booleano | É diretório |
| `islnk` | booleano | É link simbólico |
| `isblk`, `ischr`, `isfifo`, `issock` | booleano | Dispositivo de bloco, de caractere, FIFO, socket |
| `mode` | texto | Permissões em octal, como `"0644"` |
| `uid`, `gid` | número | IDs do dono e do grupo |
| `pw_name`, `gr_name` | texto | Nomes do dono e do grupo |
| `size` | número | Tamanho em bytes |
| `atime`, `mtime`, `ctime` | decimal | Acesso, modificação e mudança (segundos desde 1970) |
| `checksum` | texto | Hash do conteúdo (arquivos regulares) |
| `mimetype`, `charset` | texto | Tipo e codificação detectados |
| `readable`, `writeable`, `executable` | booleano | Permissões do usuário que executa o módulo |
| `rusr`, `wusr`, `xusr` | booleano | Leitura, escrita e execução do **dono** |
| `rgrp`, `wgrp`, `xgrp` | booleano | Idem, para o **grupo** |
| `roth`, `woth`, `xoth` | booleano | Idem, para **outros** |
| `isuid`, `isgid` | booleano | Bits setuid e setgid |
| `lnk_source` | texto | Caminho absoluto resolvido do link (em links) |
| `lnk_target` | texto | Destino do link como foi criado (em links) |
| `nlink`, `inode`, `dev` | número | Links físicos, inode e dispositivo |

### 3.2 Quando o caminho não existe

Se o caminho não existe, o resultado é **apenas**:

```json
{ "changed": false, "stat": { "exists": false } }
```

Isso tem uma consequência importante: `arq.stat.isdir` **não existe** nesse caso. Por isso, sempre teste `exists` primeiro:

```yaml
# Seguro
when: arq.stat.exists and arq.stat.isdir

# Perigoso: pode falhar se o caminho não existir
when: arq.stat.isdir
```

O `and` interrompe a avaliação no primeiro valor falso, protegendo o restante da expressão.

---

## 4. Uso básico

### 4.1 Existência

```yaml
- name: Checar o arquivo
  ansible.builtin.stat:
    path: /etc/ssh/sshd_config
  register: sshd

- name: Avisar se não existir
  ansible.builtin.debug:
    msg: "sshd_config não encontrado em {{ inventory_hostname }}"
  when: not sshd.stat.exists
```

### 4.2 Tipo: arquivo, diretório ou link

```yaml
- name: Checar o caminho
  ansible.builtin.stat:
    path: /opt/app
  register: app

- name: Criar o diretório se não existir
  ansible.builtin.file:
    path: /opt/app
    state: directory
    mode: "0755"
  when: not app.stat.exists

- name: Falhar se existir, mas não for um diretório
  ansible.builtin.fail:
    msg: "/opt/app existe, mas não é um diretório"
  when: app.stat.exists and not app.stat.isdir
```

### 4.3 Permissões e dono

```yaml
- name: Checar a chave privada
  ansible.builtin.stat:
    path: /etc/ssl/private/servidor.key
  register: chave

- name: Verificar as permissões
  ansible.builtin.assert:
    that:
      - chave.stat.exists
      - chave.stat.mode == "0600"
      - chave.stat.pw_name == "root"
    fail_msg: "A chave não está com modo 0600 e dono root"
```

Observe que `mode` é um **texto**: compare com `"0600"` entre aspas.

### 4.4 Tamanho

```yaml
- name: Checar o log
  ansible.builtin.stat:
    path: /var/log/app.log
    get_checksum: false
    get_mime: false
  register: log

- name: Alertar se passar de 100 MB
  ansible.builtin.debug:
    msg: "Log com {{ log.stat.size | human_readable }}"
  when:
    - log.stat.exists
    - log.stat.size > 104857600
```

### 4.5 Idade do arquivo

As datas são em segundos desde 1970. Combine com o fact `date_time.epoch`:

```yaml
- name: Checar o arquivo de backup
  ansible.builtin.stat:
    path: /backup/dados.tar.gz
    get_checksum: false
  register: backup

- name: Alertar se o backup tem mais de 24 horas
  ansible.builtin.debug:
    msg: >-
      Backup desatualizado: {{ ((ansible_facts['date_time']['epoch'] | int - backup.stat.mtime | int) / 3600) | round(1) }} horas
  when:
    - backup.stat.exists
    - (ansible_facts['date_time']['epoch'] | int - backup.stat.mtime | int) > 86400
```

Para verificar a idade de **vários** arquivos de uma vez, o módulo `find` (com `age:`) costuma ser mais adequado.

---

## 5. Links simbólicos

Por padrão, o `stat` descreve o **próprio link**, e não o destino:

```yaml
- name: Checar o link
  ansible.builtin.stat:
    path: /etc/alternatives/editor
  register: link

- ansible.builtin.debug:
    msg:
      - "É link? {{ link.stat.islnk }}"
      - "Aponta para: {{ link.stat.lnk_source }}"
```

Com `follow: true`, o módulo segue o link e devolve os dados do **destino**:

```yaml
- name: Checar o destino do link
  ansible.builtin.stat:
    path: /etc/alternatives/editor
    follow: true
  register: destino
```

Diferença na prática:

| Situação | `follow: false` (padrão) | `follow: true` |
|---|---|---|
| Link para um diretório | `islnk: true`, `isdir: false` | `islnk: false`, `isdir: true` |
| Link quebrado | `exists: true`, `islnk: true` | `exists: false` |
| Tamanho (`size`) | Tamanho do link | Tamanho do arquivo de destino |

Use `follow: true` quando só importa o destino real, e o padrão quando precisa saber se **é** um link ou para onde aponta.

---

## 6. Comparando conteúdo com o checksum

O checksum permite saber se um arquivo é o esperado, sem baixá-lo para a máquina de controle:

```yaml
vars:
  checksum_esperado: "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3"

tasks:
  - name: Obter o checksum atual
    ansible.builtin.stat:
      path: /usr/local/bin/app
      checksum_algorithm: sha1
    register: bin

  - name: Baixar novamente se estiver diferente ou ausente
    ansible.builtin.get_url:
      url: https://exemplo.com/app
      dest: /usr/local/bin/app
      mode: "0755"
    when: not bin.stat.exists or bin.stat.checksum != checksum_esperado
```

Atenção:

- O `checksum` só existe para **arquivos regulares** legíveis.
- O algoritmo do `checksum_algorithm` deve ser o mesmo usado para calcular o valor esperado.
- Para baixar e validar em uma única task, o `get_url` tem o parâmetro `checksum:`, que dispensa o `stat`.

---

## 7. Verificando vários caminhos

### 7.1 Com `loop`

```yaml
- name: Checar vários arquivos
  ansible.builtin.stat:
    path: "{{ item }}"
    get_checksum: false
    get_mime: false
  loop:
    - /etc/hosts
    - /etc/hostname
    - /etc/nao-existe
  register: arquivos

- name: Mostrar o resultado
  ansible.builtin.debug:
    msg: "{{ item.item }}: {{ 'existe' if item.stat.exists else 'não existe' }}"
  loop: "{{ arquivos.results }}"
  loop_control:
    label: "{{ item.item }}"
```

Com loop, o resultado fica em `arquivos.results`, e `item.item` é o valor original do loop.

### 7.2 Listar apenas os que existem

```yaml
- name: Arquivos que existem
  ansible.builtin.debug:
    msg: "{{ arquivos.results | selectattr('stat.exists') | map(attribute='item') | list }}"
```

### 7.3 Listar os que faltam

```yaml
- name: Arquivos ausentes
  ansible.builtin.debug:
    msg: "{{ arquivos.results | rejectattr('stat.exists') | map(attribute='item') | list }}"
```

### 7.4 Falhar se algum for obrigatório e estiver ausente

```yaml
- name: Exigir todos os arquivos
  ansible.builtin.assert:
    that: arquivos.results | map(attribute='stat.exists') | min
    fail_msg: "Há arquivos obrigatórios ausentes"
```

---

## 8. `stat` em ambientes Debian e Red Hat

Alguns exemplos que funcionam de forma diferente por família:

### 8.1 Reinício pendente

```yaml
- name: Checar reinício pendente (Debian)
  ansible.builtin.stat:
    path: /var/run/reboot-required
  register: reboot_debian
  when: ansible_facts['os_family'] == "Debian"

- name: Avisar
  ansible.builtin.debug:
    msg: "{{ inventory_hostname }} precisa reiniciar"
  when: reboot_debian.stat.exists | default(false)
```

No Red Hat não existe esse arquivo; lá se usa `needs-restarting -r` (do pacote `dnf-utils`), como mostrado no capítulo de condicionais.

### 8.2 Arquivo de configuração por distribuição

```yaml
- name: Localizar o arquivo de configuração do Apache
  ansible.builtin.stat:
    path: "{{ item }}"
  loop:
    - /etc/apache2/apache2.conf
    - /etc/httpd/conf/httpd.conf
  register: apache_conf

- name: Definir o caminho encontrado
  ansible.builtin.set_fact:
    apache_conf_path: "{{ (apache_conf.results | selectattr('stat.exists') | map(attribute='item') | list | first) | default('') }}"
```

### 8.3 Verificar a existência do repositório de pacotes

```yaml
- name: Checar o repositório externo
  ansible.builtin.stat:
    path: "{{ '/etc/apt/sources.list.d/exemplo.list' if ansible_facts['os_family'] == 'Debian' else '/etc/yum.repos.d/exemplo.repo' }}"
  register: repo
```

---

## 9. Esperando um arquivo aparecer

Combinando `stat` com `until`:

```yaml
- name: Aguardar o arquivo de pronto
  ansible.builtin.stat:
    path: /var/run/app.ready
  register: pronto
  until: pronto.stat.exists
  retries: 12
  delay: 5
```

Tenta por até 12 vezes, a cada 5 segundos (cerca de 1 minuto). Para esse caso específico, o módulo `ansible.builtin.wait_for` é mais direto:

```yaml
- name: Aguardar o arquivo (versão com wait_for)
  ansible.builtin.wait_for:
    path: /var/run/app.ready
    timeout: 60
```

---

## 10. Quando **não** usar o `stat`

Muitos módulos já são idempotentes e **dispensam** o `stat`:

| Em vez de... | Use |
|---|---|
| `stat` + `copy` quando o arquivo não existe | `copy` (já compara o conteúdo) com `force: false` para não sobrescrever |
| `stat` + `file: state: directory` | `file: state: directory` (cria só se faltar) |
| `stat` + `command` | `command` com `creates:` ou `removes:` |
| `stat` + `file: state: absent` | `file: state: absent` (remove só se existir) |
| `stat` + `lineinfile` | `lineinfile` (já verifica se a linha existe) |

Exemplo com `creates`:

```yaml
# Em vez de stat + when
- name: Extrair o pacote, só se ainda não foi extraído
  ansible.builtin.command: tar -xzf /tmp/app.tar.gz -C /opt
  args:
    creates: /opt/app/bin/app
```

O `stat` é a escolha certa quando você precisa **decidir** algo com base nos atributos (tamanho, idade, dono, tipo, checksum) ou quando o resultado alimenta várias tasks.

---

## 11. `stat` × módulos relacionados

| Necessidade | Módulo |
|---|---|
| Consultar um caminho | `ansible.builtin.stat` |
| Buscar arquivos por padrão, idade ou tamanho (com curingas) | `ansible.builtin.find` |
| Criar, remover ou ajustar permissão | `ansible.builtin.file` |
| Ler o **conteúdo** de um arquivo remoto | `ansible.builtin.slurp` (retorna em base64) |
| Esperar um arquivo ou porta | `ansible.builtin.wait_for` |
| Arquivos em hosts Windows | `ansible.windows.win_stat` |

Observações:

- O `stat` **não aceita curingas** (`*`, `?`). O caminho é literal. Para padrões, use `find`.
- O `stat` **não é recursivo**; descreve só o caminho informado.

---

## 12. Consultando a máquina de controle

O `stat` roda no host remoto. Para consultar um arquivo na **máquina de controle**, delegue para `localhost`:

```yaml
- name: Checar um arquivo local
  ansible.builtin.stat:
    path: ./vars/segredos.yml
  delegate_to: localhost
  become: false
  register: arq_local
```

Alternativamente, os testes `is file` e `is directory` em condições também avaliam na máquina de controle (ver capítulo de condicionais).

---

## 13. Exemplo completo

Auditoria de arquivos importantes, em Debian e Red Hat, com relatório e alertas:

```yaml
---
- name: Auditoria de arquivos com stat
  hosts: all
  gather_facts: true
  become: true

  vars:
    arquivos_criticos:
      - { path: /etc/passwd,           modo: "0644", dono: root }
      - { path: /etc/shadow,           modo: "0640", dono: root }
      - { path: /etc/ssh/sshd_config,  modo: "0600", dono: root }
    limite_log_mb: 100

  tasks:
    - name: Coletar informações dos arquivos críticos
      ansible.builtin.stat:
        path: "{{ item.path }}"
        get_checksum: false
        get_mime: false
        get_attributes: false
      loop: "{{ arquivos_criticos }}"
      loop_control:
        label: "{{ item.path }}"
      register: auditoria
      tags: auditoria

    - name: Reportar arquivos ausentes
      ansible.builtin.debug:
        msg: "AUSENTE em {{ inventory_hostname }}: {{ item.item.path }}"
      loop: "{{ auditoria.results }}"
      loop_control:
        label: "{{ item.item.path }}"
      when: not item.stat.exists
      tags: auditoria

    - name: Reportar permissões ou dono fora do esperado
      ansible.builtin.debug:
        msg: >-
          DIVERGENTE em {{ inventory_hostname }}: {{ item.item.path }}
          (modo {{ item.stat.mode }}, dono {{ item.stat.pw_name }};
          esperado {{ item.item.modo }}/{{ item.item.dono }})
      loop: "{{ auditoria.results }}"
      loop_control:
        label: "{{ item.item.path }}"
      when:
        - item.stat.exists
        - item.stat.mode != item.item.modo or item.stat.pw_name != item.item.dono
      tags: auditoria

    - name: Checar o log do sistema
      ansible.builtin.stat:
        path: "{{ '/var/log/syslog' if ansible_facts['os_family'] == 'Debian' else '/var/log/messages' }}"
        get_checksum: false
        get_mime: false
      register: syslog
      tags: logs

    - name: Alertar sobre log grande
      ansible.builtin.debug:
        msg: "Log com {{ syslog.stat.size | human_readable }} em {{ inventory_hostname }}"
      when:
        - syslog.stat.exists
        - syslog.stat.size > (limite_log_mb * 1024 * 1024)
      tags: logs

    - name: Checar reinício pendente (Debian)
      ansible.builtin.stat:
        path: /var/run/reboot-required
      register: reboot_debian
      when: ansible_facts['os_family'] == "Debian"
      tags: reboot

    - name: Avisar sobre reinício pendente
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} precisa de reinício"
      when: reboot_debian.stat.exists | default(false)
      tags: reboot
```

Execuções:

```bash
ansible-playbook -i hosts auditoria.yml -K
ansible-playbook -i hosts auditoria.yml -K --tags auditoria --limit deb00,deb02
ansible-playbook -i hosts auditoria.yml -K --tags logs -e "limite_log_mb=50"
```

---

## 14. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `'dict object' has no attribute 'isdir'` | O caminho não existe, e só `exists` é retornado | `x.stat.exists and x.stat.isdir` |
| `x.stat.checksum` indefinido | É diretório, link, ou não é legível | Verificar `isreg` e permissões |
| Comparação de `mode` falha | `mode` é texto, e você comparou com número | Usar `== "0644"` entre aspas |
| Link para diretório aparece como `isdir: false` | `follow` é `false` por padrão | Usar `follow: true` |
| Erro de permissão ao consultar | O usuário não pode acessar o diretório pai | Usar `become: true` |
| O `stat` está lento | Checksum e MIME em arquivos grandes | `get_checksum: false` e `get_mime: false` |
| Caminho com curinga não funciona | `stat` não aceita curingas | Usar `find` |
| O resultado é do host errado | `stat` roda no host remoto | `delegate_to: localhost` para o controle |
| `mtime` com casas decimais atrapalha o cálculo | É um número decimal | Converter com `\| int` |
| Variável registrada sem `stat` | A task foi pulada por `when` | `is not skipped` ou `default()` |
| Em loop não acho `stat` | Resultados estão em `.results` | Iterar sobre `x.results` |
| Hosts Windows retornam erro | Módulo é para Linux e Unix | Usar `ansible.windows.win_stat` |

---

## 15. Boas práticas

1. **Teste `exists` antes dos outros atributos:** `x.stat.exists and x.stat.isdir`.
2. **Desative o que não usa:** `get_checksum: false`, `get_mime: false` e `get_attributes: false` aceleram a consulta.
3. **Prefira módulos idempotentes** (`copy`, `file`, `lineinfile`, `command` com `creates`) quando eles já resolvem o problema, e reserve o `stat` para decisões baseadas em atributos.
4. **Dê nomes descritivos** às variáveis registradas (`sshd_conf`, `log_sistema`, `reboot_debian`).
5. **Use `follow: true` com consciência,** sabendo que muda o que é reportado em links.
6. **Compare o `mode` como texto** e o `size` e `mtime` como números (`| int`).
7. **Combine com `assert`** para auditorias e pré-requisitos.
8. **Use `find` para padrões, idade e tamanho** em vários arquivos, e `stat` para um caminho conhecido.
9. **Proteja o acesso** a tasks puladas com `default()` ou `is not skipped`.
10. **Use `become: true`** quando o arquivo estiver em área restrita.
11. **Lembre-se de que o `stat` roda no host remoto;** use `delegate_to: localhost` para o controle.
12. **Use `until` e `wait_for`** para esperar arquivos, em vez de pausas fixas.

---

## Resumo

| Necessidade | Uso |
|---|---|
| Saber se um caminho existe | `stat.exists` |
| Saber se é arquivo, diretório ou link | `stat.isreg`, `stat.isdir`, `stat.islnk` |
| Ver permissões e dono | `stat.mode`, `stat.pw_name`, `stat.gr_name` |
| Ver o tamanho | `stat.size` |
| Ver a idade | `stat.mtime` + `date_time.epoch` |
| Comparar conteúdo | `stat.checksum` + `checksum_algorithm` |
| Seguir links simbólicos | `follow: true` |
| Destino de um link | `stat.lnk_source` |
| Acelerar a consulta | `get_checksum: false`, `get_mime: false` |
| Consultar vários caminhos | `loop` + `register` + `.results` |
| Esperar um arquivo | `until` ou `wait_for` |
| Buscar com curingas, idade ou tamanho | `ansible.builtin.find` |
| Ler o conteúdo de um arquivo | `ansible.builtin.slurp` |
| Consultar a máquina de controle | `delegate_to: localhost` |
| Hosts Windows | `ansible.windows.win_stat` |
