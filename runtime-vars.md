# Capítulo: Variáveis em Runtime com `--extra-vars`

## 1. O que são extra vars

Extra vars são variáveis passadas **na hora da execução**, direto na linha de comando, com a opção `-e` ou `--extra-vars`. Elas permitem que o mesmo playbook se comporte de maneira diferente a cada execução, sem editar nenhum arquivo.

```bash
ansible-playbook -i hosts test.yml -e "usuario=maria"
```

As duas formas são equivalentes:

```bash
ansible-playbook -i hosts test.yml -e "usuario=maria"
ansible-playbook -i hosts test.yml --extra-vars "usuario=maria"
```

### Característica principal: precedência máxima

Extra vars têm a **maior precedência** de todas as fontes de variáveis. Valem mais que `vars`, `vars_files`, `group_vars`, `host_vars`, facts, `register` e até `set_fact`.

Isso as torna ideais para sobrescrever valores pontualmente, mas também exige cuidado: nenhum outro lugar consegue "desfazer" uma extra var.

---

## 2. Formatos aceitos

### 2.1 Formato `chave=valor`

O mais simples. Várias variáveis na mesma string, separadas por espaço:

```bash
ansible-playbook -i hosts test.yml -e "usuario=maria porta_http=9090"
```

Valores com espaços precisam de aspas internas:

```bash
ansible-playbook -i hosts test.yml -e "mensagem='Olá, mundo' ambiente=dev"
```

> **Atenção:** no formato `chave=valor`, **todos os valores são strings**. `porta_http=9090` vira o texto `"9090"` e `ativo=true` vira o texto `"true"`. Para tipos reais (número, booleano, lista, dicionário), use JSON ou YAML (próximas seções).

### 2.2 Formato JSON

Preserva os tipos de dados e permite listas e dicionários. No shell, envolva o JSON em **aspas simples**:

```bash
ansible-playbook -i hosts test.yml -e '{"porta_http": 9090, "ativo": true, "pacotes": ["vim", "git", "curl"]}'
```

Exemplo com dicionário:

```bash
ansible-playbook -i hosts test.yml -e '{"usuario": {"nome": "maria", "shell": "/bin/bash"}}'
```

Nesse caso, o playbook acessa `usuario.nome` e `usuario.shell`.

### 2.3 Formato arquivo (`@arquivo`)

Carrega as variáveis de um arquivo YAML ou JSON, usando o prefixo `@`:

```bash
ansible-playbook -i hosts test.yml -e @vars/producao.yml
```

Conteúdo de `vars/producao.yml`:

```yaml
---
ambiente: producao
porta_http: 80
pacotes:
  - nginx
  - htop
```

Como o arquivo é carregado como extra var, ele também tem precedência máxima. É a forma mais indicada quando há muitas variáveis.

### 2.4 Combinando vários `-e`

A opção pode ser repetida e os formatos podem ser misturados. Quando há conflito, **vale o último**:

```bash
ansible-playbook -i hosts test.yml \
  -e @vars/comum.yml \
  -e @vars/producao.yml \
  -e "porta_http=8080"
```

Aqui, `porta_http=8080` sobrescreve o valor dos dois arquivos.

---

## 3. Um exemplo completo

### 3.1 O playbook

```yaml
---
- name: Instalar um pacote informado em runtime
  hosts: all
  gather_facts: true
  become: true

  tasks:
    - name: Validar entrada
      ansible.builtin.assert:
        that:
          - pacote is defined
          - pacote | length > 0
        fail_msg: "Informe o pacote: -e pacote=<nome>"
      tags: always

    - name: Instalar o pacote
      ansible.builtin.package:
        name: "{{ pacote }}"
        state: "{{ estado | default('present') }}"
        update_cache: true
      tags: instalar
```

### 3.2 Executando

```bash
# Instalar htop
ansible-playbook -i hosts test.yml -e "pacote=htop"

# Remover htop
ansible-playbook -i hosts test.yml -e "pacote=htop estado=absent"

# Esquecendo de informar o pacote: o assert falha com a mensagem clara
ansible-playbook -i hosts test.yml
```

---

## 4. Tipos de dados: o cuidado com booleanos e números

Como `chave=valor` gera strings, comparações podem se comportar de forma inesperada.

```bash
ansible-playbook -i hosts test.yml -e "reiniciar=false"
```

```yaml
# PERIGO: o texto "false" é considerado verdadeiro
- name: Reiniciar
  ansible.builtin.reboot:
  when: reiniciar
```

Duas soluções:

**1. Converter com o filtro `bool`:**

```yaml
  when: reiniciar | bool
```

**2. Passar o valor como JSON, com tipo real:**

```bash
ansible-playbook -i hosts test.yml -e '{"reiniciar": false}'
```

O mesmo vale para números: com `chave=valor`, use `| int` quando precisar comparar ou calcular.

```yaml
when: porta_http | int > 1024
```

**Boa prática:** use `| bool` e `| int` nos playbooks que aceitam extra vars, e todas as formas de entrada passam a funcionar.

---

## 5. Valores padrão e variáveis obrigatórias

Quem executa o playbook pode esquecer de informar uma variável. Há três estratégias.

### 5.1 Valor padrão com `default`

```yaml
msg: "Porta: {{ porta_http | default(80) }}"
```

Se a extra var não foi passada, usa 80.

### 5.2 Obrigatória com `mandatory`

```yaml
msg: "{{ pacote | mandatory }}"
```

Falha se `pacote` não existir.

### 5.3 Validação antecipada com `assert`

A melhor opção para entradas importantes, pois falha logo no início, com uma mensagem útil (ver exemplo da seção 3).

```yaml
- name: Validar variáveis
  ansible.builtin.assert:
    that:
      - ambiente in ['dev', 'homolog', 'prod']
    fail_msg: "ambiente deve ser dev, homolog ou prod"
```

---

## 6. Usos práticos e comuns

### 6.1 Escolher os hosts em runtime

```yaml
---
- name: Playbook com alvo dinâmico
  hosts: "{{ alvo }}"
  gather_facts: false
  tasks:
    - ansible.builtin.ping:
```

```bash
ansible-playbook -i hosts test.yml -e "alvo=debian"
ansible-playbook -i hosts test.yml -e "alvo=deb00"
```

Sem passar `alvo`, o Ansible falha com `'alvo' is undefined`, o que é um comportamento seguro: evita rodar por engano em todos os hosts. Evite usar `default('all')` em playbooks que fazem alterações.

> Em muitos casos, `--limit` resolve o mesmo problema sem precisar de variável: `ansible-playbook -i hosts test.yml --limit deb00,deb02`.

### 6.2 Escolher a versão a instalar

```yaml
- name: Instalar versão específica
  ansible.builtin.package:
    name: "{{ pacote }}={{ versao }}"
    state: present
```

```bash
ansible-playbook -i hosts test.yml -e "pacote=nginx versao=1.22.1-9"
```

(O formato `pacote=versao` vale para `apt`; no `dnf` o formato é `pacote-versao`.)

### 6.3 Ligar ou desligar etapas

```yaml
- name: Reiniciar o servidor
  ansible.builtin.reboot:
  when: reiniciar | default(false) | bool
```

```bash
ansible-playbook -i hosts test.yml -e "reiniciar=true"
```

### 6.4 Ambientes diferentes

```bash
ansible-playbook -i hosts deploy.yml -e @vars/dev.yml
ansible-playbook -i hosts deploy.yml -e @vars/prod.yml
```

### 6.5 Usando variáveis do shell

```bash
VERSAO="1.2.3"
ansible-playbook -i hosts deploy.yml -e "versao=$VERSAO"
```

Muito comum em scripts e pipelines de CI/CD, onde o número da versão ou o nome do ambiente vêm de variáveis do pipeline.

### 6.6 Em comandos ad-hoc

```bash
ansible deb00 -i hosts -m ansible.builtin.debug -a "msg='Olá, {{ nome }}'" -e "nome=tux"
```

### 6.7 Combinando com tags, limit e check

```bash
ansible-playbook -i hosts test.yml \
  --tags instalar \
  --limit deb00,deb02 \
  --check \
  -e "pacote=htop"
```

---

## 7. Extra vars e `vars_prompt`

Se uma variável de `vars_prompt` já foi definida por extra var, o Ansible **não pergunta**. Isso permite que o mesmo playbook funcione de forma interativa (um humano responde) e automatizada (um script passa o valor):

```yaml
- hosts: all
  vars_prompt:
    - name: ambiente
      prompt: "Qual o ambiente?"
      default: dev
```

```bash
# Interativo: pergunta
ansible-playbook -i hosts test.yml

# Automatizado: não pergunta
ansible-playbook -i hosts test.yml -e "ambiente=prod"
```

---

## 8. Segurança: cuidado com dados sensíveis

Valores passados diretamente na linha de comando ficam expostos:

- no **histórico do shell** (`history`);
- na **lista de processos** (`ps aux`), visível a outros usuários;
- em **logs** de CI/CD.

Por isso, evite:

```bash
# EVITE
ansible-playbook -i hosts test.yml -e "db_senha=MinhaSenha123"
```

Prefira:

**1. Arquivo criptografado com Vault:**

```bash
ansible-vault create vars/segredos.yml
ansible-playbook -i hosts test.yml -e @vars/segredos.yml --ask-vault-pass
```

**2. Arquivo com permissões restritas** (`chmod 600`) e fora do controle de versão:

```bash
ansible-playbook -i hosts test.yml -e @/etc/ansible/segredos.yml
```

Em tasks que usam valores sensíveis, adicione `no_log: true` para que o conteúdo não apareça na saída:

```yaml
- name: Criar usuário do banco
  ansible.builtin.command: criar-usuario --senha "{{ db_senha }}"
  no_log: true
```

---

## 9. Extra vars em ferramentas gráficas e pipelines

- **AWX / Ansible Automation Platform:** o campo "Extra Variables" nos templates de job faz exatamente o mesmo papel do `-e`, e a opção "Prompt on launch" permite pedir esses valores na hora de executar.
- **CI/CD (GitLab CI, GitHub Actions, Jenkins):** variáveis do pipeline são repassadas via `-e`, em geral combinadas com `@arquivo` para valores fixos por ambiente.

---

## 10. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Variável não muda mesmo definida em `vars` | A extra var tem precedência | Remover o `-e` ou alterar o valor dele |
| `when: flag` sempre verdadeiro | Valor veio como string `"false"` | Usar `flag \| bool` ou passar JSON |
| Erro de parsing ao passar JSON | Aspas do shell erradas | Envolver o JSON em aspas simples `'...'` |
| Valor com espaço é cortado | Falta de aspas internas | `-e "msg='texto com espaço'"` |
| `'x' is undefined` | Variável não informada | Usar `default()`, `mandatory` ou `assert` |
| Valor do arquivo é ignorado | Outro `-e` posterior sobrescreveu | Verificar a ordem dos `-e` |
| `@arquivo` não encontrado | Caminho relativo ao diretório atual | Executar da pasta correta ou usar caminho absoluto |
| Senha aparece no histórico | Passada diretamente na linha | Usar arquivo com Vault |

---

## 11. Boas práticas

1. **Use extra vars para o que muda a cada execução** (versão, alvo, ambiente), e `group_vars` ou `vars_files` para o que é configuração estável.
2. **Documente** as variáveis esperadas no início do playbook ou no README, com exemplos de uso.
3. **Valide a entrada** com `assert` logo na primeira task.
4. **Defina padrões seguros** com `default()`. Para operações destrutivas, prefira exigir a variável (sem padrão).
5. **Prefira JSON ou arquivo** quando precisar de tipos (booleano, número, lista, dicionário).
6. **Use `| bool` e `| int`** nas variáveis que podem vir como texto.
7. **Não passe segredos na linha de comando**; use Vault.
8. **Evite sobrescritas inesperadas:** como extra vars vencem tudo, use nomes específicos (`deploy_versao` em vez de `versao`) para não colidir com variáveis de roles e do inventário.
9. **Teste com `--check`** antes de aplicar mudanças com valores novos.
10. **Registre o comando usado** (em script ou pipeline) para tornar a execução reproduzível.

---

## Resumo

| Necessidade | Comando |
|---|---|
| Uma ou poucas variáveis simples | `-e "chave=valor chave2=valor2"` |
| Valores com espaço | `-e "msg='texto com espaço'"` |
| Tipos reais, listas, dicionários | `-e '{"lista": ["a","b"], "ativo": true}'` |
| Muitas variáveis | `-e @arquivo.yml` |
| Combinar fontes | Vários `-e` (o último vence) |
| Dados sensíveis | `-e @segredos.yml --ask-vault-pass` |
| Garantir que a variável existe | `assert`, `mandatory` ou `default()` |
| Tratar texto como booleano ou número | `\| bool` e `\| int` |
| Precedência | Extra vars vencem todas as outras fontes |
