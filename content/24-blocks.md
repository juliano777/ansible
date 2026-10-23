# Capítulo: Blocks no Ansible

## 1. O que são blocks

Um **block** (bloco) agrupa várias tasks sob uma mesma estrutura. Isso serve a dois propósitos:

1. **Aplicar uma diretiva a várias tasks de uma vez**, sem repeti-la: `when`, `become`, `tags`, `vars`, `environment`, `ignore_errors` e outras.
2. **Tratar erros**, com as seções `rescue` (executada se algo falhar) e `always` (executada sempre), de forma parecida com o `try/catch/finally` de linguagens de programação.

Estrutura geral:

```yaml
tasks:
  - name: Nome do bloco
    block:
      - name: Task 1
        ansible.builtin.debug:
          msg: "Dentro do bloco"

      - name: Task 2
        ansible.builtin.debug:
          msg: "Também dentro do bloco"

    rescue:
      - name: Executada se alguma task do bloco falhar
        ansible.builtin.debug:
          msg: "Algo falhou"

    always:
      - name: Executada sempre
        ansible.builtin.debug:
          msg: "Fim do bloco"
```

Apenas `block:` é obrigatório; `rescue` e `always` são opcionais, e podem ser usados juntos ou separadamente.

> **Indentação:** as chaves `name`, `when`, `become`, `tags` etc. do bloco ficam no **mesmo nível** de `block:`, `rescue:` e `always:`. As tasks ficam como itens de lista **abaixo** de cada seção.

---

## 2. Aplicando diretivas a um grupo de tasks

### 2.1 Condição (`when`)

Em vez de repetir o `when` em cada task:

```yaml
- name: Tarefas do Debian
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

- name: Tarefas do Red Hat
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

Se a condição do bloco for falsa, **todas** as tasks dele são puladas. Se uma task interna também tiver `when`, as duas condições são combinadas com E.

### 2.2 Elevação de privilégio (`become`)

Foi uma dúvida do início da nossa conversa: dá para dar `sudo` só em parte do playbook, em vez de no play inteiro.

```yaml
---
- name: Elevação apenas onde é necessária
  hosts: all
  gather_facts: true
  become: false

  tasks:
    - name: Consulta que não precisa de root
      ansible.builtin.command: hostname -f
      register: nome
      changed_when: false

    - name: Operações que precisam de root
      become: true
      block:
        - name: Atualizar o cache
          ansible.builtin.apt:
            update_cache: true
          when: ansible_facts['os_family'] == "Debian"

        - name: Atualizar o cache
          ansible.builtin.dnf:
            update_cache: true
          when: ansible_facts['os_family'] == "RedHat"
```

Também é possível mudar o usuário alvo: `become_user: postgres`.

### 2.3 Tags

```yaml
- name: Atualizações
  tags: updates
  block:
    - name: Atualizar o cache
      ansible.builtin.apt:
        update_cache: true

    - name: Atualizar os pacotes
      ansible.builtin.apt:
        name: "*"
        state: latest
```

```bash
ansible-playbook -i hosts test.yml --tags updates
```

As tags do bloco são herdadas por todas as tasks internas (ver capítulo de tags). Tasks internas ainda podem ter tags adicionais, que se somam.

### 2.4 Variáveis (`vars`)

Variáveis definidas no bloco valem **somente dentro dele**:

```yaml
- name: Bloco com variáveis próprias
  vars:
    pasta_destino: /opt/app
    dono: appuser
  block:
    - name: Criar o diretório
      ansible.builtin.file:
        path: "{{ pasta_destino }}"
        state: directory
        owner: "{{ dono }}"

    - name: Copiar o arquivo
      ansible.builtin.copy:
        src: app.conf
        dest: "{{ pasta_destino }}/app.conf"
        owner: "{{ dono }}"
```

### 2.5 Variáveis de ambiente (`environment`)

Útil para proxies e configurações temporárias:

```yaml
- name: Instalar via proxy
  environment:
    http_proxy: http://proxy.exemplo.com:3128
    https_proxy: http://proxy.exemplo.com:3128
  block:
    - name: Atualizar o cache
      ansible.builtin.apt:
        update_cache: true
```

### 2.6 Ocultar saída sensível (`no_log`)

```yaml
- name: Operações com credenciais
  no_log: true
  block:
    - name: Registrar no sistema
      ansible.builtin.command: /usr/local/bin/registrar --token "{{ token }}"
      changed_when: true
```

### 2.7 Ignorar erros de um grupo (`ignore_errors`)

```yaml
- name: Tarefas opcionais
  ignore_errors: true
  block:
    - name: Parar serviço opcional A
      ansible.builtin.service:
        name: servico-a
        state: stopped

    - name: Parar serviço opcional B
      ansible.builtin.service:
        name: servico-b
        state: stopped
```

### 2.8 Outras diretivas aceitas

Também podem ser aplicadas a blocos: `check_mode`, `diff`, `delegate_to`, `remote_user`, `connection`, `module_defaults`, `collections`, `any_errors_fatal`, `throttle`, `timeout`, entre outras. A lista completa está na documentação oficial, em *Playbook Keywords → Block*.

Exemplo: executar um grupo de tasks na máquina de controle:

```yaml
- name: Registrar o resultado localmente
  delegate_to: localhost
  become: false
  block:
    - name: Gravar linha no relatório
      ansible.builtin.lineinfile:
        path: ./relatorio.txt
        line: "{{ inventory_hostname }}: concluído"
        create: true
```

### 2.9 O que **não** funciona em blocos

Algumas palavras-chave pertencem à task individual e **não** podem ser aplicadas a um bloco:

| Palavra-chave | Alternativa |
|---|---|
| `loop`, `with_*` | Mover as tasks para um arquivo e usar `include_tasks` com `loop` |
| `register` | Registrar em cada task, individualmente |
| `changed_when`, `failed_when` | Aplicar em cada task |
| `until`, `retries`, `delay` | Aplicar em cada task |
| `notify` | Aplicar em cada task |

Exemplo de loop sobre um grupo de tasks:

```yaml
- name: Executar o mesmo conjunto para cada item
  ansible.builtin.include_tasks: configurar_site.yml
  loop:
    - site1.exemplo.com
    - site2.exemplo.com
  loop_control:
    loop_var: site
```

---

## 3. Tratamento de erros: `block`, `rescue` e `always`

### 3.1 Como funciona

| Seção | Quando executa |
|---|---|
| `block` | Sempre, task por task, até uma delas falhar |
| `rescue` | **Somente** se alguma task do `block` falhar |
| `always` | **Sempre**, com ou sem falha no `block` ou no `rescue` |

Fluxo:

1. As tasks do `block` rodam em ordem.
2. Se uma **falhar**, as demais do bloco são puladas e o Ansible executa o `rescue`.
3. Se o `rescue` terminar sem erro, o host **não** é marcado como falho e o playbook continua normalmente.
4. O `always` roda no final, de qualquer forma.

### 3.2 Exemplo básico

```yaml
- name: Tentar uma operação com plano B
  block:
    - name: Tentar parar um serviço
      ansible.builtin.service:
        name: servico-inexistente
        state: stopped

    - name: Esta task é pulada se a anterior falhar
      ansible.builtin.debug:
        msg: "O serviço foi parado"

  rescue:
    - name: Plano B
      ansible.builtin.debug:
        msg: "Não foi possível parar o serviço, seguindo adiante"

  always:
    - name: Sempre executa
      ansible.builtin.debug:
        msg: "Verificação concluída em {{ inventory_hostname }}"
```

### 3.3 Informações sobre a falha

Dentro do `rescue`, duas variáveis especiais descrevem o que falhou:

| Variável | Conteúdo |
|---|---|
| `ansible_failed_task` | A task que falhou (`name`, `action` etc.) |
| `ansible_failed_result` | O resultado da task que falhou (`msg`, `rc`, `stderr` etc.) |

```yaml
  rescue:
    - name: Mostrar o que falhou
      ansible.builtin.debug:
        msg:
          - "Task: {{ ansible_failed_task.name }}"
          - "Motivo: {{ ansible_failed_result.msg | default('sem mensagem') }}"
```

### 3.4 Falhar de propósito depois do `rescue`

O `rescue` "absorve" o erro. Se você quer limpar a bagunça **e** ainda assim marcar o host como falho, termine com `fail`:

```yaml
  rescue:
    - name: Limpeza
      ansible.builtin.file:
        path: /tmp/arquivo-temporario
        state: absent

    - name: Marcar como falha mesmo assim
      ansible.builtin.fail:
        msg: "Operação falhou em {{ inventory_hostname }}: {{ ansible_failed_result.msg | default('erro desconhecido') }}"
```

### 3.5 Padrão: backup, alteração e restauração

Alterar uma configuração crítica e voltar ao estado anterior se algo der errado:

```yaml
---
- name: Alterar o SSH com rollback
  hosts: all
  gather_facts: true
  become: true

  vars:
    servico_ssh: "{{ 'ssh' if ansible_facts['os_family'] == 'Debian' else 'sshd' }}"

  tasks:
    - name: Alteração segura do sshd_config
      block:
        - name: Fazer backup
          ansible.builtin.copy:
            src: /etc/ssh/sshd_config
            dest: /etc/ssh/sshd_config.bak
            remote_src: true
            mode: preserve

        - name: Desativar login de root (validando a sintaxe)
          ansible.builtin.lineinfile:
            path: /etc/ssh/sshd_config
            regexp: '^#?PermitRootLogin'
            line: "PermitRootLogin no"
            validate: "/usr/sbin/sshd -t -f %s"

        - name: Recarregar o serviço
          ansible.builtin.service:
            name: "{{ servico_ssh }}"
            state: reloaded

      rescue:
        - name: Restaurar o backup
          ansible.builtin.copy:
            src: /etc/ssh/sshd_config.bak
            dest: /etc/ssh/sshd_config
            remote_src: true
            mode: preserve

        - name: Recarregar com a configuração original
          ansible.builtin.service:
            name: "{{ servico_ssh }}"
            state: reloaded

        - name: Sinalizar a falha
          ansible.builtin.fail:
            msg: "Alteração revertida em {{ inventory_hostname }}"

      always:
        - name: Informar o fim
          ansible.builtin.debug:
            msg: "Procedimento do SSH finalizado em {{ inventory_hostname }}"
```

O parâmetro `validate` do `lineinfile` testa o arquivo **antes** de gravá-lo; com isso, uma configuração inválida nem chega a ser aplicada.

### 3.6 Padrão: garantir limpeza com `always`

```yaml
- name: Operação com arquivo temporário
  block:
    - name: Baixar o instalador
      ansible.builtin.get_url:
        url: https://exemplo.com/instalador.sh
        dest: /tmp/instalador.sh
        mode: "0755"

    - name: Executar o instalador
      ansible.builtin.command: /tmp/instalador.sh
      changed_when: true

  always:
    - name: Remover o instalador (mesmo se algo falhou)
      ansible.builtin.file:
        path: /tmp/instalador.sh
        state: absent
```

### 3.7 O que **não** dispara o `rescue`

- **Host inalcançável** (`unreachable`): erro de conexão não é uma falha de task. Para tratá-lo, use `ignore_unreachable: true`.
- **Task com `ignore_errors: true` ou `failed_when: false`**: o erro foi explicitamente ignorado, então o bloco não considera como falha.
- **Task pulada** (`when` falso): não é falha.
- **Erro de sintaxe do playbook:** é detectado antes da execução.

### 3.8 O resumo final (`PLAY RECAP`)

Blocos com `rescue` bem-sucedido aparecem no resumo:

```
PLAY RECAP *****************************************
deb00 : ok=6  changed=1  unreachable=0  failed=0  skipped=0  rescued=1  ignored=0
```

`rescued=1` indica que houve uma falha tratada. O host **não** conta como `failed`.

---

## 4. Blocos aninhados e herança

Blocos podem conter outros blocos:

```yaml
- name: Bloco externo
  become: true
  when: ansible_facts['os_family'] == "Debian"
  tags: manutencao
  block:
    - name: Bloco interno A
      vars:
        pacote: vim
      block:
        - name: Instalar
          ansible.builtin.apt:
            name: "{{ pacote }}"
            state: present

    - name: Bloco interno B
      become_user: postgres
      block:
        - name: Consultar versão do banco
          ansible.builtin.command: psql --version
          changed_when: false
```

Regras de herança:

| Diretiva | Comportamento ao aninhar |
|---|---|
| `when` | Condições se **combinam** (E) |
| `tags` | Tags se **acumulam** |
| `vars` | Variáveis se **mesclam**; a interna vence em conflito |
| `become`, `environment`, `no_log`, etc. | A interna **sobrescreve** a externa |

Blocos aninhados também podem ter seu próprio `rescue` e `always`; um erro não tratado no interno sobe para o `rescue` do externo.

---

## 5. Blocos e tags

Tags no bloco afetam todas as tasks, inclusive as dos `rescue` e `always`:

```yaml
- name: Manutenção
  tags: manutencao
  block:
    - name: Passo 1
      ansible.builtin.debug:
        msg: "1"
      tags: passo1

    - name: Passo 2
      ansible.builtin.debug:
        msg: "2"
      tags: passo2
```

| Comando | Resultado |
|---|---|
| `--tags manutencao` | Roda os dois passos |
| `--tags passo1` | Roda apenas o Passo 1 |
| `--skip-tags passo2` | Roda tudo, menos o Passo 2 |

Para garantir que uma verificação sempre aconteça, marque-a com `tags: always`.

---

## 6. Escopo de variáveis em blocos

- Variáveis definidas em `vars:` no bloco valem **só dentro do bloco** (incluindo `rescue` e `always`).
- Variáveis de `register` e de `set_fact` **não** são limitadas ao bloco: continuam existindo depois dele, para aquele host.

```yaml
- name: Bloco
  block:
    - name: Obter hostname
      ansible.builtin.command: hostname -f
      register: nome
      changed_when: false

- name: Fora do bloco
  ansible.builtin.debug:
    msg: "{{ nome.stdout }}"      # funciona
```

---

## 7. Onde usar blocos

Blocos podem aparecer em qualquer lugar onde existam tasks:

- na lista `tasks:` de um play;
- em `pre_tasks:` e `post_tasks:`;
- dentro de arquivos de tasks usados por `include_tasks` e `import_tasks`;
- dentro de roles (`roles/<role>/tasks/main.yml`).

Exemplo em um arquivo de role:

```yaml
# roles/web/tasks/main.yml
---
- name: Instalar o servidor web
  block:
    - name: Instalar pacote
      ansible.builtin.package:
        name: "{{ pacote_web }}"
        state: present

    - name: Iniciar o serviço
      ansible.builtin.service:
        name: "{{ servico_web }}"
        state: started
        enabled: true
  rescue:
    - name: Reportar
      ansible.builtin.debug:
        msg: "Falha ao configurar o servidor web em {{ inventory_hostname }}"
```

---

## 8. Block × alternativas

| Necessidade | Use |
|---|---|
| Mesma condição ou tag para poucas tasks | `block` |
| Tratar erros e fazer rollback | `block` + `rescue` |
| Garantir limpeza | `block` + `always` |
| Ignorar a falha de **uma** task | `ignore_errors` ou `failed_when` na task |
| Escolher um arquivo de tasks inteiro por condição | `include_tasks` / `import_tasks` |
| Repetir um conjunto de tasks para vários itens | `include_tasks` com `loop` |
| Reaproveitar lógica entre playbooks | Roles |

---

## 9. Exemplo completo

Atualização de pacotes em Debian e Red Hat, usando `become` só onde é necessário, blocos por família de SO, tratamento de erro e tags:

```yaml
---
- name: Manutenção de pacotes com blocos
  hosts: all
  gather_facts: true
  become: false

  tasks:
    - name: Informar o host (não precisa de root)
      ansible.builtin.debug:
        msg: "=== Server name: {{ inventory_hostname }}"
      tags:
        - hostname
        - who

    - name: Atualização no Debian
      when: ansible_facts['os_family'] == "Debian"
      become: true
      tags: upgrade
      block:
        - name: Atualizar o cache
          ansible.builtin.apt:
            update_cache: true

        - name: Atualizar todos os pacotes
          ansible.builtin.apt:
            name: "*"
            state: latest

      rescue:
        - name: Tentar reparar pacotes quebrados
          ansible.builtin.command: dpkg --configure -a
          changed_when: true

        - name: Falhar mesmo assim
          ansible.builtin.fail:
            msg: "Atualização falhou em {{ inventory_hostname }}: {{ ansible_failed_result.msg | default('erro') }}"

      always:
        - name: Fim do bloco Debian
          ansible.builtin.debug:
            msg: "Bloco Debian concluído em {{ inventory_hostname }}"

    - name: Atualização no Red Hat
      when: ansible_facts['os_family'] == "RedHat"
      become: true
      tags: upgrade
      block:
        - name: Atualizar o cache
          ansible.builtin.dnf:
            update_cache: true

        - name: Atualizar todos os pacotes
          ansible.builtin.dnf:
            name: "*"
            state: latest

      rescue:
        - name: Limpar o cache e sinalizar
          ansible.builtin.command: dnf clean all
          changed_when: true

        - name: Falhar mesmo assim
          ansible.builtin.fail:
            msg: "Atualização falhou em {{ inventory_hostname }}: {{ ansible_failed_result.msg | default('erro') }}"

      always:
        - name: Fim do bloco Red Hat
          ansible.builtin.debug:
            msg: "Bloco Red Hat concluído em {{ inventory_hostname }}"
```

Execuções:

```bash
# Tudo
ansible-playbook -i hosts test.yml -K

# Só o hostname (sem pedir senha de sudo, pois não há become nessa task)
ansible-playbook -i hosts test.yml --tags hostname

# Só as atualizações em dois hosts
ansible-playbook -i hosts test.yml -K --tags upgrade --limit deb00,deb02

# Simulação
ansible-playbook -i hosts test.yml -K --tags upgrade --check
```

---

## 10. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `'loop' is not a valid attribute for a Block` | `loop` não é suportado em blocos | `include_tasks` com `loop` |
| `rescue` não executa | A falha foi `unreachable`, ou a task tem `ignore_errors` ou `failed_when: false` | Tratar `unreachable` à parte; remover o ignore |
| `rescue` não executa e o bloco foi todo pulado | A condição `when` do bloco é falsa | Verificar a condição |
| Erro de parsing do YAML | `rescue:` ou `always:` com indentação diferente de `block:` | Alinhar as três chaves |
| Host ainda marcado como falho após `rescue` | O próprio `rescue` falhou ou terminou com `fail` | Conferir as tasks do `rescue` |
| Playbook segue como se nada tivesse acontecido | `rescue` bem-sucedido absorve o erro | Terminar o `rescue` com `fail` |
| Variável do bloco indefinida fora dele | `vars:` do bloco só vale dentro | Usar `set_fact` ou `register` |
| `register` não funciona no nível do bloco | `register` pertence à task | Registrar em cada task |
| `become` com senha pedida sem necessidade | `become: true` no play inteiro | Mover `become` para os blocos que precisam |
| Tag do bloco não executa o `rescue` | O `rescue` só roda se o bloco falhou | Comportamento esperado |
| `ansible_failed_task` indefinido | Usado fora de um `rescue` | Só existe dentro do `rescue` |

---

## 11. Boas práticas

1. **Dê nome aos blocos** (`name:`) para que o código e a documentação fiquem claros.
2. **Use blocos para agrupar por propósito:** "tarefas do Debian", "alteração segura do SSH", "operações que precisam de root".
3. **Limite o `become`** aos blocos que realmente precisam de privilégio.
4. **Use `block` + `when`** em vez de repetir a mesma condição em várias tasks.
5. **Use `rescue` para desfazer** alterações (rollback), e termine com `fail` quando o erro precisar ser sinalizado.
6. **Use `always` para limpeza** de arquivos temporários, desbloqueio, notificações finais.
7. **Valide antes de aplicar** (como `validate` no `lineinfile` ou `copy`), e deixe o `rescue` como segunda linha de defesa.
8. **Não aninhe demais.** Dois ou três níveis são o limite razoável de leitura.
9. **Registre as informações da falha** com `ansible_failed_task` e `ansible_failed_result` para facilitar o diagnóstico.
10. **Prefira `failed_when` a `ignore_errors`** em tasks individuais, e `rescue` quando precisar de uma ação de recuperação.
11. **Para repetir um grupo de tasks por item,** use `include_tasks` com `loop`.
12. **Teste o caminho de erro:** force uma falha (por exemplo, apontando para um arquivo inexistente) para ver o `rescue` funcionando, e use `--check` para as demais tasks.

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Agrupar tasks | `block:` |
| Mesma condição para várias tasks | `when:` no bloco |
| `sudo` só em parte do playbook | `become: true` no bloco |
| Mesma tag para várias tasks | `tags:` no bloco |
| Variáveis válidas só para um grupo | `vars:` no bloco |
| Proxy ou variáveis de ambiente temporárias | `environment:` no bloco |
| Plano B em caso de falha | `rescue:` |
| Limpeza garantida | `always:` |
| Saber o que falhou | `ansible_failed_task`, `ansible_failed_result` |
| Sinalizar falha após limpar | `ansible.builtin.fail` no `rescue` |
| Executar o grupo em outro host | `delegate_to:` no bloco |
| Repetir um grupo para vários itens | `include_tasks` + `loop` |
| Ver falhas tratadas | `rescued=` no `PLAY RECAP` |
