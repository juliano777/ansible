# Capítulo: Prompts em Playbooks

## 1. O que são prompts

Prompts são perguntas feitas ao usuário **durante a execução** de um playbook. Em vez de editar o arquivo ou lembrar de passar `-e`, o Ansible pausa, pergunta, e usa a resposta como valor de uma variável.

Existem quatro mecanismos principais:

| Mecanismo | Para que serve |
|---|---|
| `vars_prompt` | Perguntar valores de variáveis no início do play |
| `ansible.builtin.pause` | Pausar no meio do playbook, esperando confirmação ou uma resposta |
| `--ask-become-pass` / `-K` | Pedir a senha do sudo |
| `--ask-pass` / `-k` e `--ask-vault-pass` | Pedir a senha SSH e a senha do Vault |

---

## 2. `vars_prompt`

### 2.1 Exemplo básico

```yaml
---
- name: Exemplo de vars_prompt
  hosts: all
  gather_facts: false

  vars_prompt:
    - name: usuario
      prompt: "Qual o nome do usuário?"
      private: false

  tasks:
    - name: Mostrar o valor informado
      ansible.builtin.debug:
        msg: "Você informou: {{ usuario }}"
```

Ao executar:

```bash
ansible-playbook -i hosts test.yml
```

```
Qual o nome do usuário?:
```

A resposta fica disponível como a variável `usuario` em todo o play.

### 2.2 Opções disponíveis

| Opção | Descrição |
|---|---|
| `name` | Nome da variável que receberá a resposta (**obrigatório**) |
| `prompt` | Texto exibido ao usuário |
| `default` | Valor usado se o usuário apenas pressionar Enter |
| `private` | Se `true` (padrão), a digitação **não** é exibida na tela |
| `confirm` | Se `true`, pede que o valor seja digitado duas vezes |
| `encrypt` | Gera um hash da resposta (ex.: `sha512_crypt`) |
| `salt_size` | Tamanho do salt usado no hash |
| `salt` | Salt fixo para o hash |
| `unsafe` | Se `true`, permite que `{{ }}` na resposta seja interpretado como template (use com cautela) |

> Observação importante: `private` vale `true` por padrão. Para perguntas comuns (nome, ambiente), use `private: false` para que a pessoa veja o que digita.

### 2.3 Valor padrão

```yaml
  vars_prompt:
    - name: ambiente
      prompt: "Qual o ambiente (dev/homolog/prod)?"
      default: dev
      private: false
```

Se o usuário pressionar Enter, `ambiente` valerá `dev`. O padrão aparece entre colchetes na pergunta.

### 2.4 Senha com confirmação

```yaml
  vars_prompt:
    - name: db_senha
      prompt: "Senha do banco"
      private: true
      confirm: true
```

O Ansible pede duas vezes e só continua se os valores forem iguais.

### 2.5 Gerando hash da senha

Útil para criar usuários, pois o módulo `user` espera a senha já em formato hash:

```yaml
---
- name: Criar usuário com senha informada na hora
  hosts: all
  become: true

  vars_prompt:
    - name: novo_usuario
      prompt: "Nome do novo usuário"
      private: false

    - name: nova_senha
      prompt: "Senha do novo usuário"
      private: true
      confirm: true
      encrypt: sha512_crypt
      salt_size: 7

  tasks:
    - name: Criar o usuário
      ansible.builtin.user:
        name: "{{ novo_usuario }}"
        password: "{{ nova_senha }}"
        state: present
```

A senha em texto puro nunca é usada no playbook: a variável `nova_senha` já contém o hash. O recurso `encrypt` depende da biblioteca Python `passlib` na máquina de controle.

### 2.6 Várias perguntas

```yaml
  vars_prompt:
    - name: ambiente
      prompt: "Ambiente"
      default: dev
      private: false

    - name: versao
      prompt: "Versão a instalar"
      private: false

    - name: reiniciar
      prompt: "Reiniciar o servidor ao final (sim/nao)?"
      default: nao
      private: false
```

### 2.7 Valores padrão em casos específicos

Há quatro situações, dependendo de **de onde** vem o padrão.

**1. Padrão fixo**

```yaml
vars_prompt:
  - name: ambiente
    prompt: "Ambiente"
    default: dev
    private: false
```

**2. Padrão vindo de outra variável**

O `default` aceita template, então pode usar uma variável do play ou do ambiente:

```yaml
vars:
  ambiente_padrao: homolog

vars_prompt:
  - name: ambiente
    prompt: "Ambiente"
    default: "{{ ambiente_padrao }}"
    private: false

  - name: responsavel
    prompt: "Responsável"
    default: "{{ lookup('env', 'USER') }}"
    private: false
```

Limitação: o `vars_prompt` roda **antes** da coleta de facts e vale para o play inteiro. Por isso o `default` não enxerga facts (como `ansible_os_family`) nem valores por host.

**3. Padrão condicional (por sistema, host ou grupo)**

Deixe o prompt sem `default` e aplique o padrão depois, já com os facts disponíveis. O segundo argumento `true` do filtro `default` faz com que uma resposta **vazia** (só Enter) também use o padrão:

```yaml
---
- name: Padrão conforme o sistema
  hosts: all
  gather_facts: true
  become: true

  vars:
    pacote_padrao:
      Debian: apache2
      RedHat: httpd

  vars_prompt:
    - name: pacote_informado
      prompt: "Pacote web (Enter para o padrão do sistema)"
      private: false

  tasks:
    - name: Definir o pacote final
      ansible.builtin.set_fact:
        pacote_web: "{{ pacote_informado | default(pacote_padrao[ansible_facts['os_family']], true) }}"

    - name: Instalar
      ansible.builtin.package:
        name: "{{ pacote_web }}"
        state: present
```

Se o usuário pressionar Enter, Debian instala `apache2` e Red Hat instala `httpd`. Se digitar `nginx`, vale `nginx` para todos.

**4. Perguntar apenas em certos casos**

O `vars_prompt` não aceita `when`. Para perguntar só em determinadas situações, use `pause` com `when`:

```yaml
  tasks:
    - name: Perguntar a versão apenas em produção
      ansible.builtin.pause:
        prompt: "Versão a instalar (Enter para {{ versao_padrao }})"
      register: resp
      run_once: true
      when: ambiente == 'prod'

    - name: Definir a versão final
      ansible.builtin.set_fact:
        versao_final: "{{ resp.user_input | default(versao_padrao, true) }}"
```

Fora de produção a task é pulada, `resp.user_input` não existe e o `default` assume o valor padrão sem perguntar nada.

| Situação | Solução |
|---|---|
| Padrão fixo | `default: valor` |
| Padrão de uma variável do play ou do ambiente | `default: "{{ variavel }}"` |
| Padrão que depende de fact, host ou grupo | Prompt sem `default`, depois `\| default(x, true)` ou `set_fact` |
| Perguntar só em certos casos | `pause` com `when` |
| Pular a pergunta em automação | `-e "variavel=valor"` |

---

## 3. Comportamento do `vars_prompt`

Pontos importantes que costumam causar surpresa:

1. **A pergunta é feita uma única vez, no início do play**, antes de qualquer task, e a resposta vale para **todos os hosts**. Não é possível perguntar um valor diferente para cada host.
2. **A resposta é sempre uma string.** Para números e booleanos, converta com `| int` e `| bool`.
3. **Se a variável já foi definida por `-e`, o Ansible não pergunta.** Isso permite usar o mesmo playbook de forma interativa e automatizada (ver seção 6).
4. **Playbooks com mais de um play:** cada play pode ter seus próprios `vars_prompt`, perguntados no início de cada um.
5. **O prompt precisa de um terminal.** Em execuções sem terminal interativo (agendadores, pipelines, ferramentas como AWX), passe os valores por `-e` ou arquivo.

### Convertendo a resposta

```yaml
  vars_prompt:
    - name: porta
      prompt: "Porta"
      default: "8080"
      private: false

  tasks:
    - ansible.builtin.debug:
        msg: "Dobro da porta: {{ porta | int * 2 }}"

    - name: Reiniciar se confirmado
      ansible.builtin.reboot:
      when: reiniciar | lower in ['s', 'sim', 'y', 'yes']
```

### Valores padrão com aspas

Escreva o `default` entre aspas quando for um número, para que o YAML não o converta e o Ansible o trate sempre como texto: `default: "8080"`.

---

## 4. Validando as respostas

Como o usuário pode digitar qualquer coisa, valide logo na primeira task:

```yaml
  tasks:
    - name: Validar ambiente
      ansible.builtin.assert:
        that:
          - ambiente in ['dev', 'homolog', 'prod']
        fail_msg: "Ambiente inválido: {{ ambiente }}. Use dev, homolog ou prod."
        success_msg: "Ambiente válido."
      tags: always

    - name: Validar versão
      ansible.builtin.assert:
        that:
          - versao | length > 0
          - versao is match('^[0-9]+\.[0-9]+\.[0-9]+$')
        fail_msg: "Versão deve estar no formato X.Y.Z"
```

---

## 5. O módulo `pause`

O `vars_prompt` pergunta **antes** das tasks. Já o `ansible.builtin.pause` interrompe a execução **no meio** do playbook.

### 5.1 Pausa com prompt (esperar Enter)

```yaml
    - name: Conferir o plano antes de continuar
      ansible.builtin.pause:
        prompt: "Pressione Enter para continuar, ou Ctrl+C e depois A para abortar"
```

### 5.2 Pausa por tempo

```yaml
    - name: Aguardar o serviço estabilizar
      ansible.builtin.pause:
        seconds: 30
```

Ou em minutos:

```yaml
    - ansible.builtin.pause:
        minutes: 2
```

### 5.3 Capturando uma resposta

O resultado fica em `user_input` quando se usa `register`:

```yaml
    - name: Perguntar o nome do responsável
      ansible.builtin.pause:
        prompt: "Quem está executando esta mudança?"
      register: resposta

    - name: Registrar
      ansible.builtin.debug:
        msg: "Responsável: {{ resposta.user_input }}"
```

### 5.4 Ocultando a digitação

```yaml
    - name: Pedir token
      ansible.builtin.pause:
        prompt: "Informe o token"
        echo: false
      register: token
```

### 5.5 Confirmação antes de uma operação perigosa

Um padrão muito útil: exigir que o usuário digite uma palavra para continuar.

```yaml
---
- name: Atualizar todos os pacotes com confirmação
  hosts: all
  gather_facts: true
  become: true

  tasks:
    - name: Pedir confirmação
      ansible.builtin.pause:
        prompt: "Isto atualizará TODOS os pacotes de {{ ansible_play_hosts | length }} host(s). Digite 'sim' para continuar"
      register: confirmacao
      run_once: true

    - name: Abortar se não confirmado
      ansible.builtin.assert:
        that:
          - confirmacao.user_input | lower == 'sim'
        fail_msg: "Operação cancelada pelo usuário."
      run_once: true

    - name: Atualizar todos os pacotes
      ansible.builtin.package:
        name: "*"
        state: latest
        update_cache: true
```

### 5.6 Cuidados com `pause`

- Em um play com vários hosts, o `pause` com prompt acontece **uma vez**, não uma vez por host.
- Nas estratégias `free` não é possível usar o prompt de forma confiável; mantenha a estratégia padrão (`linear`) quando houver `pause`.
- Em execuções sem terminal (CI/CD, agendamentos), o prompt não funciona. Para esses casos, use uma variável e a condição `when`:

```yaml
    - name: Pausa apenas em modo interativo
      ansible.builtin.pause:
        prompt: "Confirma?"
      when: confirmar_manual | default(true) | bool
```

```bash
# Em pipeline: pula a pausa
ansible-playbook -i hosts test.yml -e "confirmar_manual=false"
```

---

## 6. Prompt interativo e automatizado no mesmo playbook

Como `-e` tem precedência sobre `vars_prompt` (e evita a pergunta), o mesmo arquivo atende a dois públicos.

```yaml
---
- name: Deploy
  hosts: all
  become: true

  vars_prompt:
    - name: ambiente
      prompt: "Ambiente (dev/homolog/prod)"
      default: dev
      private: false

    - name: versao
      prompt: "Versão"
      private: false

  tasks:
    - name: Mostrar parâmetros
      ansible.builtin.debug:
        msg: "Deploy da versão {{ versao }} em {{ ambiente }}"
```

**Uso interativo:**

```bash
ansible-playbook -i hosts deploy.yml
```

O Ansible pergunta `ambiente` e `versao`.

**Uso automatizado:**

```bash
ansible-playbook -i hosts deploy.yml -e "ambiente=prod versao=1.4.2"
```

Nenhuma pergunta é feita.

**Misto:**

```bash
ansible-playbook -i hosts deploy.yml -e "ambiente=prod"
```

Só `versao` será perguntada.

---

## 7. Prompts nativos da linha de comando

Além das perguntas dentro do playbook, o próprio `ansible-playbook` oferece opções que solicitam credenciais:

| Opção | Pede |
|---|---|
| `-K`, `--ask-become-pass` | Senha do `sudo` (elevação de privilégio) |
| `-k`, `--ask-pass` | Senha da conexão SSH |
| `--ask-vault-pass` | Senha do Ansible Vault |

Exemplos:

```bash
# Senha do sudo (como no seu playbook com become: true)
ansible-playbook -i hosts test.yml -K

# Senha SSH e do sudo
ansible-playbook -i hosts test.yml -k -K

# Arquivos criptografados com Vault
ansible-playbook -i hosts test.yml --ask-vault-pass
```

Para automação, prefira chaves SSH, `sudo` sem senha para o usuário de automação (`NOPASSWD`) e `--vault-password-file`, evitando prompts.

---

## 8. Exemplo completo

Playbook que combina `vars_prompt`, validação, confirmação com `pause` e tags:

```yaml
---
- name: Instalar pacote com perguntas e confirmação
  hosts: all
  gather_facts: true
  become: true

  vars_prompt:
    - name: pacote
      prompt: "Nome do pacote a instalar"
      private: false

    - name: acao
      prompt: "Ação (present/absent/latest)"
      default: present
      private: false

  tasks:
    - name: Validar as respostas
      ansible.builtin.assert:
        that:
          - pacote | length > 0
          - acao in ['present', 'absent', 'latest']
        fail_msg: "Pacote vazio ou ação inválida ({{ acao }})."
      tags: always

    - name: Confirmar a operação
      ansible.builtin.pause:
        prompt: "Vai executar '{{ acao }}' do pacote '{{ pacote }}' em {{ ansible_play_hosts | length }} host(s). Digite 'sim'"
      register: confirmacao
      run_once: true
      when: confirmar | default(true) | bool
      tags: confirmar

    - name: Cancelar se não confirmado
      ansible.builtin.assert:
        that: confirmacao.user_input | lower == 'sim'
        fail_msg: "Cancelado pelo usuário."
      run_once: true
      when: confirmar | default(true) | bool
      tags: confirmar

    - name: Executar a ação
      ansible.builtin.package:
        name: "{{ pacote }}"
        state: "{{ acao }}"
        update_cache: true
      tags: instalar
```

Execuções possíveis:

```bash
# Interativo completo
ansible-playbook -i hosts test.yml -K

# Parcialmente automatizado
ansible-playbook -i hosts test.yml -K -e "pacote=htop"

# Totalmente automatizado (sem perguntas e sem confirmação)
ansible-playbook -i hosts test.yml -K -e "pacote=htop acao=present confirmar=false"
```

---

## 9. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Não vejo o que digito | `private` é `true` por padrão | Usar `private: false` |
| Playbook trava em pipeline ou cron | Sem terminal para responder | Passar valores por `-e` e desativar `pause` |
| Pergunta não aparece | Variável já definida por `-e` | Comportamento esperado; remover o `-e` |
| Cálculo ou comparação numérica falha | Resposta é string | Usar `\| int` ou `\| bool` |
| `confirmacao.user_input` indefinido | A task do `pause` foi pulada por `when` | Usar `default` ou aplicar o mesmo `when` na validação |
| Hash de senha falha | Falta `passlib` na máquina de controle | `pip install passlib` |
| Quero um valor diferente por host | `vars_prompt` é único para o play | Usar `host_vars`, ou perguntar e usar `set_fact` por host |
| `pause` pergunta uma vez só | Comportamento por design | Usar `run_once` explicitamente e tratar o resultado para todos |

---

## 10. Boas práticas

1. **Use `vars_prompt` para o que precisa de decisão humana**; para tudo que for fixo, use `vars`, `group_vars` ou `vars_files`.
2. **Sempre ofereça um caminho automatizado:** deixe que `-e` substitua as perguntas.
3. **Defina `default` seguro** (ex.: `dev`, e nunca `prod`).
4. **Use `private: true` e `confirm: true`** para senhas e tokens.
5. **Use `encrypt`** quando a resposta for uma senha de usuário do sistema.
6. **Valide as respostas** com `assert` logo no início.
7. **Exija confirmação explícita** (digitar uma palavra) em operações destrutivas ou em muitos hosts.
8. **Não use prompts em automação.** Se o playbook roda em pipeline ou agendador, passe tudo por `-e`.
9. **Converta os tipos** (`| int`, `| bool`), pois todas as respostas são strings.
10. **Documente as perguntas** no início do playbook ou no README.

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Perguntar valores antes de tudo | `vars_prompt` |
| Esconder ou mostrar a digitação | `private: true` / `false` |
| Valor padrão fixo | `default` |
| Valor padrão condicional (por fact, host ou grupo) | Prompt sem `default` + `\| default(x, true)` / `set_fact` |
| Perguntar só em certos casos | `pause` com `when` |
| Pedir senha duas vezes | `confirm: true` |
| Gerar hash da senha digitada | `encrypt: sha512_crypt` |
| Pausar no meio do playbook | `ansible.builtin.pause` |
| Capturar resposta no meio do playbook | `pause` + `register` + `user_input` |
| Pausar por tempo | `pause: seconds:` / `minutes:` |
| Evitar a pergunta em automação | `-e "variavel=valor"` |
| Senha do sudo, SSH ou Vault | `-K`, `-k`, `--ask-vault-pass` |
| Garantir respostas válidas | `assert` |
