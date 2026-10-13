# Configuração do Ansible com `ansible.cfg`

O arquivo `ansible.cfg` é o principal arquivo de configuração do Ansible.

Ele permite alterar o comportamento padrão do Ansible sem precisar informar
as mesmas opções em todos os comandos ou Playbooks.

Entre outras coisas, o `ansible.cfg` pode definir:

- o arquivo ou diretório de inventário;
- o usuário utilizado nas conexões remotas;
- a quantidade de conexões paralelas;
- o tempo limite das conexões;
- o método de elevação de privilégios;
- opções de SSH;
- caminhos de Roles e Collections;
- comportamento de plugins;
- diretórios temporários;
- opções de logging.

O arquivo utiliza um formato semelhante ao **INI**, dividido em seções.

Exemplo:

```ini
[defaults]
inventory = ./inventory
remote_user = ansible
forks = 20
timeout = 30

[privilege_escalation]
become = True
become_method = sudo

[ssh_connection]
pipelining = True
```

---

## 1. Onde o Ansible procura o `ansible.cfg`

O Ansible procura o arquivo de configuração na seguinte ordem:

```text
1. $ANSIBLE_CONFIG
2. ./ansible.cfg
3. ~/.ansible.cfg
4. /etc/ansible/ansible.cfg
```

Em outras palavras:

```text
Maior prioridade
       |
       v

$ANSIBLE_CONFIG
       |
       v
./ansible.cfg
       |
       v
~/.ansible.cfg
       |
       v
/etc/ansible/ansible.cfg

       |
       v
Menor prioridade
```

É importante entender que o Ansible **não combina esses arquivos**.

Ele percorre a lista e utiliza **o primeiro arquivo encontrado**.

Os demais são ignorados.

Por exemplo, se existirem:

```text
./ansible.cfg
~/.ansible.cfg
/etc/ansible/ansible.cfg
```

o Ansible utilizará:

```text
./ansible.cfg
```

Os outros dois arquivos não serão carregados.

---

## 2. `$ANSIBLE_CONFIG`

A variável de ambiente `ANSIBLE_CONFIG` possui a maior prioridade na busca
pelo arquivo de configuração.

Exemplo:

```bash
export ANSIBLE_CONFIG=/opt/ansible/producao.cfg
```

A partir desse momento, os comandos Ansible executados naquele ambiente
utilizarão:

```text
/opt/ansible/producao.cfg
```

É possível verificar:

```bash
echo $ANSIBLE_CONFIG
```

Exemplo de saída:

```text
/opt/ansible/producao.cfg
```

Uma utilização interessante é manter arquivos diferentes para ambientes
distintos.

Exemplo:

```text
/etc/ansible/config/
├── development.cfg
├── homologation.cfg
└── production.cfg
```

Para utilizar produção:

```bash
export ANSIBLE_CONFIG=/etc/ansible/config/production.cfg
```

Também é possível definir a variável apenas para um comando:

```bash
ANSIBLE_CONFIG=./production.cfg ansible-playbook site.yml
```

Nesse caso, a configuração é utilizada somente naquela execução.

---

## 3. `./ansible.cfg`

O próximo local pesquisado é o diretório atual:

```text
./ansible.cfg
```

Essa é uma abordagem bastante interessante para projetos Ansible.

Exemplo:

```text
project/
├── ansible.cfg
├── inventory/
│   ├── production.yml
│   └── development.yml
├── group_vars/
├── roles/
└── site.yml
```

O arquivo pode conter:

```ini
[defaults]
inventory = ./inventory/production.yml
roles_path = ./roles
forks = 20
```

Ao entrar no diretório:

```bash
cd project
```

e executar:

```bash
ansible-playbook site.yml
```

o Ansible encontrará automaticamente:

```text
./ansible.cfg
```

Essa abordagem facilita manter determinadas configurações junto ao projeto.

> **Atenção:** por segurança, o Ansible não carrega automaticamente
> `./ansible.cfg` quando o diretório atual é gravável por qualquer usuário
> (*world-writable*). Isso evita que outro usuário coloque um arquivo de
> configuração malicioso no diretório.

---

## 4. `~/.ansible.cfg`

Se não encontrar os arquivos anteriores, o Ansible procura:

```text
~/.ansible.cfg
```

Esse arquivo contém configurações específicas do usuário.

Exemplo:

```text
/home/aluno/.ansible.cfg
```

Um exemplo simples:

```ini
[defaults]
remote_user = aluno
forks = 10
timeout = 20
```

Essa configuração será utilizada para aquele usuário, desde que não exista
um arquivo de maior prioridade.

---

## 5. `/etc/ansible/ansible.cfg`

Se nenhum dos arquivos anteriores for encontrado, o Ansible procura:

```text
/etc/ansible/ansible.cfg
```

Esse é o local tradicional para uma configuração global do sistema.

Exemplo:

```ini
[defaults]
inventory = /etc/ansible/hosts
forks = 10
timeout = 30
```

Como é uma configuração de sistema, normalmente sua alteração exige
privilégios administrativos.

---

## 6. Verificando qual arquivo está sendo utilizado

Uma maneira simples é executar:

```bash
ansible --version
```

Exemplo de saída:

```text
ansible [core ...]
  config file = /home/aluno/projeto/ansible.cfg
  ...
```

A linha:

```text
config file =
```

indica qual arquivo foi carregado.

Se nenhum arquivo de configuração estiver sendo utilizado, o Ansible pode
mostrar:

```text
config file = None
```

Nesse caso, os valores padrão internos e outras fontes de configuração
continuam válidos.

---

## 7. Estrutura do `ansible.cfg`

O `ansible.cfg` usa um formato baseado em INI.

Uma seção é identificada por:

```ini
[nome_da_secao]
```

e os parâmetros aparecem no formato:

```ini
opcao = valor
```

Exemplo:

```ini
[defaults]
inventory = ./inventory
forks = 20
timeout = 30
```

Entre as seções mais comuns estão:

```text
[defaults]
[privilege_escalation]
[ssh_connection]
[persistent_connection]
[inventory]
```

As opções disponíveis podem variar de acordo com a versão do Ansible e com
os plugins instalados.

Por isso, em vez de copiar cegamente arquivos de configuração encontrados
na Internet, é melhor consultar a instalação local com:

```bash
ansible-config
```

---

## 8. Seção `[defaults]`

A seção `[defaults]` concentra várias das configurações gerais do Ansible.

Exemplo:

```ini
[defaults]
inventory = ./inventory
remote_user = ansible
forks = 20
timeout = 30
roles_path = ./roles
```

### `inventory`

Define o inventário padrão:

```ini
[defaults]
inventory = ./inventory
```

Assim, em vez de executar:

```bash
ansible all -i inventory -m ansible.builtin.ping
```

pode-se executar:

```bash
ansible all -m ansible.builtin.ping
```

O Ansible utilizará o inventário configurado.

### `remote_user`

Define o usuário remoto padrão:

```ini
[defaults]
remote_user = ansible
```

### `forks`

Controla quantos hosts o Ansible pode processar em paralelo.

```ini
[defaults]
forks = 20
```

Aumentar `forks` pode melhorar o desempenho em ambientes maiores, mas também
pode aumentar o consumo de recursos no Control Node e a quantidade de
conexões simultâneas.

### `timeout`

Define o tempo limite padrão utilizado em determinadas conexões.

```ini
[defaults]
timeout = 30
```

### `roles_path`

Define os diretórios onde o Ansible procura Roles.

```ini
[defaults]
roles_path = ./roles:/opt/ansible/roles
```

---

## 9. Seção `[privilege_escalation]`

Essa seção controla o mecanismo de elevação de privilégios, conhecido no
Ansible como **become**.

Exemplo:

```ini
[privilege_escalation]
become = True
become_method = sudo
become_user = root
```

Com essa configuração, o Ansible pode utilizar `sudo` para executar tarefas
com privilégios do usuário `root`.

Entretanto, habilitar `become` globalmente deve ser uma decisão consciente,
pois nem toda automação precisa de privilégios administrativos.

---

## 10. Seção `[ssh_connection]`

Essa seção contém configurações relacionadas à conexão SSH.

Exemplo:

```ini
[ssh_connection]
pipelining = True
```

O `pipelining` pode reduzir a quantidade de operações realizadas durante a
execução de módulos e melhorar o desempenho em determinadas situações.

Antes de habilitá-lo em produção, verifique a compatibilidade com a política
de `sudo`, com o método de conexão e com a versão utilizada.

---

## 11. Um exemplo de `ansible.cfg`

Considere um projeto com a seguinte estrutura:

```text
ansible-lab/
├── ansible.cfg
├── inventory/
│   └── hosts.yml
├── roles/
└── site.yml
```

O arquivo `ansible.cfg` poderia ser:

```ini
[defaults]
inventory = ./inventory/hosts.yml
remote_user = ansible
forks = 20
timeout = 30
roles_path = ./roles

[privilege_escalation]
become = True
become_method = sudo
become_user = root

[ssh_connection]
pipelining = True
```

Agora:

```bash
ansible all -m ansible.builtin.ping
```

já utilizará o inventário configurado, e:

```bash
ansible-playbook site.yml
```

utilizará as demais opções definidas no arquivo.

---

## 12. Comentários no `ansible.cfg`

Comentários em linhas separadas podem utilizar `#` ou `;`.

Exemplo:

```ini
[defaults]

# Inventário do projeto
inventory = ./inventory

; Número de processos paralelos
forks = 20
```

Para comentários colocados na mesma linha de um valor, use `;`.

Exemplo:

```ini
inventory = ./inventory  ; inventário do projeto
```

---

## 13. Caminhos relativos

Muitas opções do `ansible.cfg` aceitam caminhos relativos.

Exemplo:

```ini
[defaults]
inventory = ./inventory
roles_path = ./roles
```

Em muitas configurações, caminhos relativos são resolvidos tomando como
referência o diretório do arquivo de configuração carregado.

Isso torna prática uma estrutura como:

```text
project/
├── ansible.cfg
├── inventory/
├── roles/
└── playbooks/
```

---

# 14. O utilitário `ansible-config`

O comando:

```bash
ansible-config
```

é a principal ferramenta para consultar e analisar a configuração do
Ansible.

Sua vantagem é mostrar as opções reconhecidas pela **versão realmente
instalada** no sistema.

Entre seus principais subcomandos estão:

```text
ansible-config list
ansible-config dump
ansible-config view
ansible-config init
ansible-config validate
```

O conjunto exato de opções pode variar conforme a versão.

Consulte:

```bash
ansible-config --help
```

---

## 15. `ansible-config list`

O comando:

```bash
ansible-config list
```

lista as configurações conhecidas pelo Ansible.

A saída pode apresentar informações como:

- descrição da configuração;
- valor padrão;
- seção do arquivo INI;
- nome da opção;
- variável de ambiente correspondente;
- tipo do valor.

Como a saída é extensa:

```bash
ansible-config list | less
```

Ou, para procurar algo específico:

```bash
ansible-config list | grep -i forks
```

---

## 16. `ansible-config dump`

O comando:

```bash
ansible-config dump
```

mostra os valores efetivos das configurações.

Exemplo de saída:

```text
DEFAULT_FORKS(default) = 5
DEFAULT_TIMEOUT(default) = 10
```

Um dos comandos mais úteis para troubleshooting é:

```bash
ansible-config dump --only-changed
```

Ele mostra somente configurações cujo valor difere do padrão.

Para consultar algo específico:

```bash
ansible-config dump | grep DEFAULT_FORKS
```

Uma saída pode indicar também a origem do valor, por exemplo:

```text
DEFAULT_FORKS(/home/aluno/projeto/ansible.cfg) = 20
```

Assim é possível descobrir não apenas o valor, mas também de onde ele veio.

---

## 17. `ansible-config view`

O comando:

```bash
ansible-config view
```

exibe o conteúdo do arquivo de configuração selecionado.

Isso é diferente de:

```bash
ansible-config dump
```

A diferença básica é:

```text
ansible-config view
    Mostra o conteúdo do ansible.cfg selecionado.

ansible-config dump
    Mostra os valores efetivos reconhecidos pelo Ansible.
```

---

## 18. `ansible-config init`

O `ansible-config init` pode gerar um arquivo inicial de configuração.

Exemplo:

```bash
ansible-config init --disabled > ansible.cfg
```

A opção `--disabled` faz com que as configurações geradas apareçam
comentadas.

Isso permite utilizar o arquivo como referência e habilitar apenas as opções
necessárias.

Para incluir também configurações associadas aos plugins disponíveis:

```bash
ansible-config init --disabled -t all > ansible.cfg
```

Esse método é preferível a copiar um `ansible.cfg` antigo da Internet, pois
a saída corresponde à instalação local.

---

## 19. `ansible-config validate`

Versões atuais do `ansible-core` oferecem o subcomando:

```bash
ansible-config validate
```

Ele pode ser utilizado para validar a configuração.

Como funcionalidades podem mudar entre versões, confirme sua disponibilidade:

```bash
ansible-config --help
```

---

## 20. Informando explicitamente outro arquivo ao `ansible-config`

Alguns subcomandos aceitam:

```text
-c
```

ou:

```text
--config
```

Exemplo:

```bash
ansible-config dump -c ./production.cfg
```

Outro exemplo:

```bash
ansible-config view -c ./production.cfg
```

Isso é útil para analisar um arquivo sem alterar permanentemente a variável
`ANSIBLE_CONFIG`.

---

# 21. `ansible-config` no troubleshooting

Imagine que o administrador configurou:

```ini
[defaults]
forks = 30
```

mas não sabe se esse arquivo realmente está sendo utilizado.

Primeiro:

```bash
ansible --version
```

Verifique a linha:

```text
config file =
```

Depois:

```bash
ansible-config dump | grep DEFAULT_FORKS
```

E finalmente:

```bash
ansible-config dump --only-changed
```

Esse fluxo ajuda a responder:

```text
Qual arquivo foi carregado?
        |
        v
Qual é o valor efetivo?
        |
        v
Esse valor foi alterado?
        |
        v
De onde veio a configuração?
```

---

# 22. Arquivo de configuração x variável de ambiente

É importante não confundir duas situações.

## Selecionar o arquivo de configuração

A variável:

```bash
ANSIBLE_CONFIG
```

escolhe qual arquivo de configuração utilizar.

Exemplo:

```bash
export ANSIBLE_CONFIG=./production.cfg
```

## Alterar uma opção específica

Muitas opções do Ansible também possuem sua própria variável de ambiente.

Quando uma variável de ambiente correspondente a uma configuração está
definida, ela pode sobrescrever o valor encontrado no `ansible.cfg`.

Por isso, `ANSIBLE_CONFIG` não deve ser entendido como a única variável de
ambiente relacionada à configuração do Ansible.

---

# 23. Prioridade entre diferentes fontes de configuração

A ordem:

```text
$ANSIBLE_CONFIG
./ansible.cfg
~/.ansible.cfg
/etc/ansible/ansible.cfg
```

responde apenas à pergunta:

> **Qual arquivo `ansible.cfg` será carregado?**

Ela não representa toda a precedência existente no Ansible.

Depois que o arquivo é escolhido, outras fontes podem possuir prioridade
maior para determinadas opções.

De forma simplificada:

```text
ansible.cfg
      |
      v
Environment variables
      |
      v
Command-line options
```

Além dessas fontes, o Ansible possui regras de precedência envolvendo
Playbook keywords, variables e direct assignment.

Portanto, existem dois conceitos diferentes:

```text
1. Prioridade para localizar ansible.cfg

   $ANSIBLE_CONFIG
       >
   ./ansible.cfg
       >
   ~/.ansible.cfg
       >
   /etc/ansible/ansible.cfg

2. Precedência de configurações do Ansible

   Define qual valor prevalece quando a mesma característica
   pode ser configurada por fontes diferentes.
```

Essa distinção é muito importante durante troubleshooting.

---

# 24. Boa prática: configuração por projeto

Para muitos ambientes, uma boa estrutura é manter um `ansible.cfg`
específico dentro do projeto:

```text
ansible-project/
├── ansible.cfg
├── inventory/
│   ├── development.yml
│   └── production.yml
├── group_vars/
├── host_vars/
├── roles/
└── playbooks/
```

Exemplo:

```ini
[defaults]
inventory = ./inventory/production.yml
roles_path = ./roles
forks = 20
timeout = 30
```

Essa abordagem traz benefícios como:

- configuração próxima ao código;
- maior previsibilidade;
- facilidade para reproduzir o ambiente;
- possibilidade de versionamento;
- menor dependência da configuração global do Control Node.

Evite armazenar segredos diretamente no `ansible.cfg`.

Senhas, tokens e outros dados sensíveis devem utilizar mecanismos apropriados,
como o **Ansible Vault** ou um sistema externo de gerenciamento de segredos.

---

# 25. Boa prática: altere somente o necessário

Um arquivo `ansible.cfg` não precisa conter todas as opções existentes.

Um arquivo pequeno pode ser suficiente:

```ini
[defaults]
inventory = ./inventory
forks = 20

[ssh_connection]
pipelining = True
```

Isso tende a ser mais fácil de entender, revisar, manter e diagnosticar.

Para consultar valores que não foram explicitamente definidos:

```bash
ansible-config dump
```

---

# 26. Exercício rápido

Crie um diretório:

```bash
mkdir -p ~/ansible-config-lab
cd ~/ansible-config-lab
```

Crie o arquivo:

```bash
vi ansible.cfg
```

Com:

```ini
[defaults]
forks = 25
timeout = 40
```

Verifique qual arquivo está ativo:

```bash
ansible --version
```

Depois:

```bash
ansible-config dump --only-changed
```

Consulte especificamente:

```bash
ansible-config dump | grep -E 'DEFAULT_FORKS|DEFAULT_TIMEOUT'
```

Agora gere uma configuração de referência:

```bash
ansible-config init --disabled > ansible.cfg.example
```

Por fim, crie outro arquivo:

```bash
cp ansible.cfg production.cfg
```

Altere o novo arquivo:

```ini
[defaults]
forks = 50
timeout = 60
```

Teste-o sem substituir o arquivo principal:

```bash
ansible-config dump -c ./production.cfg \
  | grep -E 'DEFAULT_FORKS|DEFAULT_TIMEOUT'
```

Esse laboratório demonstra:

- localização do `ansible.cfg`;
- valores efetivos;
- origem das configurações;
- geração de um arquivo de referência;
- seleção explícita de outro arquivo.

---

# 27. Resumo

A regra principal para localizar o arquivo pode ser memorizada assim:

```text
$ANSIBLE_CONFIG
       |
       | se não existir
       v
./ansible.cfg
       |
       | se não existir
       v
~/.ansible.cfg
       |
       | se não existir
       v
/etc/ansible/ansible.cfg
```

O Ansible para no **primeiro arquivo encontrado**.

Os arquivos não são mesclados.

Para investigar a configuração, lembre-se principalmente destes comandos:

```bash
ansible --version
ansible-config list
ansible-config dump
ansible-config dump --only-changed
ansible-config view
ansible-config init --disabled
```

---

# Referências

- Ansible Community Documentation — Ansible Configuration Settings:
  <https://docs.ansible.com/projects/ansible/latest/reference_appendices/config.html>
- Ansible Community Documentation — Configuring Ansible:
  <https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_configuration.html>
- Ansible Community Documentation — `ansible-config`:
  <https://docs.ansible.com/projects/ansible/latest/cli/ansible-config.html>
- Ansible Community Documentation — Precedence Rules:
  <https://docs.ansible.com/projects/ansible/latest/reference_appendices/general_precedence.html>
