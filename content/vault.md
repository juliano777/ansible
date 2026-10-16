# Capítulo: Ansible Vault

## 1. O que é o Ansible Vault

O **Ansible Vault** é o recurso do Ansible para **criptografar dados sensíveis** (senhas, tokens, chaves privadas, certificados) e guardá-los junto do restante do projeto, sem expô-los em texto puro. Ele resolve um problema clássico: o playbook precisa de uma senha, mas você não quer (e não deve) colocá-la visível no repositório Git.

O que o Vault permite:

- criptografar **arquivos inteiros** (por exemplo, um arquivo de variáveis);
- criptografar **variáveis individuais**, embutidas em um arquivo YAML comum;
- usar esses dados **normalmente** em playbooks e roles: o Ansible descriptografa em memória, no momento da execução, quando recebe a senha do Vault.

O Vault **não** é um cofre de segredos completo (não há auditoria, rotação automática ou controle de acesso por usuário). É uma proteção simples e eficaz para dados em repouso nos arquivos do projeto (ver seção 16).

Um exemplo do que ele protege. Sem Vault, em `group_vars/db.yml`:

```yaml
# EXPOSTO no repositório
db_senha: "S3nh4-Forte"
```

Com Vault, o arquivo fica assim:

```
$ANSIBLE_VAULT;1.1;AES256
62313365396662343061393464336163383764373764613633653634306231386433626436623361
3434356430313433336265393934...
```

---

## 2. Como funciona

- O conteúdo é criptografado com **AES-256**, usando uma chave derivada da senha do Vault, e protegido por um código de autenticação (HMAC), que detecta alterações indevidas.
- A primeira linha do arquivo, o **cabeçalho**, identifica o formato: `$ANSIBLE_VAULT;1.1;AES256` (ou `1.2`, quando há um *vault id* com rótulo).
- Os arquivos criptografados são **texto**, então podem ser versionados no Git.
- Para qualquer comando que **use** o conteúdo (`ansible-playbook`, `ansible`), é preciso fornecer a senha do Vault.
- A senha em si **nunca** fica no repositório.

---

## 3. O comando `ansible-vault`

| Comando | O que faz |
|---|---|
| `ansible-vault create arquivo` | Cria um arquivo novo, já criptografado, abrindo o editor |
| `ansible-vault encrypt arquivo` | Criptografa um arquivo **existente** |
| `ansible-vault view arquivo` | Mostra o conteúdo descriptografado, sem alterar o arquivo |
| `ansible-vault edit arquivo` | Descriptografa, abre no editor e criptografa de novo ao salvar |
| `ansible-vault decrypt arquivo` | **Remove** a criptografia do arquivo (cuidado) |
| `ansible-vault rekey arquivo` | Troca a senha do Vault do arquivo |
| `ansible-vault encrypt_string` | Criptografa um **texto** (para variáveis individuais) |

### 3.1 Criar

```bash
ansible-vault create group_vars/db/vault.yml
```

```
New Vault password:
Confirm New Vault password:
```

Em seguida o editor abre (definido pela variável `EDITOR`; use `EDITOR=nano ansible-vault create ...` para escolher). Escreva o conteúdo e salve:

```yaml
---
vault_postgresql_app_senha: "S3nh4-Forte"
vault_postgresql_admin_senha: "Outra-S3nha"
```

### 3.2 Criptografar um arquivo existente

```bash
ansible-vault encrypt group_vars/db/vault.yml
```

Para gerar uma cópia criptografada, sem alterar o original:

```bash
ansible-vault encrypt segredos.yml --output segredos.vault.yml
```

### 3.3 Visualizar e editar

```bash
ansible-vault view group_vars/db/vault.yml
ansible-vault edit group_vars/db/vault.yml
```

Prefira sempre `edit` e `view`: eles nunca deixam uma cópia descriptografada gravada no disco de forma permanente.

### 3.4 Remover a criptografia

```bash
ansible-vault decrypt group_vars/db/vault.yml
```

O arquivo volta ao texto puro **no disco**. Só faça isso se tiver certeza, e **nunca** faça commit do resultado. Para apenas ler o conteúdo, use `view`.

### 3.5 Trocar a senha (`rekey`)

```bash
ansible-vault rekey group_vars/db/vault.yml
```

Pede a senha antiga e a nova. Com arquivos de senha:

```bash
ansible-vault rekey --vault-password-file ~/.vault_antiga \
                    --new-vault-password-file ~/.vault_nova \
                    group_vars/db/vault.yml
```

---

## 4. Informando a senha do Vault

Há quatro formas. Escolha conforme o contexto.

### 4.1 Digitando na hora (`--ask-vault-pass`)

```bash
ansible-playbook -i hosts pg.yml -K --ask-vault-pass
```

Simples e seguro para uso manual. Não serve para automação.

### 4.2 Arquivo de senha (`--vault-password-file`)

```bash
echo 'SenhaDoVault-Forte' > ~/.vault_pass
chmod 600 ~/.vault_pass

ansible-playbook -i hosts pg.yml -K --vault-password-file ~/.vault_pass
```

Cuidados: o arquivo deve conter **apenas** a senha, com permissão restrita (`600`), e **nunca** ser versionado.

### 4.3 Configuração no `ansible.cfg`

Para não repetir a opção a cada execução:

```ini
[defaults]
vault_password_file = ~/.vault_pass
```

Também é possível usar a variável de ambiente:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
```

### 4.4 Script que devolve a senha

Se o arquivo de senha for **executável**, o Ansible o executa e usa a saída (a primeira linha) como senha. Isso permite buscar a senha em um gerenciador de segredos ou em uma variável de ambiente (seção 13):

```bash
#!/bin/sh
echo "$ANSIBLE_VAULT_PASS"
```

```bash
chmod 700 vault-pass.sh
ansible-playbook -i hosts pg.yml --vault-password-file ./vault-pass.sh
```

### 4.5 Senha do Vault × senha do `sudo`

São coisas independentes:

| Opção | Pede |
|---|---|
| `--ask-vault-pass` | A senha do **Vault** (para descriptografar os dados) |
| `-K` (`--ask-become-pass`) | A senha do **sudo** nos hosts |
| `-k` (`--ask-pass`) | A senha do **SSH** |

Em um mesmo comando, as três podem aparecer:

```bash
ansible-playbook -i hosts pg.yml -K --ask-vault-pass
```

---

## 5. Usando arquivos criptografados

### 5.1 `group_vars` e `host_vars`

Arquivos criptografados dentro de `group_vars/` e `host_vars/` são carregados **automaticamente**, desde que a senha seja fornecida. Não é preciso declarar nada no playbook:

```
group_vars/
└── db/
    ├── vars.yml        # texto puro
    └── vault.yml       # criptografado
```

Quando o grupo tem um **diretório**, todos os arquivos dentro dele são lidos (em ordem alfabética), misturando arquivos comuns e criptografados.

### 5.2 `vars_files` e `include_vars`

```yaml
- hosts: db
  vars_files:
    - vars/segredos.yml         # pode estar criptografado
  tasks:
    - ansible.builtin.include_vars: vars/mais_segredos.yml
```

### 5.3 `--extra-vars` com arquivo

```bash
ansible-playbook -i hosts pg.yml -e @segredos.yml --ask-vault-pass
```

O arquivo criptografado também funciona com `@`, como mencionado no capítulo de extra vars.

---

## 6. O padrão `vault_` (recomendado)

Um arquivo inteiramente criptografado esconde também os **nomes** das variáveis, o que dificulta buscar (`grep`) onde uma variável é definida e entender o que o projeto usa. A prática recomendada separa em dois arquivos:

`group_vars/db/vault.yml` (criptografado): apenas os valores secretos, com o prefixo `vault_`.

```yaml
---
vault_postgresql_app_senha: "S3nh4-Forte"
vault_postgresql_admin_senha: "Outra-S3nha"
```

`group_vars/db/vars.yml` (texto puro): as variáveis "públicas", que apontam para as secretas.

```yaml
---
postgresql_app_usuario: app
postgresql_app_senha: "{{ vault_postgresql_app_senha }}"
postgresql_admin_senha: "{{ vault_postgresql_admin_senha }}"
```

Vantagens:

- Quem lê o `vars.yml` vê **todas** as variáveis existentes, e basta procurar por `vault_` para saber quais são secretas.
- O `grep` continua funcionando para os nomes.
- As tasks e roles usam apenas os nomes "públicos" (`postgresql_app_senha`), sem saber de onde vêm.
- Trocar a origem do segredo (por exemplo, para um gerenciador externo) exige mudar só o `vars.yml`.

---

## 7. Criptografando variáveis individuais: `encrypt_string`

Em vez de um arquivo inteiro, você pode criptografar **só o valor** de uma variável e mantê-la no meio de um YAML normal.

### 7.1 Gerando o valor criptografado

```bash
ansible-vault encrypt_string 'S3nh4-Forte' --name 'postgresql_app_senha'
```

Saída:

```yaml
postgresql_app_senha: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          36396132336366336334323163653039343663383533343232366266393137636236313133383636
          3363666539636365393831303932663130643831623761340a...
```

A marca `!vault |` informa ao Ansible que o valor é criptografado. Cole o bloco no arquivo de variáveis:

```yaml
---
postgresql_app_usuario: app
postgresql_app_senha: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          36396132336366336334323163653039343663383533343232366266393137636236313133383636
          3363666539636365393831303932663130643831623761340a...
```

### 7.2 Evitando que a senha apareça no histórico do shell

Ao escrever `ansible-vault encrypt_string 'S3nh4-Forte'`, o valor fica gravado no histórico do shell (`history`). Alternativas melhores:

```bash
# Digitando o valor em um prompt (não fica no histórico)
ansible-vault encrypt_string --prompt --name 'postgresql_app_senha'

# Lendo da entrada padrão
ansible-vault encrypt_string --stdin-name 'postgresql_app_senha'
# (digite o valor e finalize com Ctrl+D)
```

### 7.3 Vários valores de uma vez

```bash
ansible-vault encrypt_string 'valor1' --name 'var1' 'valor2' --name 'var2'
```

### 7.4 Quando usar cada abordagem

| | Arquivo inteiro criptografado | Variável individual (`!vault`) |
|---|---|---|
| Visibilidade dos nomes | Escondida (a menos que use o padrão `vault_`) | Os nomes ficam visíveis |
| Diff no Git | Opaco (o arquivo todo muda) | Só o bloco da variável muda |
| Edição | `ansible-vault edit` | Gerar de novo com `encrypt_string` e colar |
| Vários segredos | Muito prático | Trabalhoso |
| Legibilidade do arquivo | Baixa | Boa (mistura texto puro e segredos) |

Para muitos segredos, o arquivo inteiro com o padrão `vault_` costuma ser mais prático. Para poucos valores soltos em um arquivo de variáveis, `encrypt_string` é bem conveniente.

> Cuidado: um valor criptografado com `encrypt_string` **não** pode ser lido com `ansible-vault view arquivo.yml`, porque o arquivo em si não é um arquivo Vault. Para conferir um valor, use `ansible -m debug` (seção 10) ou decifre o bloco: `echo '<bloco>' | ansible-vault decrypt --output -`.

---

## 8. Arquivos e templates criptografados

### 8.1 `copy` com arquivo criptografado

Um arquivo em `files/` (como uma chave privada) pode ser criptografado com `ansible-vault encrypt`. O módulo `copy` o **descriptografa automaticamente** ao enviar ao host:

```bash
ansible-vault encrypt roles/web/files/servidor.key
```

```yaml
- name: Instalar a chave privada
  ansible.builtin.copy:
    src: servidor.key              # criptografado no repositório
    dest: /etc/ssl/private/servidor.key
    owner: root
    group: root
    mode: "0600"
  no_log: true
```

O destino no host fica em **texto puro**, como deve ser para o serviço ler o arquivo, então proteja-o com permissões restritas (`0600`).

### 8.2 `template` com variáveis secretas

Um template pode usar variáveis vindas do Vault, e o resultado é gravado em texto puro no host:

```yaml
- name: Gerar o arquivo de ambiente da aplicação
  ansible.builtin.template:
    src: app.env.j2
    dest: /etc/app/app.env
    owner: app
    group: app
    mode: "0600"
  no_log: true
```

`app.env.j2`:

```
DB_USUARIO={{ postgresql_app_usuario }}
DB_SENHA={{ postgresql_app_senha }}
```

---

## 9. Vault IDs: várias senhas

Em projetos maiores, é comum ter **senhas diferentes** por ambiente (desenvolvimento, produção) ou por tipo de segredo. Os **vault ids** permitem isso.

### 9.1 Criptografando com um id

Sintaxe: `rótulo@fonte`, em que a fonte é `prompt` (digitar) ou o caminho de um arquivo de senha (ou script).

```bash
ansible-vault create --vault-id dev@prompt group_vars/dev/vault.yml
ansible-vault create --vault-id prod@~/.vault_prod group_vars/prod/vault.yml
```

O rótulo fica registrado no cabeçalho do arquivo (`$ANSIBLE_VAULT;1.2;AES256;prod`).

### 9.2 Executando com vários ids

```bash
ansible-playbook -i hosts pg.yml \
  --vault-id dev@~/.vault_dev \
  --vault-id prod@~/.vault_prod
```

O Ansible tenta as senhas fornecidas para descriptografar cada arquivo (começando pela de rótulo correspondente).

### 9.3 Configuração no `ansible.cfg`

```ini
[defaults]
vault_identity_list = dev@~/.vault_dev, prod@~/.vault_prod
```

### 9.4 O rótulo não é uma proteção

O rótulo é apenas uma **dica** de qual senha usar. A segurança vem da senha, não do rótulo. Para evitar que a equipe de desenvolvimento tenha acesso aos segredos de produção, basta **não** entregar a senha de produção a ela.

---

## 10. Não vazar segredos durante a execução

Criptografar os arquivos protege os dados **em repouso**. Durante a execução, os valores existem em texto puro na memória e podem aparecer na saída se você não tomar cuidado.

### 10.1 `no_log: true`

```yaml
- name: Criar o usuário do banco
  community.postgresql.postgresql_user:
    name: "{{ postgresql_app_usuario }}"
    password: "{{ postgresql_app_senha }}"
  become: true
  become_user: postgres
  no_log: true
```

Sem `no_log`, os parâmetros da task (incluindo a senha) podem aparecer na saída com `-v` ou em caso de erro. Aplique `no_log: true` em **toda** task que manipula segredos, ou em um `block` inteiro.

### 10.2 `diff: false`

O `--diff` mostra o conteúdo dos arquivos alterados (inclusive de templates com senhas). Desative-o nas tasks sensíveis:

```yaml
- name: Gerar o arquivo de ambiente
  ansible.builtin.template:
    src: app.env.j2
    dest: /etc/app/app.env
    mode: "0600"
  no_log: true
  diff: false
```

### 10.3 O módulo `debug` e a verbosidade

- Nunca use `debug` para mostrar variáveis secretas fora de testes.
- `-v`, `-vv`, `-vvv` aumentam o detalhe da saída; em tasks sem `no_log`, isso pode revelar valores.
- Logs de CI/CD guardam tudo o que for impresso, então o cuidado se estende a eles.

Para **conferir** um valor localmente, durante o desenvolvimento:

```bash
ansible db -i hosts -m ansible.builtin.debug -a "var=postgresql_app_senha" --ask-vault-pass
```

(Faça isso apenas em terminal seguro, e apague da tela e do histórico se necessário.)

### 10.4 Cache de facts e `set_fact`

`set_fact` com `cacheable: true` e o cache de facts gravam valores em **texto puro** em disco. Não coloque segredos em facts cacheáveis.

### 10.5 Argument specs de roles

Em roles com `meta/argument_specs.yml`, marque as opções sensíveis com `no_log: true`, para que os valores não sejam impressos em erros de validação:

```yaml
options:
  postgresql_app_senha:
    type: str
    no_log: true
    description: Senha do usuário da aplicação.
```

---

## 11. Vault e Git

### 11.1 O que versionar e o que não versionar

| Item | Versionar? |
|---|---|
| Arquivos criptografados (`vault.yml`) | **Sim** |
| Arquivos de variáveis comuns (`vars.yml`) | Sim |
| Arquivo de senha (`.vault_pass`) | **Nunca** |
| Arquivo descriptografado por engano | **Nunca** |
| Script que apenas lê a senha de um gerenciador | Sim (sem a senha dentro) |

`.gitignore`:

```
.vault_pass
.vault_*
*.decrypted
```

### 11.2 Evitando commits de arquivos em texto puro

Um erro comum é rodar `ansible-vault decrypt`, esquecer e fazer o commit. Uma proteção simples é um *hook* de `pre-commit` que verifica se os arquivos `vault.yml` começam com o cabeçalho `$ANSIBLE_VAULT`. Ferramentas como `pre-commit` e o `ansible-lint` ajudam a automatizar isso.

### 11.3 Diferenças legíveis no Git

Por padrão, o `git diff` de um arquivo criptografado é ilegível. Dá para configurar o Git para comparar o conteúdo **descriptografado**:

`.gitattributes`:

```
group_vars/**/vault.yml diff=ansible-vault merge=binary
```

Configuração do Git:

```bash
git config diff.ansible-vault.textconv "ansible-vault view"
```

Com a senha do Vault configurada (por exemplo, `vault_password_file` no `ansible.cfg`), o `git diff` passa a mostrar as mudanças em texto puro, **somente na sua máquina**.

### 11.4 Conflitos de merge

Dois branches que alteram o mesmo arquivo criptografado geram conflito impossível de resolver manualmente (o conteúdo é binário na prática). Resolva abrindo cada versão com `ansible-vault view`, reconciliando o texto e recriptografando.

---

## 12. Vault em roles

- **Não guarde segredos em `defaults/` nem em `vars/` da role.** Uma role compartilhada não deve carregar senhas.
- A role declara em `defaults/` (ou no README) **quais** variáveis espera, sem valor secreto, e quem usa a role fornece o valor vindo do Vault.
- Use o padrão `vault_` no projeto que usa a role, mapeando para as variáveis da role:

```yaml
# group_vars/db/vars.yml
postgresql_remote_app_senha: "{{ vault_postgresql_app_senha }}"
```

- Marque as opções sensíveis com `no_log: true` no `argument_specs.yml` (seção 10.5) e use `no_log: true` nas tasks da role que usam esses valores.
- Para testar a role com o Molecule, use senhas **fictícias** de teste, nunca as reais.

---

## 13. Vault em CI/CD

Em pipelines, não há ninguém para digitar a senha. As abordagens comuns:

### 13.1 Variável secreta do pipeline gravada em arquivo

```bash
echo "$ANSIBLE_VAULT_PASS" > .vault_pass
chmod 600 .vault_pass
ansible-playbook -i hosts pg.yml --vault-password-file .vault_pass
rm -f .vault_pass
```

`ANSIBLE_VAULT_PASS` é uma variável **secreta e mascarada** do GitLab CI, GitHub Actions ou Jenkins (nunca uma variável comum).

### 13.2 Script que lê a variável de ambiente

```bash
#!/bin/sh
echo "$ANSIBLE_VAULT_PASS"
```

```bash
ansible-playbook -i hosts pg.yml --vault-password-file ./vault-pass.sh
```

Assim, nenhuma senha é gravada em arquivo.

### 13.3 Script que consulta um gerenciador de segredos

O script pode buscar a senha do Vault em um serviço externo (um cofre corporativo, o gerenciador de segredos da nuvem, etc.) e imprimi-la, mantendo o controle de acesso e a auditoria fora do Ansible.

### 13.4 AWX e Ansible Automation Platform

Essas plataformas têm um tipo de credencial próprio para o **Vault**, que guarda a senha de forma segura e a entrega ao job.

### 13.5 Cuidados

- Mascare a variável nos logs do pipeline.
- Use `no_log: true` nas tasks sensíveis.
- Não execute o pipeline com `-vvv` em jobs que usam segredos.
- Restrinja quem pode executar ou editar o pipeline.

---

## 14. Rotação: `rekey` não basta

Trocar a senha do Vault (`rekey`) **não** troca os segredos que estavam protegidos. Considere:

| Situação | O que fazer |
|---|---|
| A **senha do Vault** foi exposta, ou alguém que a conhecia saiu da equipe | `rekey` de todos os arquivos **e** troca dos segredos em si (senhas de bancos, tokens, chaves) |
| Um **segredo** foi exposto | Trocar o segredo no sistema de origem e atualizar o `vault.yml` |
| Arquivos já estavam no Git com a senha antiga | O **histórico** do Git continua decifrável com a senha antiga; por isso, trocar os segredos é indispensável |

Em resumo: se a senha do Vault vazou, **assuma que todos os segredos protegidos por ela também vazaram**, e troque-os.

Para trocar a senha de vários arquivos de uma vez:

```bash
ansible-vault rekey --vault-password-file ~/.vault_antiga \
                    --new-vault-password-file ~/.vault_nova \
                    $(grep -rl 'ANSIBLE_VAULT' group_vars host_vars)
```

Atenção: o `rekey` só funciona em arquivos que são Vault por inteiro. Arquivos com variáveis `!vault` **inline** também contêm o texto `ANSIBLE_VAULT`, mas não podem ser tratados assim; para eles, gere os valores novamente com `encrypt_string` usando a nova senha. Confira a lista de arquivos antes de executar o comando.

---

## 15. Exemplo completo

Projeto que usa o Vault para configurar o usuário da aplicação no PostgreSQL e gerar o arquivo de ambiente, em Debian e Red Hat.

### 15.1 Estrutura

```
ansible/
├── ansible.cfg
├── hosts
├── .gitignore
├── .vault_pass                    # NÃO versionado
├── pg.yml
└── group_vars/
    └── db/
        ├── vars.yml               # texto puro
        └── vault.yml              # criptografado
```

### 15.2 `ansible.cfg`

```ini
[defaults]
inventory = ./hosts
vault_password_file = ~/.vault_pass
```

### 15.3 `.gitignore`

```
.vault_pass
```

### 15.4 Criando os arquivos

```bash
# Senha do Vault, com permissão restrita
echo 'SenhaDoVault-Forte' > ~/.vault_pass
chmod 600 ~/.vault_pass

# Arquivo com os segredos
ansible-vault create group_vars/db/vault.yml
```

Conteúdo digitado no editor:

```yaml
---
vault_postgresql_app_senha: "S3nh4-Forte"
```

`group_vars/db/vars.yml`:

```yaml
---
postgresql_app_usuario: app
postgresql_app_banco: appdb
postgresql_app_senha: "{{ vault_postgresql_app_senha }}"
```

### 15.5 `pg.yml`

```yaml
---
- name: Configurar o acesso da aplicação ao PostgreSQL
  hosts: db
  gather_facts: true
  become: true

  tasks:
    - name: Criar o usuário da aplicação no PostgreSQL
      community.postgresql.postgresql_user:
        name: "{{ postgresql_app_usuario }}"
        password: "{{ postgresql_app_senha }}"
        state: present
      become_user: postgres
      no_log: true
      tags: usuario

    - name: Garantir o diretório de configuração da aplicação
      ansible.builtin.file:
        path: /etc/app
        state: directory
        mode: "0750"
      tags: arquivos

    - name: Gerar o arquivo de ambiente com a senha
      ansible.builtin.copy:
        dest: /etc/app/app.env
        content: |
          DB_USUARIO={{ postgresql_app_usuario }}
          DB_BANCO={{ postgresql_app_banco }}
          DB_SENHA={{ postgresql_app_senha }}
        owner: root
        group: root
        mode: "0600"
      no_log: true
      diff: false
      tags: arquivos
```

O módulo `community.postgresql.postgresql_user` exige a coleção `community.postgresql` e a biblioteca `psycopg2` no host. Se você usar `become_user: postgres`, o Ansible pode pedir o pacote `acl` (ou o uso de *pipelining*) para criar arquivos temporários como o usuário sem privilégios.

### 15.6 Execução

```bash
# Com vault_password_file configurado no ansible.cfg
ansible-playbook pg.yml -K

# Pedindo a senha do Vault
ansible-playbook pg.yml -K --ask-vault-pass

# Informando o arquivo de senha explicitamente
ansible-playbook pg.yml -K --vault-password-file ~/.vault_pass

# Apenas o arquivo de ambiente
ansible-playbook pg.yml -K --tags arquivos --limit deb00,deb02

# Simulação
ansible-playbook pg.yml -K --check
```

### 15.7 Manutenção dos segredos

```bash
ansible-vault view   group_vars/db/vault.yml
ansible-vault edit   group_vars/db/vault.yml
ansible-vault rekey  group_vars/db/vault.yml
```

---

## 16. O que o Vault não faz: alternativas e complementos

O Vault protege **arquivos em repouso** com uma senha compartilhada. Ele não oferece:

- controle de acesso **por segredo ou por usuário** (quem tem a senha vê tudo);
- **auditoria** de quem leu qual segredo;
- **rotação** automática;
- **segredos dinâmicos** (credenciais temporárias geradas sob demanda).

Para esses casos, integre o Ansible a um gerenciador de segredos, usando lookups e coleções:

| Solução | Como integrar |
|---|---|
| HashiCorp Vault | Coleção `community.hashi_vault` (lookup `hashi_vault`) |
| Gerenciadores de segredos de nuvem | Lookups das coleções da respectiva nuvem |
| Gerenciadores de senhas corporativos | Lookups ou coleções específicas |
| SOPS | Criptografia de arquivos com chaves de KMS ou PGP, integrável ao Ansible |

Um uso combinado muito comum: manter no **Ansible Vault** apenas a credencial de acesso ao gerenciador externo, e buscar os demais segredos de lá em tempo de execução.

---

## 17. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Erro dizendo que há dados criptografados e **nenhuma senha** foi fornecida | Faltou a senha do Vault | `--ask-vault-pass`, `--vault-password-file` ou configurar no `ansible.cfg` |
| `Decryption failed` | Senha incorreta, ou arquivo criptografado com outra senha ou id | Conferir a senha; usar `--vault-id` correspondente |
| Erro de YAML ao colar `encrypt_string` | Indentação do bloco `!vault |` errada | Manter a indentação gerada pelo comando |
| `ansible-vault view` falha em um arquivo com `!vault` | O arquivo não é um Vault completo | Usar `encrypt_string`/`decrypt` no bloco |
| Variável do Vault aparece vazia ou indefinida | O arquivo não está em `group_vars` do grupo certo, ou o nome mudou | Verificar o caminho e o nome com `ansible-inventory --host` |
| Senha aparece na saída | Falta `no_log: true` | Aplicar `no_log: true` e `diff: false` |
| Prompt "Vault password" a cada execução | Sem arquivo de senha configurado | `vault_password_file` no `ansible.cfg` |
| Playbook falha em CI com pedido de senha | Pipeline sem a senha | Variável secreta e `--vault-password-file` |
| Arquivo de senha com quebra de linha extra | Senha com caracteres além do texto | Gravar com `echo` ou `printf` simples e conferir |
| `Vault password file ... is not executable/readable` ou semelhante | Permissões inadequadas | Ajustar as permissões do arquivo ou script |
| Conflito de merge em `vault.yml` | Duas alterações no mesmo arquivo | Resolver via `view` das duas versões e recriptografar |
| `decrypt` deixou segredos em texto puro no Git | Commit de arquivo descriptografado | Recriptografar, **trocar os segredos** e limpar o histórico |
| Editor errado ao usar `create` ou `edit` | Variável `EDITOR` | `EDITOR=nano ansible-vault edit ...` |
| `--limit` ou tags não alteram a necessidade de senha | O Ansible carrega as variáveis do grupo antes de filtrar | Fornecer a senha mesmo assim |

---

## 18. Boas práticas

1. **Nunca versione senhas em texto puro**, nem o arquivo da senha do Vault.
2. **Use o padrão `vault_`:** segredos em `vault.yml`, variáveis públicas em `vars.yml` apontando para eles.
3. **Prefira `edit` e `view`** a `decrypt` e `encrypt`: nunca deixam o arquivo descriptografado no disco.
4. **Use `no_log: true` e `diff: false`** em toda task que manipula segredos.
5. **Use `encrypt_string --prompt`** (ou `--stdin-name`) para não deixar a senha no histórico do shell.
6. **Use senhas de Vault diferentes por ambiente** (vault ids), e entregue a de produção apenas a quem precisa.
7. **Proteja o arquivo de senha** (`chmod 600`, fora do repositório) ou use um script que consulte um gerenciador de segredos.
8. **Em CI/CD**, use variáveis secretas e mascaradas, e evite `-vvv`.
9. **Gere senhas fortes e únicas** para cada serviço; o Vault protege o armazenamento, mas não corrige uma senha fraca.
10. **Planeje a rotação:** se a senha do Vault vazar, `rekey` e troque também os segredos.
11. **Não coloque segredos em roles compartilhadas;** receba-os como parâmetros.
12. **Configure o `git diff`** para mostrar o conteúdo descriptografado localmente (`textconv`).
13. **Automatize verificações** (hook de `pre-commit`, `ansible-lint`) para impedir commits de arquivos em texto puro.
14. **Considere um gerenciador de segredos** quando precisar de auditoria, controle fino de acesso ou rotação automática.
15. **Teste com valores fictícios** (Molecule, ambientes de desenvolvimento), nunca com segredos de produção.

---

## Resumo

| Necessidade | Comando ou recurso |
|---|---|
| Criar um arquivo criptografado | `ansible-vault create arquivo` |
| Criptografar um arquivo existente | `ansible-vault encrypt arquivo` |
| Ler sem alterar | `ansible-vault view arquivo` |
| Editar | `ansible-vault edit arquivo` |
| Remover a criptografia | `ansible-vault decrypt arquivo` |
| Trocar a senha do Vault | `ansible-vault rekey arquivo` |
| Criptografar uma variável | `ansible-vault encrypt_string --name var` |
| Evitar a senha no histórico | `encrypt_string --prompt` ou `--stdin-name` |
| Informar a senha na execução | `--ask-vault-pass` |
| Informar a senha por arquivo | `--vault-password-file` |
| Senha padrão do projeto | `vault_password_file` no `ansible.cfg` |
| Senha por script | Arquivo executável que imprime a senha |
| Senhas por ambiente | `--vault-id rótulo@fonte` |
| Organizar os segredos | Padrão `vault_` com `vars.yml` + `vault.yml` |
| Usar arquivo criptografado | `group_vars`, `host_vars`, `vars_files`, `include_vars`, `-e @arquivo` |
| Arquivo criptografado em `copy` | Descriptografado automaticamente no envio |
| Não vazar na saída | `no_log: true` e `diff: false` |
| Diferenças legíveis no Git | `.gitattributes` + `textconv` |
| Mais controle e auditoria | Gerenciador de segredos externo |
