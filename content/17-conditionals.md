# Capítulo: Condicionais no Ansible

## 1. O que são condicionais

Condicionais permitem que uma task (ou um grupo de tasks) seja executada **somente se uma condição for verdadeira**. É o que torna um playbook adaptável: instalar um pacote só se ele não existir, usar `apt` em Debian e `dnf` em Red Hat, reiniciar só se for necessário, e assim por diante.

A ferramenta principal é a palavra-chave **`when`**. Você já a usou nos exemplos de cache de pacotes:

```yaml
- name: Update apt cache (Debian)
  ansible.builtin.apt:
    update_cache: true
  when: ansible_facts['os_family'] == "Debian"
```

Além do `when`, existem outros recursos que também decidem o fluxo e que veremos neste capítulo: `failed_when`, `changed_when`, `until`, `assert`, `fail` e `meta`.

---

## 2. O `when` básico

### 2.1 Regras de sintaxe

1. **Sem chaves duplas.** O `when` já é avaliado como uma expressão Jinja2, então não se escreve `{{ }}`.

```yaml
# CORRETO
when: ambiente == "prod"

# ERRADO (desnecessário e desencorajado)
when: "{{ ambiente == 'prod' }}"
```

2. **Aspas quando houver dois-pontos ou caracteres especiais.** O YAML pode confundir o valor com um dicionário:

```yaml
# ERRADO: o YAML interpreta o ":" como separador
when: 'ERROR:' in res.stdout

# CORRETO
when: "'ERROR:' in res.stdout"
```

3. **O resultado precisa ser verdadeiro ou falso.** Versões recentes do `ansible-core` estão mais rígidas com condições que resultam em texto em vez de booleano. Prefira comparações explícitas ou converta com `| bool` (ver seção 6).

### 2.2 Exemplo mínimo

```yaml
---
- name: Exemplo de when
  hosts: all
  gather_facts: true

  tasks:
    - name: Só em Debian
      ansible.builtin.debug:
        msg: "Este host é Debian"
      when: ansible_facts['os_family'] == "Debian"

    - name: Só em Red Hat
      ansible.builtin.debug:
        msg: "Este host é Red Hat"
      when: ansible_facts['os_family'] == "RedHat"
```

---

## 3. Operadores

### 3.1 Comparação

| Operador | Significado | Exemplo |
|---|---|---|
| `==` | Igual | `ambiente == "prod"` |
| `!=` | Diferente | `ambiente != "dev"` |
| `>` | Maior | `porta > 1024` |
| `>=` | Maior ou igual | `ansible_facts['memtotal_mb'] >= 2048` |
| `<` | Menor | `uso < 80` |
| `<=` | Menor ou igual | `tentativas <= 3` |

### 3.2 Lógicos

| Operador | Significado | Exemplo |
|---|---|---|
| `and` | E | `a == 1 and b == 2` |
| `or` | Ou | `a == 1 or b == 2` |
| `not` | Negação | `not arq.stat.exists` |
| `( )` | Agrupamento | `(a or b) and c` |

### 3.3 Pertencimento

```yaml
when: ansible_facts['distribution'] in ['Debian', 'Ubuntu']
when: ambiente not in ['dev', 'homolog']
when: "'ssh' in pacotes_instalados"        # item em lista
when: "'ERROR' in res.stdout"              # trecho em texto
```

---

## 4. Várias condições

### 4.1 Lista: todas precisam ser verdadeiras (E)

```yaml
when:
  - ansible_facts['os_family'] == "RedHat"
  - ansible_facts['distribution_major_version'] | int >= 8
  - ambiente == "prod"
```

Cada item da lista é combinado com `and`. É a forma mais legível.

### 4.2 `and` e `or` na mesma linha

```yaml
when: ansible_facts['os_family'] == "Debian" or ansible_facts['os_family'] == "Ubuntu"

when: (ambiente == "prod" or ambiente == "homolog") and reiniciar | bool
```

### 4.3 Expressões longas em várias linhas

O estilo `>` do YAML junta as linhas em uma só:

```yaml
when: >
  ansible_facts['os_family'] == "Debian" and
  ansible_facts['distribution_major_version'] | int >= 12 and
  ambiente == "prod"
```

### 4.4 Misturando lista com `or`

Para "A **e** (B **ou** C)":

```yaml
when:
  - ambiente == "prod"
  - ansible_facts['os_family'] == "Debian" or ansible_facts['os_family'] == "RedHat"
```

---

## 5. Condições com facts

Os facts são a base das condições em ambientes mistos (ver capítulo de facts):

```yaml
# Por família
when: ansible_facts['os_family'] == "Debian"

# Por distribuição específica
when: ansible_facts['distribution'] == "Ubuntu"

# Por versão (use o teste "version", e não comparação de texto)
when: ansible_facts['distribution_version'] is version('12', '>=')

# Por recursos de hardware
when: ansible_facts['memtotal_mb'] < 2048
when: ansible_facts['processor_vcpus'] >= 4

# Por virtualização
when: ansible_facts['virtualization_type'] == "docker"
```

> `ansible_facts['x']` só existe se `gather_facts` estiver ativo. Com `gather_facts: false`, qualquer condição baseada em facts falha com "variable is undefined".

---

## 6. Condições com variáveis, tipos e booleanos

### 6.1 Variável booleana

```yaml
vars:
  reiniciar: true

tasks:
  - name: Reiniciar
    ansible.builtin.reboot:
    when: reiniciar
```

### 6.2 O problema do texto `"false"`

Variáveis vindas de `-e "reiniciar=false"` (formato `chave=valor`) ou de `vars_prompt` são **strings**. O texto `"false"` não é o booleano `false`. Use `| bool`:

```yaml
when: reiniciar | bool
```

`| bool` reconhece `true`, `yes`, `on`, `1` como verdadeiros e `false`, `no`, `off`, `0` como falsos.

Alternativas:

```yaml
when: reiniciar == "true"              # comparação explícita com o texto
when: reiniciar is truthy              # teste "truthy"
when: reiniciar is falsy               # teste "falsy"
```

Ou passe um booleano real com JSON: `-e '{"reiniciar": false}'`.

### 6.3 Números

Variáveis de linha de comando, prompts e saídas de comandos são texto. Converta antes de comparar:

```yaml
when: porta | int > 1024
when: uso_raiz.stdout | int >= 80
```

Comparar texto com número dá resultados errados (`"100" < "20"` é verdadeiro como texto).

### 6.4 Variável que pode não existir

```yaml
# Falha se "debug_ativo" não existir
when: debug_ativo

# Seguro: só avalia se existir
when: debug_ativo is defined and debug_ativo | bool

# Seguro: valor padrão
when: debug_ativo | default(false) | bool
```

O operador `and` interrompe a avaliação no primeiro valor falso, por isso `is defined and ...` protege o resto da expressão.

---

## 7. Testes úteis em condições

| Teste | Verdadeiro quando |
|---|---|
| `x is defined` | A variável existe |
| `x is undefined` | A variável não existe |
| `x is none` | O valor é nulo |
| `x is string` | É um texto |
| `x is number` | É um número |
| `x is mapping` | É um dicionário |
| `x is iterable` | É uma lista (ou algo iterável) |
| `x is truthy` / `x is falsy` | Equivale a verdadeiro ou falso (aceita `yes`, `no`, `1`, `0`) |
| `x is version('9', '>=')` | Comparação semântica de versões |
| `x is match('^a')` | O texto **começa** com o padrão (regex) |
| `x is search('erro')` | O padrão aparece **em qualquer ponto** do texto |
| `x is regex('^[0-9]+$')` | Equivale a `search`, com opções extras |
| `x is subset(y)` / `x is superset(y)` | Relação entre listas |
| `x is file` / `x is directory` | Caminho na **máquina de controle** |
| `x is succeeded` / `failed` / `changed` / `skipped` | Estado de uma variável registrada |

Exemplos:

```yaml
when: pacote is defined
when: ansible_facts['distribution_version'] is version('9', '>=')
when: res.stdout is search('active')
when: ['curl', 'git'] is subset(pacotes_instalados)
```

Para negar, use `is not`: `when: pacote is not defined`.

---

## 8. Condições com variáveis registradas

O `register` (ver capítulo anterior) é a principal fonte de condições dinâmicas.

### 8.1 Por existência de arquivo

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

### 8.2 Pela saída ou pelo código de retorno

```yaml
- name: Verificar o serviço
  ansible.builtin.command: systemctl is-active ssh
  register: ssh_status
  changed_when: false
  failed_when: false

- name: Iniciar se não estiver ativo
  ansible.builtin.service:
    name: ssh
    state: started
  when: ssh_status.stdout != "active"
```

Ou, usando o código de retorno:

```yaml
when: ssh_status.rc != 0
```

### 8.3 Pelo estado da task anterior

```yaml
- name: Ajustar configuração
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    line: "PermitRootLogin no"
  register: config_ssh

- name: Recarregar o SSH apenas se mudou
  ansible.builtin.service:
    name: "{{ 'ssh' if ansible_facts['os_family'] == 'Debian' else 'sshd' }}"
    state: reloaded
  when: config_ssh is changed
```

> Para este último caso o recurso idiomático são os **handlers** (`notify`), mas o `register` com `when` funciona e é mais explícito.

### 8.4 Cuidado com tasks puladas

Se a task do `register` foi pulada, a variável existe, mas **sem** `stdout`, `rc` etc. Proteja:

```yaml
when: res is not skipped and res.rc == 0
when: res.rc | default(1) == 0
```

---

## 9. Condições com grupos e hosts do inventário

Variáveis mágicas permitem decidir com base na posição do host no inventário:

```yaml
# O host pertence a um grupo
when: "'debian' in group_names"

# O host é um membro específico de um grupo
when: inventory_hostname in groups['web']

# Só no primeiro host do grupo
when: inventory_hostname == groups['web'][0]

# Só em um host específico
when: inventory_hostname == "deb00"

# Em todos, exceto em um
when: inventory_hostname != "deb02"

# Padrão no nome do host
when: inventory_hostname is match("deb")
```

Variáveis úteis do próprio Ansible em condições:

| Variável | Uso |
|---|---|
| `ansible_check_mode` | Verdadeira quando roda com `--check` |
| `ansible_play_hosts` | Hosts ativos no play |
| `ansible_version.full` | Versão do Ansible |
| `ansible_become` | Se há elevação de privilégio |

```yaml
- name: Só executa de verdade (nunca em --check)
  ansible.builtin.command: /usr/local/bin/sincronizar.sh
  when: not ansible_check_mode
```

---

## 10. `when` em loops

Com `loop`, o `when` é avaliado **para cada item**, e a variável `item` pode ser usada na condição:

```yaml
- name: Mostrar só os números maiores que 3
  ansible.builtin.debug:
    msg: "{{ item }}"
  loop: [1, 2, 3, 4, 5]
  when: item > 3
```

Itens que não atendem são pulados individualmente.

Com listas de dicionários:

```yaml
vars:
  usuarios:
    - { nome: ana,   ativo: true }
    - { nome: bruno, ativo: false }
    - { nome: carla, ativo: true }

tasks:
  - name: Criar apenas usuários ativos
    ansible.builtin.user:
      name: "{{ item.nome }}"
      state: present
    loop: "{{ usuarios }}"
    when: item.ativo
    loop_control:
      label: "{{ item.nome }}"
```

Com resultados registrados de outro loop (ver capítulo de `register`):

```yaml
- name: Remover os arquivos que existem
  ansible.builtin.file:
    path: "{{ item.item }}"
    state: absent
  loop: "{{ arquivos.results }}"
  when: item.stat.exists
```

> Quando possível, filtre a lista **antes** do loop (`selectattr`, `select`), o que deixa a saída mais limpa por não listar itens pulados:
>
> ```yaml
> loop: "{{ usuarios | selectattr('ativo') | list }}"
> ```

---

## 11. `when` em blocos

Aplicar a mesma condição a várias tasks sem repeti-la:

```yaml
- name: Tarefas exclusivas do Debian
  when: ansible_facts['os_family'] == "Debian"
  block:
    - name: Atualizar o cache
      ansible.builtin.apt:
        update_cache: true

    - name: Instalar utilitários
      ansible.builtin.apt:
        name:
          - vim
          - curl
        state: present

- name: Tarefas exclusivas do Red Hat
  when: ansible_facts['os_family'] == "RedHat"
  block:
    - name: Atualizar o cache
      ansible.builtin.dnf:
        update_cache: true

    - name: Instalar utilitários
      ansible.builtin.dnf:
        name:
          - vim-enhanced
          - curl
        state: present
```

A condição do bloco é aplicada a **cada task** dentro dele. Se uma task do bloco também tiver o seu próprio `when`, as duas condições são combinadas com E.

Os blocos também permitem tratamento de erros:

```yaml
- name: Atualização com tratamento de erro
  when: ansible_facts['os_family'] == "Debian"
  block:
    - name: Atualizar pacotes
      ansible.builtin.apt:
        upgrade: dist
  rescue:
    - name: Executado se alguma task do bloco falhar
      ansible.builtin.debug:
        msg: "Falha na atualização em {{ inventory_hostname }}"
  always:
    - name: Executado sempre
      ansible.builtin.debug:
        msg: "Fim do bloco em {{ inventory_hostname }}"
```

---

## 12. `when` com imports, includes, roles e handlers

O comportamento depende do tipo de reaproveitamento (a mesma distinção estática × dinâmica vista no capítulo de tags):

| Diretiva | Tipo | Efeito do `when` |
|---|---|---|
| `import_tasks`, `import_role` | Estática | A condição é **copiada para cada task** importada e avaliada task por task |
| `include_tasks`, `include_role` | Dinâmica | A condição é avaliada **uma vez**; se falsa, o arquivo nem é carregado |
| `roles:` (no play) | Estática | Igual ao `import_role` |
| `handlers` | n/a | Cada handler aceita seu próprio `when` |

Exemplos:

```yaml
tasks:
  # Dinâmico: o arquivo só é lido se a condição for verdadeira
  - ansible.builtin.include_tasks: debian.yml
    when: ansible_facts['os_family'] == "Debian"

  # Estático: cada task do arquivo recebe a condição
  - ansible.builtin.import_tasks: redhat.yml
    when: ansible_facts['os_family'] == "RedHat"

roles:
  - role: apache
    when: instalar_web | default(false) | bool
```

Um padrão ainda mais enxuto para ambientes mistos é escolher o arquivo **pelo nome**, sem nenhum `when`:

```yaml
- ansible.builtin.include_tasks: "{{ ansible_facts['os_family'] | lower }}.yml"
```

Isso carrega `debian.yml` ou `redhat.yml` conforme o host.

---

## 13. Outros mecanismos condicionais

### 13.1 `failed_when` e `changed_when`

Definem o que é falha e o que é alteração (ver capítulo de `register`):

```yaml
- name: grep retorna 1 se não achar, o que não é erro aqui
  ansible.builtin.command: grep -c "erro" /var/log/app.log
  register: contagem
  changed_when: false
  failed_when: contagem.rc > 1
```

### 13.2 `until`: repetir até a condição ser verdadeira

```yaml
- name: Aguardar o serviço responder
  ansible.builtin.uri:
    url: http://localhost:8080/health
  register: saude
  until: saude.status == 200
  retries: 10
  delay: 5
```

### 13.3 `assert`: validar premissas

Falha com mensagem clara se a condição não for atendida:

```yaml
- name: Validar pré-requisitos
  ansible.builtin.assert:
    that:
      - ansible_facts['memtotal_mb'] >= 2048
      - ambiente in ['dev', 'homolog', 'prod']
    fail_msg: "Pré-requisitos não atendidos em {{ inventory_hostname }}"
    success_msg: "Pré-requisitos OK"
```

### 13.4 `fail`: interromper com mensagem

```yaml
- name: Abortar em sistema não suportado
  ansible.builtin.fail:
    msg: "Sistema não suportado: {{ ansible_facts['os_family'] }}"
  when: ansible_facts['os_family'] not in ['Debian', 'RedHat']
```

### 13.5 `meta`: encerrar a execução em um host ou no play

```yaml
- name: Sair deste host se não for o ambiente desejado
  ansible.builtin.meta: end_host
  when: ambiente != "prod"

- name: Encerrar o play para todos
  ansible.builtin.meta: end_play
  when: not continuar | default(true) | bool
```

### 13.6 Condição dentro de valores: `if` em linha e `ternary`

Não é um `when`, mas resolve decisões **dentro** de um parâmetro:

```yaml
name: "{{ 'apache2' if ansible_facts['os_family'] == 'Debian' else 'httpd' }}"
name: "{{ (ansible_facts['os_family'] == 'Debian') | ternary('apache2', 'httpd') }}"
```

### 13.7 Parâmetro opcional: `default(omit)`

```yaml
- name: Criar arquivo, com modo opcional
  ansible.builtin.file:
    path: /tmp/teste
    state: touch
    mode: "{{ modo | default(omit) }}"
```

---

## 14. O que acontece quando a condição é falsa

A task é **pulada** e aparece como `skipping` na saída:

```
TASK [Só em Red Hat] ***********************************
skipping: [deb00]
ok: [rh01]
```

- No resumo final, é contada em `skipped=`.
- Se tinha `register`, a variável existe com `skipped: true` e `skip_reason`.
- Tasks puladas **não** falham o playbook.

Para ver o motivo da condição, rode com `-v`.

---

## 15. Exemplo completo

Playbook que atualiza os pacotes em Debian e Red Hat e **só reinicia se for necessário e se for autorizado**:

```yaml
---
- name: Atualização com reinício condicional
  hosts: all
  gather_facts: true
  become: true

  vars:
    reiniciar_se_necessario: false

  tasks:
    - name: Validar sistema suportado
      ansible.builtin.assert:
        that:
          - ansible_facts['os_family'] in ['Debian', 'RedHat']
        fail_msg: "Sistema não suportado: {{ ansible_facts['os_family'] }}"
      tags: always

    - name: Atualizar o cache (Debian)
      ansible.builtin.apt:
        update_cache: true
      when: ansible_facts['os_family'] == "Debian"
      tags: upgrade

    - name: Atualizar o cache (Red Hat)
      ansible.builtin.dnf:
        update_cache: true
      when: ansible_facts['os_family'] == "RedHat"
      tags: upgrade

    - name: Atualizar todos os pacotes
      ansible.builtin.package:
        name: "*"
        state: latest
      tags: upgrade

    - name: Verificar se há reinício pendente (Debian)
      ansible.builtin.stat:
        path: /var/run/reboot-required
      register: reboot_debian
      when: ansible_facts['os_family'] == "Debian"
      tags: reboot

    - name: Verificar se há reinício pendente (Red Hat)
      ansible.builtin.command: needs-restarting -r
      register: reboot_redhat
      changed_when: false
      failed_when: reboot_redhat.rc not in [0, 1]
      check_mode: false
      when: ansible_facts['os_family'] == "RedHat"
      tags: reboot

    - name: Reiniciar se necessário e autorizado
      ansible.builtin.reboot:
      when:
        - reiniciar_se_necessario | bool
        - (reboot_debian.stat.exists | default(false)) or (reboot_redhat.rc | default(0) == 1)
      tags: reboot

    - name: Avisar se há reinício pendente e ele não foi autorizado
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} precisa de reinício (não autorizado)"
      when:
        - not (reiniciar_se_necessario | bool)
        - (reboot_debian.stat.exists | default(false)) or (reboot_redhat.rc | default(0) == 1)
      tags: reboot
```

No Red Hat, `needs-restarting` faz parte do pacote `dnf-utils` (ou `yum-utils`); instale-o antes se necessário. O código de retorno 1 significa "reinício necessário".

Execuções:

```bash
# Atualiza, avisa se precisa reiniciar
ansible-playbook -i hosts test.yml

# Atualiza e reinicia automaticamente, se necessário
ansible-playbook -i hosts test.yml -e "reiniciar_se_necessario=true"

# Apenas verificar a necessidade de reinício
ansible-playbook -i hosts test.yml --tags reboot --limit deb00,deb02
```

---

## 16. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `'ansible_facts' ... is undefined` | `gather_facts: false` | Ativar a coleta ou chamar `setup` |
| `when: flag` sempre verdadeiro | `flag` é o **texto** `"false"` | `flag \| bool` ou passar JSON |
| Erro de "conditional must be boolean" (versões recentes) | A expressão resulta em texto, não em booleano | Comparar explicitamente (`== "x"`) ou usar `\| bool` |
| Erro de YAML na linha do `when` | Dois-pontos ou chaves sem aspas | Colocar a expressão entre aspas |
| Aviso sobre `{{ }}` em `when` | Templating desnecessário | Remover as chaves duplas |
| `'dict object' has no attribute 'stdout'` | Task do `register` foi pulada | `is not skipped` ou `default()` |
| Comparação numérica errada | Valores são texto | `\| int` ou `\| float` |
| Comparação de versão errada | Comparou texto (`'10' < '9'`) | `is version('9', '<')` |
| Condição não avalia como esperado | Precedência de operadores | Usar parênteses |
| `when` em `include_tasks` "não afeta" as tasks internas | Include é dinâmico: a condição vale só para o include | Usar `import_tasks`, `apply` ou `block` |
| Teste `is file` não acha o arquivo | Avalia na máquina de controle | Usar `stat` + `register` no host remoto |
| Todos os hosts pulados | Condição depende de grupo ou host fora do `--limit` | Conferir `--limit` e o inventário |

---

## 17. Boas práticas

1. **Use listas no `when`** para condições com "E". São mais legíveis que `and` na mesma linha.
2. **Não use `{{ }}` no `when`.**
3. **Converta os tipos** (`| bool`, `| int`) em valores que vêm de `-e`, prompts e comandos.
4. **Proteja variáveis opcionais** com `is defined` ou `default()`.
5. **Use `os_family` para decisões amplas** (Debian × Red Hat) e `is version(...)` para versões.
6. **Agrupe com `block`** em vez de repetir o mesmo `when` em várias tasks.
7. **Prefira escolher arquivos pelo nome** (`"{{ ansible_facts['os_family'] | lower }}.yml"`) a empilhar muitos `when`.
8. **Filtre listas antes do `loop`** para evitar dezenas de linhas `skipping`.
9. **Valide premissas cedo** com `assert` e `fail`, com mensagens claras.
10. **Prefira `failed_when` e `changed_when`** a `ignore_errors`.
11. **Comandos de leitura que alimentam condições** devem ter `changed_when: false` e `check_mode: false`, para funcionar também em `--check`.
12. **Use parênteses** sempre que misturar `and` e `or`.
13. **Evite condições complexas demais:** se o `when` ocupa várias linhas difíceis de ler, calcule partes com `set_fact` e dê nomes claros (`precisa_reiniciar`, `eh_producao`).
14. **Teste os dois caminhos:** execute com a condição verdadeira e falsa (use `-e` para forçar) e com `--check`.

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Executar só se a condição for verdadeira | `when: expressão` |
| Várias condições (todas) | `when:` com lista |
| Alternativas (qualquer uma) | `or` |
| Negar | `not` ou `is not` |
| Pertencimento | `in`, `not in` |
| Variável existe | `is defined` |
| Texto para booleano | `\| bool` |
| Texto para número | `\| int`, `\| float` |
| Comparar versões | `is version('x', '>=')` |
| Estado de uma task anterior | `is changed`, `is failed`, `is skipped`, `is succeeded` |
| Por SO ou hardware | Facts: `ansible_facts[...]` |
| Por grupo ou host | `group_names`, `groups`, `inventory_hostname` |
| Por item de loop | `when` + `item` |
| Mesma condição para várias tasks | `block` + `when` |
| Condição em include dinâmico | Vale só para o include |
| Condição em import estático | Copiada para cada task |
| Definir falha ou alteração | `failed_when`, `changed_when` |
| Repetir até uma condição | `until`, `retries`, `delay` |
| Validar premissas | `assert`, `fail` |
| Encerrar host ou play | `meta: end_host`, `meta: end_play` |
| Valor condicional dentro de um parâmetro | `if ... else`, `ternary`, `default(omit)` |
| Não executar em `--check` | `when: not ansible_check_mode` |
