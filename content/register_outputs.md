# Capítulo: Registro de Outputs (`register`)

## 1. O que é o `register`

Toda task do Ansible produz um **resultado**: o que foi executado, se alterou algo, se falhou, o que foi impresso. Por padrão esse resultado é mostrado e descartado. A palavra-chave `register` **guarda o resultado em uma variável**, para ser usada nas tasks seguintes.

Foi o que você usou logo no início:

```yaml
- name: Get the hostname
  ansible.builtin.command: hostname -f
  register: res
  changed_when: false

- name: Show the output
  ansible.builtin.debug:
    msg: "The hostname is {{ res.stdout }}"
```

Casos de uso típicos:

- mostrar ou reaproveitar a saída de um comando;
- tomar decisões (`when`) com base no resultado de outra task;
- definir quando uma task é considerada alterada (`changed_when`) ou falha (`failed_when`);
- processar listas de resultados de um loop;
- gerar relatórios.

---

## 2. Sintaxe

```yaml
- name: Qualquer task
  ansible.builtin.command: uptime
  register: nome_da_variavel
```

O nome segue as mesmas regras de qualquer variável: letras, números e underscore, começando por letra ou underscore.

---

## 3. A estrutura do resultado

O conteúdo da variável registrada **depende do módulo** usado. Para ver exatamente o que existe, use `debug` com `var`:

```yaml
- name: Executar
  ansible.builtin.command: hostname -f
  register: res
  changed_when: false

- name: Ver tudo que foi registrado
  ansible.builtin.debug:
    var: res
```

Saída (resumida):

```json
{
    "changed": false,
    "cmd": ["hostname", "-f"],
    "delta": "0:00:00.003",
    "end": "2026-10-09 10:00:00.000",
    "failed": false,
    "msg": "",
    "rc": 0,
    "start": "2026-10-09 10:00:00.000",
    "stderr": "",
    "stderr_lines": [],
    "stdout": "deb00.exemplo.com",
    "stdout_lines": ["deb00.exemplo.com"]
}
```

### 3.1 Campos comuns de `command`, `shell` e `raw`

| Campo | Conteúdo |
|---|---|
| `stdout` | Saída padrão como texto (com quebras de linha) |
| `stdout_lines` | Saída padrão como **lista**, uma linha por item |
| `stderr` | Saída de erro como texto |
| `stderr_lines` | Saída de erro como lista |
| `rc` | Código de retorno (0 = sucesso) |
| `cmd` | O comando executado |
| `start`, `end`, `delta` | Início, fim e duração |
| `changed` | Se a task é considerada "alterada" |
| `failed` | Se a task falhou |
| `skipped` | Se foi pulada (por `when`) |

### 3.2 Campos de outros módulos

Cada módulo devolve seus próprios campos. Alguns exemplos:

| Módulo | Campos úteis |
|---|---|
| `stat` | `stat.exists`, `stat.size`, `stat.mode`, `stat.isdir` |
| `uri` | `status`, `json`, `content`, `url` |
| `find` | `files` (lista), `matched` |
| `slurp` | `content` (em base64) |
| `user` | `name`, `uid`, `home`, `shell` |
| `service` | `status`, `state` |
| `package`, `apt`, `dnf` | `changed`, `msg`, `results` |

Para qualquer módulo novo, a regra é: **rode com `debug: var=`** e descubra.

---

## 4. Usando o valor registrado

### 4.1 Texto da saída

```yaml
msg: "Host: {{ res.stdout }}"
```

### 4.2 Saída em lista

```yaml
- name: Listar usuários com shell de login
  ansible.builtin.command: grep -v nologin /etc/passwd
  register: usuarios
  changed_when: false

- name: Mostrar cada linha
  ansible.builtin.debug:
    msg: "{{ item }}"
  loop: "{{ usuarios.stdout_lines }}"
```

### 4.3 Primeiro e último itens

```yaml
msg: "Primeira linha: {{ usuarios.stdout_lines | first }}"
msg: "Última linha: {{ usuarios.stdout_lines | last }}"
msg: "Total de linhas: {{ usuarios.stdout_lines | length }}"
```

### 4.4 Limpando e transformando o texto

```yaml
msg: "{{ res.stdout | trim }}"                          # remove espaços e quebras nas pontas
msg: "{{ res.stdout | upper }}"                         # maiúsculas
msg: "{{ res.stdout | split('.') | first }}"            # parte antes do primeiro ponto
msg: "{{ res.stdout | regex_search('[0-9]+\\.[0-9]+') }}" # extrai um padrão
msg: "{{ res.stdout | int }}"                           # converte para número
```

### 4.5 Saída em JSON

Quando um comando imprime JSON, converta com `from_json`:

```yaml
- name: Obter dados em JSON
  ansible.builtin.command: ip -j addr show
  register: ip_json
  changed_when: false

- name: Usar os dados
  ansible.builtin.debug:
    msg: "{{ (ip_json.stdout | from_json)[0]['ifname'] }}"
```

---

## 5. Registro com condicionais

### 5.1 Decidindo com `when`

```yaml
- name: Verificar se o arquivo existe
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

### 5.2 Testando o resultado com `is`

O Ansible oferece testes prontos para variáveis registradas:

| Teste | Verdadeiro quando |
|---|---|
| `res is changed` | A task alterou algo |
| `res is failed` | A task falhou |
| `res is succeeded` | A task teve sucesso |
| `res is skipped` | A task foi pulada |

```yaml
- name: Reiniciar apenas se a configuração mudou
  ansible.builtin.service:
    name: ssh
    state: restarted
  when: config is changed
```

> Para esse último caso, o recurso idiomático é o `notify` com **handlers**, mas o `register` com `when` funciona e é mais explícito.

### 5.3 Comparando a saída

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

---

## 6. Controlando `changed` e `failed`

Comandos não sabem informar ao Ansible se "mudaram" algo. O padrão é considerar `command` e `shell` **sempre** como `changed`, o que polui o relatório final. Dois recursos corrigem isso.

### 6.1 `changed_when`

```yaml
- name: Consultar hostname (somente leitura)
  ansible.builtin.command: hostname -f
  register: res
  changed_when: false
```

Também aceita condições sobre a própria saída:

```yaml
- name: Executar script de sincronização
  ansible.builtin.command: /usr/local/bin/sync.sh
  register: sync
  changed_when: "'arquivos copiados' in sync.stdout"
```

### 6.2 `failed_when`

Define o que é considerado falha, em vez de depender só do código de retorno:

```yaml
- name: grep retorna 1 quando não encontra, o que não é um erro aqui
  ansible.builtin.command: grep -c "erro" /var/log/app.log
  register: contagem
  changed_when: false
  failed_when: contagem.rc > 1
```

Falhar com base no conteúdo da saída:

```yaml
- name: Falhar se aparecer ERROR
  ansible.builtin.command: /usr/local/bin/verificar.sh
  register: verif
  changed_when: false
  failed_when: "'ERROR' in verif.stdout"
```

### 6.3 `ignore_errors`

Continua o playbook mesmo que a task falhe, mantendo o resultado em `register`:

```yaml
- name: Tentar parar um serviço opcional
  ansible.builtin.service:
    name: servico-opcional
    state: stopped
  register: parada
  ignore_errors: true

- name: Informar
  ansible.builtin.debug:
    msg: "O serviço não existe ou não pôde ser parado"
  when: parada is failed
```

Prefira `failed_when` a `ignore_errors` quando possível, pois é mais preciso.

---

## 7. Registro em loops

Quando a task tem `loop`, a variável registrada guarda uma **lista de resultados** em `results`, um por item:

```yaml
- name: Verificar vários arquivos
  ansible.builtin.stat:
    path: "{{ item }}"
  loop:
    - /etc/hosts
    - /etc/hostname
    - /etc/nao-existe
  register: arquivos

- name: Mostrar quais existem
  ansible.builtin.debug:
    msg: "{{ item.item }}: {{ 'existe' if item.stat.exists else 'não existe' }}"
  loop: "{{ arquivos.results }}"
  loop_control:
    label: "{{ item.item }}"
```

Aqui `item.item` é o valor original do loop (o caminho) e `item.stat` é o resultado do módulo para aquele item.

Para filtrar apenas os que atendem a uma condição:

```yaml
- name: Listar apenas os arquivos existentes
  ansible.builtin.debug:
    msg: "{{ arquivos.results | selectattr('stat.exists') | map(attribute='item') | list }}"
```

---

## 8. Registro com tasks puladas

Se a task é pulada por `when`, a variável **ainda é criada**, mas contém apenas:

```json
{ "changed": false, "skipped": true, "skip_reason": "Conditional result was False" }
```

Por isso, acessar `res.stdout` de uma task pulada gera erro. Proteja com `default` ou teste `skipped`:

```yaml
- name: Executar apenas no Debian
  ansible.builtin.command: apt-get --version
  register: apt_ver
  changed_when: false
  when: ansible_facts['os_family'] == "Debian"

- name: Mostrar a versão, se existir
  ansible.builtin.debug:
    msg: "{{ apt_ver.stdout_lines | first }}"
  when: apt_ver is not skipped
```

Ou com valor padrão:

```yaml
msg: "{{ apt_ver.stdout | default('não se aplica') }}"
```

---

## 9. Escopo e duração

- A variável registrada é **por host**: cada host tem seu próprio valor.
- Vale **até o fim do play** (e dos plays seguintes do mesmo playbook, para aquele host).
- **Não persiste entre execuções.** Na próxima vez que o playbook rodar, começa vazia.
- Registrar com o mesmo nome em outra task **substitui** o valor anterior.
- Para persistir entre execuções, combine com `set_fact` e `cacheable: true` (com cache de facts configurado):

```yaml
- name: Guardar no cache de facts
  ansible.builtin.set_fact:
    versao_app: "{{ res.stdout | trim }}"
    cacheable: true
```

### 9.1 Acessando o registro de outro host

```yaml
- name: Ver o hostname registrado em deb00
  ansible.builtin.debug:
    msg: "{{ hostvars['deb00']['res']['stdout'] }}"
```

Funciona se a task com `register` já rodou naquele host durante a execução.

### 9.2 `run_once` e `register`

Com `run_once: true`, a task roda em apenas um host, mas o resultado registrado fica disponível para **todos os hosts do play**:

```yaml
- name: Obter a data uma única vez
  ansible.builtin.command: date +%F
  register: data
  changed_when: false
  run_once: true

- name: Usar em todos os hosts
  ansible.builtin.debug:
    msg: "Data: {{ data.stdout }}"
```

---

## 10. Modo `--check` e comandos de leitura

No modo `--check`, os módulos `command` e `shell` **não são executados** (são pulados), então a variável registrada fica sem `stdout`. Isso pode quebrar tasks seguintes.

Para comandos de apenas leitura, que são seguros em qualquer modo, use `check_mode: false`:

```yaml
- name: Consultar hostname (executa mesmo em --check)
  ansible.builtin.command: hostname -f
  register: res
  changed_when: false
  check_mode: false
```

Assim, `res.stdout` existe também em `--check`.

---

## 11. Repetindo até obter o resultado: `until`

O `register` é o que permite o `until` avaliar a saída a cada tentativa:

```yaml
- name: Aguardar o serviço responder
  ansible.builtin.uri:
    url: http://localhost:8080/health
    return_content: true
  register: saude
  until: saude.status == 200
  retries: 10
  delay: 5
```

Tenta até 10 vezes, com intervalo de 5 segundos.

---

## 12. Salvando o resultado em arquivo

### 12.1 No host remoto

```yaml
- name: Salvar a saída em arquivo
  ansible.builtin.copy:
    dest: /tmp/hostname.txt
    content: "{{ res.stdout }}\n"
    mode: "0644"
```

### 12.2 Na máquina de controle (relatório consolidado)

```yaml
- name: Gravar relatório local
  ansible.builtin.lineinfile:
    path: ./relatorio.txt
    line: "{{ inventory_hostname }};{{ res.stdout }}"
    create: true
  delegate_to: localhost
  become: false
```

Com isso, cada host acrescenta uma linha ao arquivo `relatorio.txt` na máquina onde o Ansible roda.

---

## 13. Dados sensíveis

A variável registrada pode conter senhas ou tokens, e a saída do playbook (e os logs) os mostrarão. Proteja com `no_log`:

```yaml
- name: Obter token
  ansible.builtin.command: /usr/local/bin/gerar-token
  register: token
  changed_when: false
  no_log: true
```

A variável continua utilizável, mas o conteúdo não aparece na saída.

---

## 14. Exemplo completo

Relatório de uso de disco em Debian e Red Hat, com alerta e tags:

```yaml
---
- name: Relatório de disco
  hosts: all
  gather_facts: true
  become: true

  vars:
    limite_uso: 80

  tasks:
    - name: Obter uso da partição raiz (%)
      ansible.builtin.shell: df --output=pcent / | tail -1 | tr -dc '0-9'
      register: uso_raiz
      changed_when: false
      check_mode: false
      tags: disco

    - name: Obter os 3 maiores diretórios em /var
      ansible.builtin.shell: du -x -d1 /var 2>/dev/null | sort -nr | head -4 | tail -3
      register: maiores
      changed_when: false
      check_mode: false
      tags: disco

    - name: Mostrar o resumo
      ansible.builtin.debug:
        msg:
          - "Host: {{ inventory_hostname }} ({{ ansible_facts['distribution'] }})"
          - "Uso da raiz: {{ uso_raiz.stdout | int }}%"
          - "Maiores diretórios em /var:"
          - "{{ maiores.stdout_lines }}"
      tags: disco

    - name: Alertar se passou do limite
      ansible.builtin.debug:
        msg: "ALERTA: {{ inventory_hostname }} com {{ uso_raiz.stdout | int }}% de uso"
      when: uso_raiz.stdout | int > limite_uso
      tags: alerta

    - name: Gravar relatório local
      ansible.builtin.lineinfile:
        path: ./relatorio_disco.csv
        line: "{{ inventory_hostname }};{{ uso_raiz.stdout | int }}"
        create: true
      delegate_to: localhost
      become: false
      tags: relatorio
```

Execuções:

```bash
ansible-playbook -i hosts disco.yml
ansible-playbook -i hosts disco.yml --tags alerta --limit deb00,deb02
ansible-playbook -i hosts disco.yml -e "limite_uso=60"
```

---

## 15. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `'res' is undefined` | A task com `register` não rodou nesse host (tag, `--limit` ou condição) | Garantir que a task roda, ou usar `default` |
| `'dict object' has no attribute 'stdout'` | Task pulada, ou módulo sem `stdout` | Testar `is not skipped`, ou ver os campos com `debug var=` |
| Task sempre aparece como `changed` | `command` e `shell` assumem `changed` | Usar `changed_when: false` |
| Playbook para por um código de retorno diferente de 0 que é esperado | Falha padrão por `rc != 0` | Usar `failed_when` |
| `stdout` vem vazio em `--check` | `command` não executa em modo check | Usar `check_mode: false` |
| Comparação numérica falha | `stdout` é texto | Usar `\| int` (ou `\| float`) |
| Valor com espaços ou quebra de linha inesperada | `stdout` traz o `\n` final | Usar `\| trim` |
| Loop: não acho a saída | Resultados estão em `.results` | Iterar sobre `res.results` |
| Valor "vaza" nos logs | Falta `no_log` | Adicionar `no_log: true` |
| Variável tem valor antigo | Outra task reutilizou o mesmo nome | Usar nomes distintos e descritivos |

---

## 16. Boas práticas

1. **Descubra a estrutura antes de usar:** rode `debug: var=` na variável registrada.
2. **Use nomes descritivos** (`uso_raiz`, `ssh_status`) em vez de `res`, `r`, `out`.
3. **Prefira módulos específicos a `command` e `shell`**; o `register` de um módulo costuma trazer dados estruturados mais fáceis de usar.
4. **Sempre use `changed_when: false`** em comandos de apenas leitura.
5. **Use `check_mode: false`** nesses mesmos comandos, para funcionarem em `--check`.
6. **Prefira `stdout_lines`** quando for iterar, e `stdout | trim` quando for comparar.
7. **Converta tipos** com `| int` e `| float` antes de comparar números.
8. **Proteja contra tasks puladas** com `is not skipped` ou `default()`.
9. **Use `failed_when` em vez de `ignore_errors`** sempre que puder.
10. **Aplique `no_log: true`** quando o resultado contiver dados sensíveis.
11. **Não dependa do registro entre execuções;** use `set_fact` com `cacheable` ou um arquivo, se precisar persistir.
12. **Veja mais detalhes com verbosidade:** `-v` mostra o resultado das tasks, `-vvv` inclui detalhes de conexão.

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Guardar o resultado de uma task | `register: nome` |
| Ver tudo que foi registrado | `debug: var=nome` |
| Texto da saída | `nome.stdout` |
| Saída em lista de linhas | `nome.stdout_lines` |
| Código de retorno | `nome.rc` |
| Saída em JSON | `nome.stdout \| from_json` |
| Evitar `changed` em leitura | `changed_when: false` |
| Definir o que é falha | `failed_when: condição` |
| Testar sucesso, falha, alteração ou pulo | `is succeeded`, `is failed`, `is changed`, `is skipped` |
| Resultado de loop | `nome.results` |
| Rodar comando de leitura em `--check` | `check_mode: false` |
| Repetir até obter o resultado | `until`, `retries`, `delay` |
| Compartilhar com todos os hosts | `run_once: true` |
| Ler o registro de outro host | `hostvars['host']['nome']` |
| Persistir entre execuções | `set_fact` com `cacheable: true` |
| Ocultar dados sensíveis | `no_log: true` |
