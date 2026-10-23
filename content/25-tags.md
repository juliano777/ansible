# Capítulo: Tags no Ansible

## 1. O que são tags

Tags são rótulos que você anexa a tasks, blocos, plays, roles ou imports. Em vez de executar um playbook inteiro, você pode escolher **quais partes** dele rodar (ou quais pular) diretamente na linha de comando.

Elas são úteis quando o playbook cresce e você precisa, por exemplo:

- atualizar apenas os pacotes, sem tocar na configuração;
- reiniciar apenas um serviço;
- executar somente tarefas de diagnóstico;
- pular uma etapa demorada durante testes.

---

## 2. Aplicando tags em uma task

Use a chave `tags`, com uma lista:

```yaml
---
- name: Exemplo de tags
  hosts: all
  gather_facts: true
  become: true

  tasks:
    - name: Update all packages (Debian / Red Hat)
      ansible.builtin.package:
        name: "*"
        state: latest
        update_cache: true
      tags:
        - upgrade
        - all_packages

    - name: Show hostname
      ansible.builtin.debug:
        msg: "=== Server name: {{ inventory_hostname }}"
      tags:
        - hostname
        - who
```

Uma task pode ter quantas tags quiser, e a mesma tag pode ser usada em várias tasks. Também é aceita a forma compacta:

```yaml
      tags: upgrade
      tags: [upgrade, all_packages]
```

> **Atenção à indentação:** `tags` é uma chave da **task**, no mesmo nível de `name` e do módulo. Já `update_cache`, `name` e `state` pertencem ao **módulo** e ficam um nível abaixo.

---

## 3. Executando com tags

### 3.1 Rodar apenas tasks com determinada tag

```bash
ansible-playbook -i hosts test.yml --tags upgrade
```

### 3.2 Várias tags (separadas por vírgula)

```bash
ansible-playbook -i hosts test.yml --tags "upgrade,hostname"
```

Roda as tasks que tenham **qualquer uma** das tags informadas.

### 3.3 Pular tags

```bash
ansible-playbook -i hosts test.yml --skip-tags upgrade
```

Roda tudo, **exceto** o que tiver a tag `upgrade`.

### 3.4 Listar tags e tasks sem executar

```bash
ansible-playbook -i hosts test.yml --list-tags
ansible-playbook -i hosts test.yml --list-tasks
ansible-playbook -i hosts test.yml --list-tasks --tags upgrade
```

A última linha é uma ótima forma de **conferir o que vai rodar** antes de executar de verdade.

### 3.5 Combinando com outras opções

```bash
ansible-playbook -i hosts test.yml --tags upgrade --limit deb00,deb02 --check
```

`--limit` restringe os hosts, `--tags` restringe as tasks e `--check` simula a execução.

---

## 4. Tags em níveis maiores: play, bloco e role

Uma tag aplicada a um nível superior é **herdada** por tudo que está dentro dele.

### 4.1 Tag no play

```yaml
- name: Manutenção
  hosts: all
  tags: manutencao
  tasks:
    - name: Task A
      ansible.builtin.debug:
        msg: "A"

    - name: Task B
      ansible.builtin.debug:
        msg: "B"
```

Ambas as tasks respondem à tag `manutencao`.

### 4.2 Tag em um bloco

```yaml
  tasks:
    - name: Atualizações
      tags: updates
      block:
        - name: Atualizar cache
          ansible.builtin.apt:
            update_cache: true
          when: ansible_os_family == "Debian"

        - name: Atualizar pacotes
          ansible.builtin.apt:
            name: "*"
            state: latest
          when: ansible_os_family == "Debian"
```

Agrupar tasks em um `block` evita repetir a mesma tag em cada uma.

### 4.3 Tag em uma role

```yaml
  roles:
    - role: nginx
      tags: web
    - role: postgresql
      tags: db
```

Todas as tasks da role recebem a tag.

---

## 5. Imports e includes: herança estática e dinâmica

O comportamento muda conforme o tipo de reaproveitamento:

| Diretiva | Tipo | Tags na diretiva |
|---|---|---|
| `import_tasks`, `import_role` | Estática (processada ao carregar o playbook) | São herdadas por todas as tasks importadas |
| `include_tasks`, `include_role` | Dinâmica (processada durante a execução) | Valem **apenas** para a própria task de include |

Exemplo estático (tag herdada):

```yaml
    - ansible.builtin.import_tasks: pacotes.yml
      tags: pacotes
```

Exemplo dinâmico: para propagar a tag ao conteúdo incluído, use `apply`:

```yaml
    - ansible.builtin.include_tasks:
        file: pacotes.yml
        apply:
          tags: pacotes
      tags: pacotes
```

A tag fora do `apply` garante que o próprio include seja executado quando você usar `--tags pacotes`; a tag dentro do `apply` é a que vai para as tasks incluídas.

---

## 6. Tags especiais

O Ansible reserva alguns nomes com comportamento próprio.

### 6.1 `always`

Tasks com a tag `always` rodam **sempre**, mesmo quando você filtra com `--tags`. Só deixam de rodar se você pedir explicitamente com `--skip-tags always`.

```yaml
    - name: Validar conectividade
      ansible.builtin.ping:
      tags: always
```

### 6.2 `never`

Tasks com a tag `never` **não rodam por padrão**. Só executam se você chamar explicitamente uma tag associada a elas. É ideal para tarefas perigosas ou raras.

```yaml
    - name: Limpar cache de pacotes (apenas sob demanda)
      ansible.builtin.command: apt-get clean
      changed_when: true
      tags:
        - never
        - limpeza
```

```bash
ansible-playbook -i hosts test.yml --tags limpeza
```

### 6.3 `all`, `tagged` e `untagged`

São valores usados na linha de comando:

| Opção | Efeito |
|---|---|
| `--tags all` | Roda todas as tasks (comportamento padrão) |
| `--tags tagged` | Roda apenas tasks que tenham alguma tag |
| `--tags untagged` | Roda apenas tasks sem nenhuma tag |
| `--skip-tags tagged` | Pula as tasks que tenham alguma tag |

---

## 7. Detalhes importantes

- **Coleta de facts:** com `gather_facts: true`, a coleta acontece mesmo quando você filtra por `--tags`. Se uma task depende de facts (como `ansible_os_family`), eles estarão disponíveis. Em compensação, você paga o tempo da coleta mesmo rodando uma única tag.
- **Tasks dependentes:** se uma task usa um valor registrado (`register`) por outra task que foi pulada pela tag, a variável não existirá. Ao filtrar por tags, tenha certeza de que as dependências também serão executadas.
- **Tags são estáticas:** não é possível usar variáveis ou condicionais para definir o valor de uma tag. Para decisões dinâmicas, use `when`.
- **Nomes:** prefira nomes curtos, em minúsculas e sem espaços (`upgrade`, `packages`, `web`). Use um padrão consistente em todo o projeto.
- **Tags não são condicionais:** `--tags` seleciona quais tasks entram na execução, mas o `when` de cada task continua sendo avaliado normalmente.

---

## 8. Boas práticas

1. **Defina um vocabulário de tags** para o projeto (por exemplo: `packages`, `config`, `services`, `security`) e documente-o no README.
2. **Use tags por finalidade**, não por detalhe de implementação. `upgrade` é mais útil que `apt_task`.
3. **Prefira blocos ou roles** a repetir a mesma tag em dezenas de tasks.
4. **Use `never` para tarefas destrutivas**, de modo que só rodem quando solicitadas.
5. **Use `always` com moderação**, apenas para verificações realmente indispensáveis.
6. **Valide antes de executar:** combine `--list-tasks` e `--check` com `--tags`.
7. **Evite excesso de tags.** Se quase toda task tem três ou quatro tags, a organização provavelmente precisa ser repensada.

---

## 9. Exemplo completo

```yaml
---
- name: Manutenção de servidores Debian e Red Hat
  hosts: all
  gather_facts: true
  become: true

  tasks:
    - name: Verificar conectividade
      ansible.builtin.ping:
      tags: always

    - name: Atualizar cache de pacotes
      ansible.builtin.package:
        update_cache: true
      tags:
        - cache
        - packages

    - name: Atualizar todos os pacotes
      ansible.builtin.package:
        name: "*"
        state: latest
        update_cache: true
      tags:
        - upgrade
        - packages

    - name: Mostrar o nome do servidor
      ansible.builtin.debug:
        msg: "=== Server name: {{ inventory_hostname }}"
      tags:
        - hostname
        - who

    - name: Limpar cache de pacotes (apenas sob demanda)
      ansible.builtin.command: "{{ 'apt-get clean' if ansible_os_family == 'Debian' else 'dnf clean all' }}"
      changed_when: true
      tags:
        - never
        - limpeza
```

Cenários de uso:

```bash
# Somente atualizar o cache
ansible-playbook -i hosts manutencao.yml --tags cache

# Tudo relacionado a pacotes
ansible-playbook -i hosts manutencao.yml --tags packages

# Tudo, exceto a atualização completa
ansible-playbook -i hosts manutencao.yml --skip-tags upgrade

# Mostrar o hostname em dois servidores
ansible-playbook -i hosts manutencao.yml --tags hostname --limit deb00,deb02

# Executar a limpeza, que nunca roda por padrão
ansible-playbook -i hosts manutencao.yml --tags limpeza

# Ver o que rodaria com a tag packages, sem executar
ansible-playbook -i hosts manutencao.yml --list-tasks --tags packages
```

---

## 10. Resumo

| Necessidade | Comando / recurso |
|---|---|
| Rodar só uma parte | `--tags nome` |
| Rodar tudo menos uma parte | `--skip-tags nome` |
| Ver tags existentes | `--list-tags` |
| Ver tasks que vão rodar | `--list-tasks --tags nome` |
| Rodar sempre | tag `always` |
| Nunca rodar por padrão | tag `never` |
| Aplicar tag a várias tasks | `block`, play ou role |
| Propagar tag em include dinâmico | `apply: tags:` |

Com tags bem planejadas, um único playbook pode servir a várias finalidades, sem precisar dividir o código em muitos arquivos.
