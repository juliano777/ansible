# Arquivos de Inventário no Ansible

O **inventário** (*inventory*) é a fonte utilizada pelo Ansible para saber
**quais hosts serão administrados** e como esses hosts estão organizados.

Um inventário pode conter:

- endereços IP;
- nomes de hosts;
- FQDNs;
- grupos de hosts;
- grupos filhos;
- variáveis de hosts;
- variáveis de grupos;
- parâmetros de conexão;
- informações sobre ambientes;
- informações obtidas dinamicamente de outras plataformas.

Em um ambiente pequeno, o inventário pode ser apenas um arquivo contendo
alguns servidores.

Exemplo:

```ini
192.168.56.10

[rh]
192.168.56.20
```

Em ambientes maiores, ele pode representar centenas ou milhares de hosts,
organizados por função, localização, sistema operacional, ambiente ou
qualquer outro critério relevante.

---

# 1. Por que o inventário é importante?

Sem um inventário, o Ansible não sabe quais máquinas fazem parte da
infraestrutura que será administrada.

Considere:

```bash
ansible all -m ansible.builtin.ping
```

A palavra:

```text
all
```

não significa "todas as máquinas da rede".

Ela significa:

> todos os hosts conhecidos pelo inventário carregado pelo Ansible.

O inventário, portanto, funciona como uma representação dos sistemas que o
Control Node pode administrar.

Conceitualmente:

```text
Inventory
   |
   | hosts
   | groups
   | variables
   | connection information
   v
Ansible
   |
   v
Managed Nodes
```

---

# 2. Inventário padrão

Historicamente, um dos caminhos tradicionais de inventário é:

```text
/etc/ansible/hosts
```

Entretanto, projetos Ansible normalmente utilizam um inventário próprio.

Exemplo:

```text
ansible-project/
├── ansible.cfg
├── hosts
├── group_vars/
├── host_vars/
└── site.yml
```

O inventário pode ser informado na linha de comando:

```bash
ansible all -i hosts -m ansible.builtin.ping
```

ou:

```bash
ansible-playbook -i hosts site.yml
```

Também pode ser configurado no `ansible.cfg`:

```ini
[defaults]
inventory = ./hosts
```

Com isso, não é necessário informar `-i` em todos os comandos.

Exemplo:

```bash
ansible all -m ansible.builtin.ping
```

---

# 3. Formatos de inventário

Os dois formatos mais comuns para inventários estáticos são:

- INI;
- YAML.

Exemplo INI:

```ini
[webservers]
web01.example.com
web02.example.com
```

Exemplo YAML:

```yaml
---
all:
  children:
    webservers:
      hosts:
        web01.example.com:
        web02.example.com:
...
```

Os dois representam essencialmente a mesma informação.

O formato INI costuma ser mais simples para inventários pequenos.

O formato YAML tende a ficar mais organizado quando existem:

- muitos grupos;
- grupos filhos;
- várias variáveis;
- estruturas mais complexas.

---

# 4. Hosts no inventário

Um host pode ser informado de diferentes formas.

## 4.1 Endereço IP

```ini
192.168.56.10
192.168.56.20
```

O Ansible tentará conectar diretamente aos endereços informados.

---

## 4.2 Nome de host

```ini
server01
server02
```

Nesse caso, o nome deverá ser resolvido pelo ambiente em que o Ansible está
sendo executado.

Isso pode ocorrer, por exemplo, por:

- DNS;
- `/etc/hosts`;
- outro mecanismo de resolução de nomes disponível no sistema.

---

## 4.3 FQDN

É perfeitamente válido utilizar um **Fully Qualified Domain Name (FQDN)**.

Exemplo:

```ini
web01.example.com
web02.example.com
db01.example.com
```

Em um ambiente corporativo com DNS bem estruturado, utilizar FQDN pode
facilitar bastante a identificação dos sistemas.

---

# 5. Inventory hostname e `ansible_host`

O nome registrado no inventário não precisa ser necessariamente o endereço
real utilizado na conexão.

Exemplo:

```ini
[webservers]
web01 ansible_host=192.168.56.20
```

Nesse exemplo:

```text
web01
```

é o **inventory hostname**.

Já:

```text
192.168.56.20
```

é o endereço utilizado pelo Ansible para tentar estabelecer a conexão.

A relação pode ser visualizada assim:

```text
Inventory hostname
      web01
        |
        | ansible_host
        v
192.168.56.20
```

Também é possível utilizar um FQDN:

```ini
web01 ansible_host=web01.example.com
```

Isso permite trabalhar com nomes lógicos no inventário:

```bash
ansible web01 -m ansible.builtin.ping
```

sem exigir que o inventory hostname seja exatamente o destino da conexão.

---

# 6. Grupos

Hosts podem ser organizados em **grupos**.

No formato INI, um grupo é definido entre colchetes.

Exemplo:

```ini
[webservers]
web01.example.com
web02.example.com

[databases]
db01.example.com
db02.example.com
```

Agora é possível executar:

```bash
ansible webservers -m ansible.builtin.ping
```

ou:

```bash
ansible databases -m ansible.builtin.ping
```

Um Playbook também pode utilizar um grupo:

```yaml
---
- name: Configure web servers
  hosts: webservers

  tasks:
    - name: Test connectivity
      ansible.builtin.ping:
...
```

---

# 7. Grupos padrão

O Ansible possui grupos especiais criados automaticamente.

Os principais são:

```text
all
ungrouped
```

---

## 7.1 Grupo `all`

O grupo:

```text
all
```

contém todos os hosts conhecidos pelo inventário.

Exemplo:

```ini
192.168.56.10

[rh]
192.168.56.20
```

Ao executar:

```bash
ansible all --list-hosts
```

os dois hosts aparecem porque ambos fazem parte de `all`.

Em outras palavras:

```text
all
├── 192.168.56.10
└── 192.168.56.20
```

---

## 7.2 Grupo `ungrouped`

O grupo:

```text
ungrouped
```

contém hosts que não pertencem a nenhum grupo customizado, além do grupo
especial `all`.

Considere:

```ini
192.168.56.10

[rh]
192.168.56.20
```

O host:

```text
192.168.56.10
```

não foi incluído em nenhum grupo criado pelo administrador.

Portanto, ele pertence a:

```text
all
ungrouped
```

Já:

```text
192.168.56.20
```

pertence a:

```text
all
rh
```

e não pertence a `ungrouped`.

---

# 8. Grupos customizados

Além de `all` e `ungrouped`, podem ser criados grupos conforme a necessidade
do ambiente.

Exemplo:

```ini
[debian]
deb01.example.com
deb02.example.com

[redhat]
rh01.example.com
rh02.example.com

[freebsd]
bsd01.example.com
```

Esses grupos podem representar:

- sistema operacional;
- função;
- aplicação;
- ambiente;
- datacenter;
- localização;
- cliente;
- equipe responsável;
- qualquer outro critério útil para a automação.

---

# 9. Um host pode pertencer a vários grupos

Um host pode fazer parte de mais de um grupo.

Exemplo:

```ini
[webservers]
web01.example.com
web02.example.com

[production]
web01.example.com
db01.example.com

[databases]
db01.example.com
```

O host:

```text
web01.example.com
```

pertence simultaneamente aos grupos:

```text
all
webservers
production
```

Isso permite selecionar os hosts de diferentes perspectivas.

Por função:

```bash
ansible webservers --list-hosts
```

Por ambiente:

```bash
ansible production --list-hosts
```

---

# 10. Grupos filhos

Grupos podem conter outros grupos.

No formato INI, utiliza-se:

```text
:children
```

Exemplo:

```ini
[webservers]
web01.example.com
web02.example.com

[databases]
db01.example.com
db02.example.com

[production:children]
webservers
databases
```

Agora:

```text
production
├── webservers
│   ├── web01.example.com
│   └── web02.example.com
└── databases
    ├── db01.example.com
    └── db02.example.com
```

É possível executar:

```bash
ansible production --list-hosts
```

e obter todos os hosts pertencentes aos grupos filhos.

---

# 11. Inventário equivalente em YAML

O mesmo exemplo anterior pode ser escrito em YAML:

```yaml
---
all:
  children:
    production:
      children:
        webservers:
          hosts:
            web01.example.com:
            web02.example.com:

        databases:
          hosts:
            db01.example.com:
            db02.example.com:
...
```

Outra forma é definir os grupos no mesmo nível e fazer `production`
referenciá-los como filhos:

```yaml
---
all:
  children:

    webservers:
      hosts:
        web01.example.com:
        web02.example.com:

    databases:
      hosts:
        db01.example.com:
        db02.example.com:

    production:
      children:
        webservers:
        databases:
...
```

Essa segunda forma costuma ser mais fácil de visualizar em inventários
maiores.

---

# 12. Variáveis de host

É possível associar variáveis diretamente a um host.

No formato INI:

```ini
[webservers]
web01 ansible_host=192.168.56.20 ansible_user=tux
web02 ansible_host=192.168.56.21 ansible_user=tux
```

Agora o Ansible conhece:

```text
Inventory hostname: web01
Connection address: 192.168.56.20
Remote user:        tux
```

---

# 13. Variáveis de grupo

Também é possível atribuir variáveis a todos os membros de um grupo.

No formato INI:

```ini
[webservers]
web01.example.com
web02.example.com

[webservers:vars]
ansible_user=tux
ansible_port=22
```

As variáveis serão aplicadas aos hosts pertencentes ao grupo.

---

# 14. Variáveis em inventário YAML

No formato YAML:

```yaml
---
all:
  children:
    webservers:
      hosts:
        web01:
          ansible_host: 192.168.56.20

        web02:
          ansible_host: 192.168.56.21

      vars:
        ansible_user: tux
        ansible_port: 22
...
```

Aqui:

```yaml
vars:
```

define as variáveis do grupo `webservers`.

Já:

```yaml
web01:
  ansible_host: 192.168.56.20
```

define uma variável específica daquele host.

---

# 15. Variáveis de conexão importantes

Algumas variáveis são utilizadas frequentemente no inventário.

## `ansible_host`

Define o endereço utilizado na conexão:

```ini
web01 ansible_host=192.168.56.20
```

---

## `ansible_port`

Define a porta:

```ini
web01 ansible_host=192.168.56.20 ansible_port=2222
```

---

## `ansible_user`

Define o usuário remoto:

```ini
web01 ansible_user=tux
```

---

## `ansible_connection`

Define o tipo de conexão.

Exemplo:

```ini
localhost ansible_connection=local
```

Outro exemplo comum é SSH:

```ini
web01 ansible_connection=ssh
```

---

## `ansible_ssh_private_key_file`

Define uma chave SSH privada:

```ini
web01 ansible_ssh_private_key_file=~/.ssh/ansible
```

Evite armazenar informações secretas diretamente no inventário.

---

## `ansible_python_interpreter`

Permite informar explicitamente o interpretador Python remoto.

Exemplo:

```ini
web01 ansible_python_interpreter=/usr/bin/python3
```

Em versões atuais do Ansible, a descoberta automática do interpretador
resolve muitos casos, portanto essa variável deve ser utilizada quando
necessário.

---

## `ansible_become`

Pode habilitar elevação de privilégio para determinado host ou grupo.

Exemplo:

```ini
[webservers:vars]
ansible_become=true
```

---

## `ansible_become_user`

Define o usuário de destino do `become`.

Exemplo:

```ini
[webservers:vars]
ansible_become=true
ansible_become_user=root
```

---

# 16. Evite colocar senhas em texto claro

Tecnicamente existem variáveis relacionadas a senhas, mas não é uma boa
prática colocar segredos diretamente em um arquivo de inventário
versionado.

Evite algo como:

```ini
web01 ansible_password=MinhaSenha123
```

ou:

```ini
ansible_become_password=OutraSenha123
```

Prefira mecanismos como:

- Ansible Vault;
- variáveis criptografadas;
- ferramentas externas de gerenciamento de segredos;
- credenciais administradas por plataformas de automação.

---

# 17. Arquivos `group_vars`

Não é necessário colocar todas as variáveis diretamente no arquivo de
inventário.

O Ansible suporta a estrutura:

```text
group_vars/
```

Exemplo:

```text
ansible-project/
├── hosts
├── group_vars/
│   ├── all.yml
│   ├── webservers.yml
│   └── databases.yml
└── site.yml
```

Arquivo:

```text
group_vars/webservers.yml
```

Exemplo:

```yaml
---
ansible_user: tux
http_port: 8080
package_name: nginx
...
```

Essas variáveis são associadas ao grupo:

```text
webservers
```

---

```bash
mkdir {group,host}_vars
```

```bash
vim group_vars/debian.yaml
```

```yaml
---
package_manager: apt
...
```

```bash
ansible debian -i hosts -m debug -a 'var=package_manager'
```
```
192.168.56.10 | SUCCESS => {
    "package_manager": "apt"
}
```

ansible debian -i hosts \
  --extra-vars 'chave=valor' \
  -m ansible.builtin.debug \
  -a 'msg=package_manager={{package_manager}},chave={{chave}}'

192.168.56.10 | SUCCESS => {
    "msg": "package_manager=apt,chave=valor"
}


## Prioridades

host -> group -> children -> all




# 18. `group_vars/all.yml`

Variáveis destinadas a todos os hosts podem ser colocadas em:

```text
group_vars/all.yml
```

Exemplo:

```yaml
---
timezone: America/Sao_Paulo
dns_domain: example.com
...
```

Essas variáveis ficam disponíveis para os hosts do inventário, respeitando
as regras de precedência de variáveis do Ansible.

---

# 19. Arquivos `host_vars`

Variáveis específicas de um host podem ser armazenadas em:

```text
host_vars/
```

Exemplo:

```text
ansible-project/
├── hosts
├── host_vars/
│   ├── web01.yml
│   └── db01.yml
└── site.yml
```

Arquivo:

```text
host_vars/web01.yml
```

Exemplo:

```yaml
---
ansible_host: 192.168.56.20
http_port: 8080
...
```

Isso ajuda a evitar inventários gigantes contendo muitas variáveis inline.

---

# 20. Organização recomendada

Para um projeto pequeno:

```text
ansible-project/
├── ansible.cfg
├── hosts
├── playbook.yml
├── group_vars/
└── host_vars/
```

Para um ambiente maior:

```text
ansible-project/
├── ansible.cfg
├── inventories/
│   ├── development/
│   │   ├── hosts.yml
│   │   ├── group_vars/
│   │   └── host_vars/
│   │
│   ├── homologation/
│   │   ├── hosts.yml
│   │   ├── group_vars/
│   │   └── host_vars/
│   │
│   └── production/
│       ├── hosts.yml
│       ├── group_vars/
│       └── host_vars/
│
├── roles/
└── playbooks/
```

Essa separação reduz o risco de utilizar acidentalmente variáveis de um
ambiente em outro.

---

# 21. Selecionando um inventário

Um inventário específico pode ser informado com:

```text
-i
```

ou:

```text
--inventory
```

Exemplo:

```bash
ansible all -i hosts -m ansible.builtin.ping
```

Também:

```bash
ansible-playbook -i hosts site.yml
```

Com um diretório:

```bash
ansible-playbook -i inventories/production site.yml
```

Dependendo dos arquivos presentes e dos plugins de inventário habilitados,
o Ansible pode tratar um diretório como uma coleção de fontes de
inventário.

---

# 22. Utilizando mais de uma fonte de inventário

O Ansible pode receber múltiplas opções `-i`.

Exemplo:

```bash
ansible all \
  -i inventories/datacenter1.yml \
  -i inventories/datacenter2.yml \
  --list-hosts
```

As fontes são combinadas pelo mecanismo de inventário.

Isso pode ser útil quando diferentes partes da infraestrutura são
administradas separadamente.

---

# 23. `ansible-inventory`

O utilitário:

```bash
ansible-inventory
```

é uma das principais ferramentas para trabalhar com inventários.

Ele permite visualizar **como o Ansible interpretou o inventário**.

Isso é muito importante porque o conteúdo do arquivo e a estrutura
resultante podem não ser visualmente óbvios em inventários maiores.

---

# 24. Visualizando o inventário como árvore

Use:

```bash
ansible-inventory -i hosts --graph
```

Exemplo:

```text
@all:
  |--@ungrouped:
  |  |--192.168.56.10
  |--@rh:
  |  |--192.168.56.20
```

Essa é uma forma excelente de verificar grupos e relações entre eles.

---

# 25. Utilizando o inventário definido no `ansible.cfg`

Se o `ansible.cfg` contiver:

```ini
[defaults]
inventory = ./hosts
```

basta executar:

```bash
ansible-inventory --graph
```

Não é necessário informar:

```text
-i hosts
```

---

# 26. Listando o inventário completo

Use:

```bash
ansible-inventory -i hosts --list
```

A saída padrão normalmente é estruturada em JSON.

Para visualizar em YAML:

```bash
ansible-inventory -i hosts --list --yaml
```

Esse comando é especialmente útil para troubleshooting de:

- hosts;
- grupos;
- grupos filhos;
- variáveis.

---

# 27. Consultando um host

Para verificar as variáveis associadas a um determinado host:

```bash
ansible-inventory -i hosts --host web01
```

Exemplo:

```json
{
    "ansible_host": "192.168.56.20",
    "ansible_user": "tux"
}
```

Também pode ser utilizado:

```bash
ansible-inventory -i hosts --host web01 --yaml
```

---

# 28. Exibindo variáveis no gráfico

É possível usar:

```bash
ansible-inventory -i hosts --graph --vars
```

Isso pode ajudar bastante quando se deseja entender de quais grupos e
variáveis determinado host está recebendo configuração.

---

# 29. Verificando quais hosts seriam atingidos

O comando:

```bash
ansible <pattern> --list-hosts
```

não executa módulos nos Managed Nodes.

Ele apenas mostra quais hosts correspondem ao padrão informado.

Exemplo:

```bash
ansible webservers --list-hosts
```

Exemplo de saída:

```text
  hosts (2):
    web01.example.com
    web02.example.com
```

Antes de executar uma operação importante, essa é uma verificação muito
útil.

---

# 30. Padrões de hosts

O primeiro argumento do comando `ansible` normalmente é um **pattern**.

Exemplo:

```bash
ansible webservers -m ansible.builtin.ping
```

Aqui:

```text
webservers
```

é o pattern.

Um pattern pode representar:

- um host;
- um grupo;
- vários grupos;
- combinações;
- exclusões;
- interseções.

---

# 31. Todos os hosts

```bash
ansible all --list-hosts
```

Seleciona todos os hosts do inventário.

---

# 32. Um grupo

```bash
ansible webservers --list-hosts
```

Seleciona apenas o grupo `webservers`.

---

# 33. Mais de um grupo

É possível utilizar união de patterns.

Exemplo:

```bash
ansible 'webservers:databases' --list-hosts
```

Isso seleciona hosts pertencentes a:

```text
webservers OU databases
```

Colocar o pattern entre aspas é uma boa prática para evitar interpretações
indesejadas pelo shell.

---

# 34. Exclusão

Exemplo:

```bash
ansible 'all:!databases' --list-hosts
```

Significa:

```text
todos os hosts, exceto databases
```

---

# 35. Interseção

Exemplo:

```bash
ansible 'webservers:&production' --list-hosts
```

Seleciona hosts que pertencem simultaneamente aos grupos:

```text
webservers
E
production
```

---

# 36. Combinando patterns

Exemplo:

```bash
ansible 'webservers:&production:!maintenance' --list-hosts
```

Conceitualmente:

```text
webservers
    AND
production
    EXCEPT
maintenance
```

Esse recurso é bastante poderoso em inventários bem organizados.

---

# 37. Faixas (*ranges*) de hosts

Quando vários hosts seguem um padrão numérico ou alfabético, não é
necessário listar cada endereço individualmente.

Os plugins de inventário INI e YAML suportam **ranges de hosts**.

## 37.1 Range em endereços IP

Por exemplo:

```ini
[examplerange]
192.168.56.7[0:9]
```

Esse range é expandido para:

```text
192.168.56.70
192.168.56.71
192.168.56.72
192.168.56.73
192.168.56.74
192.168.56.75
192.168.56.76
192.168.56.77
192.168.56.78
192.168.56.79
```

Os limites são **inclusivos**. Portanto:

```text
[0:9]
```

inclui tanto `0` quanto `9`.

Esse recurso não representa uma rede CIDR e não realiza descoberta de
hosts. Ele apenas gera nomes ou endereços seguindo o padrão informado.

Por exemplo:

```ini
[servers]
192.168.56.[10:15]
```

representa:

```text
192.168.56.10
192.168.56.11
192.168.56.12
192.168.56.13
192.168.56.14
192.168.56.15
```

---

## 37.2 Range em hostnames e FQDNs

Ranges também podem ser usados dentro de nomes de hosts.

Exemplo:

```ini
[databases]
db0[0:7].my.domain
```

Esse padrão representa:

```text
db00.my.domain
db01.my.domain
db02.my.domain
db03.my.domain
db04.my.domain
db05.my.domain
db06.my.domain
db07.my.domain
```

Outro exemplo:

```ini
[webservers]
web[01:05].example.com
```

representa:

```text
web01.example.com
web02.example.com
web03.example.com
web04.example.com
web05.example.com
```

Os zeros à esquerda são preservados de acordo com o padrão informado.

---

## 37.3 Incremento (*stride*)

Também é possível definir o incremento do range.

A sintaxe é:

```text
[início:fim:incremento]
```

Exemplo:

```ini
[webservers]
web[01:10:2].example.com
```

A expansão será:

```text
web01.example.com
web03.example.com
web05.example.com
web07.example.com
web09.example.com
```

O incremento `2` faz com que o Ansible avance de dois em dois.

---

## 37.4 Ranges alfabéticos

Ranges também podem utilizar letras.

Exemplo:

```ini
[databases]
db-[a:f].example.com
```

representa:

```text
db-a.example.com
db-b.example.com
db-c.example.com
db-d.example.com
db-e.example.com
db-f.example.com
```

---

## 37.5 Range em inventário YAML

O mesmo conceito pode ser utilizado em um inventário YAML.

Exemplo:

```yaml
---
all:
  children:
    webservers:
      hosts:
        web[01:05].example.com:
...
```

Ou com endereços IP:

```yaml
---
all:
  children:
    examplerange:
      hosts:
        192.168.56.7[0:9]:
...
```

---

## 37.6 Verificando a expansão

Sempre que utilizar ranges, confira como o Ansible interpretou o
inventário.

Exemplo:

```bash
ansible-inventory -i hosts --graph
```

Para:

```ini
[examplerange]
192.168.56.7[0:9]
```

a árvore deverá mostrar os dez hosts expandidos.

Também é possível verificar somente o grupo:

```bash
ansible examplerange -i hosts --list-hosts
```

Uma saída esperada é semelhante a:

```text
hosts (10):
  192.168.56.70
  192.168.56.71
  192.168.56.72
  192.168.56.73
  192.168.56.74
  192.168.56.75
  192.168.56.76
  192.168.56.77
  192.168.56.78
  192.168.56.79
```

---

## 37.7 Range não é pattern de execução

É importante diferenciar dois conceitos:

```text
Range no inventário
    -> cria/expande hosts no inventário

Pattern
    -> seleciona hosts que já existem no inventário
```

Por exemplo:

```ini
[webservers]
web[01:05].example.com
```

faz o inventário conter cinco hosts.

Depois disso, comandos como:

```bash
ansible webservers --list-hosts
```

ou:

```bash
ansible 'web*.example.com' --list-hosts
```

podem selecionar esses hosts.

O range é utilizado na **definição do inventário**; o pattern é utilizado
na **seleção dos hosts**.


# 38. Inventário INI completo

Exemplo:

```ini
[webservers]
web01 ansible_host=192.168.56.21
web02 ansible_host=192.168.56.22

[databases]
db01 ansible_host=192.168.56.31
db02 ansible_host=192.168.56.32

[linux:children]
webservers
databases

[production:children]
webservers
databases

[linux:vars]
ansible_user=tux
ansible_port=22
```

A estrutura resultante é aproximadamente:

```text
all
├── linux
│   ├── webservers
│   │   ├── web01
│   │   └── web02
│   │
│   └── databases
│       ├── db01
│       └── db02
│
└── production
    ├── webservers
    └── databases
```

Observe que os mesmos hosts podem aparecer em diferentes ramos por
pertencerem a vários grupos.

---

# 39. Inventário YAML completo

Uma versão equivalente pode ser escrita como:

```yaml
---
all:
  children:

    webservers:
      hosts:
        web01:
          ansible_host: 192.168.56.21
        web02:
          ansible_host: 192.168.56.22

    databases:
      hosts:
        db01:
          ansible_host: 192.168.56.31
        db02:
          ansible_host: 192.168.56.32

    linux:
      children:
        webservers:
        databases:
      vars:
        ansible_user: tux
        ansible_port: 22

    production:
      children:
        webservers:
        databases:
...
```

---

# 40. INI ou YAML?

Os dois formatos são válidos.

Uma comparação simplificada:

| Característica | INI | YAML |
|---|---|---|
| Simplicidade inicial | Muito boa | Boa |
| Inventários pequenos | Excelente | Excelente |
| Estruturas complexas | Menos visual | Mais clara |
| Tipos de dados | Pode gerar ambiguidades | Mais explícitos |
| Variáveis aninhadas | Menos natural | Melhor |
| Familiaridade em Ansible | Alta | Alta |

Para laboratórios introdutórios, INI pode ser mais fácil.

Para estruturas grandes e com muitas variáveis, YAML tende a ser mais
organizado.

---

# 41. Cuidado com tipos em inventários INI

Inventários INI podem apresentar diferenças de interpretação de tipos
dependendo de onde uma variável foi declarada.

Por isso, valores como:

```text
true
false
10
1.5
```

nem sempre devem ser tratados mentalmente como simples strings.

Quando o tipo do dado for importante, YAML costuma ser mais explícito:

```yaml
enabled: true
workers: 10
ratio: 1.5
```

Em Playbooks, evite depender de conversões implícitas.

Filtros como:

```jinja2
{{ value | int }}
```

ou:

```jinja2
{{ value | bool }}
```

podem ser úteis quando a origem da variável não garante o tipo desejado.

---

# 42. Nomes de grupos

Prefira nomes simples e previsíveis.

Exemplos:

```text
webservers
databases
production
development
redhat
debian
freebsd
```

Evite nomes que compliquem a leitura, o uso de patterns ou o processamento
por ferramentas externas.

Uma convenção consistente torna comandos como:

```bash
ansible production --list-hosts
```

muito mais fáceis de compreender.

---

# 43. Organizando por função e ambiente

Uma estratégia bastante útil é criar grupos independentes para função e
ambiente.

Exemplo:

```ini
[webservers]
web01
web02
web03

[databases]
db01
db02

[production]
web01
web02
db01

[development]
web03
db02
```

Agora é possível trabalhar com:

```bash
ansible webservers --list-hosts
```

ou:

```bash
ansible production --list-hosts
```

ou ainda:

```bash
ansible 'webservers:&production' --list-hosts
```

Esse último seleciona apenas os servidores Web de produção.

---

# 44. Organizando por sistema operacional

Outra possibilidade:

```ini
[debian]
deb01
deb02

[redhat]
rh01
rh02

[freebsd]
bsd01
```

Isso pode ser útil para determinadas tarefas específicas.

Entretanto, para decisões baseadas no sistema operacional detectado,
**Facts** também podem ser mais adequados do que manter manualmente uma
classificação que pode ficar desatualizada.

---

# 45. Inventário estático

Um inventário como:

```ini
[webservers]
web01.example.com
web02.example.com
```

é chamado de inventário estático porque sua informação é mantida
explicitamente em arquivos.

Ele funciona muito bem quando:

- o ambiente muda pouco;
- a quantidade de hosts é pequena ou moderada;
- existe um processo claro de atualização;
- a infraestrutura é relativamente estável.

---

# 46. Limitação do inventário estático

Imagine um ambiente de cloud no qual VMs são criadas e removidas
constantemente.

Manter manualmente:

```ini
[webservers]
10.20.0.101
10.20.0.102
10.20.0.103
```

pode rapidamente ficar desatualizado.

É nesse tipo de cenário que entram os inventários dinâmicos.

---

# 47. Inventário dinâmico

Um inventário dinâmico obtém hosts e grupos a partir de uma fonte externa.

Exemplos de fontes:

- AWS;
- Azure;
- Google Cloud;
- VMware;
- OpenStack;
- plataformas de virtualização;
- APIs internas;
- CMDB;
- sistemas de gerenciamento de ativos.

A ideia é:

```text
External Source
      |
      | API
      v
Inventory Plugin
      |
      v
Ansible
      |
      v
Managed Nodes
```

Assim, o inventário pode refletir automaticamente o estado atual da
infraestrutura.

---

# 48. CMDB e inventário

Uma CMDB pode funcionar como fonte de informações para o inventário.

Exemplo conceitual:

```text
CMDB
 |
 | hostname
 | IP
 | environment
 | operating system
 | role
 | metadata
 v
Dynamic Inventory
 |
 v
Ansible
```

A CMDB e o inventário não são necessariamente a mesma coisa.

O inventário responde principalmente:

> quais hosts o Ansible conhece e como devo agrupá-los ou conectar a eles?

Uma CMDB pode conter muito mais informações, inclusive relacionamentos entre
os componentes da infraestrutura.

---

# 49. Inventory plugins

Versões modernas do Ansible utilizam **inventory plugins** para diversas
fontes de inventário.

Eles permitem transformar dados externos em:

- hosts;
- grupos;
- variáveis.

Os plugins disponíveis podem ser consultados com:

```bash
ansible-doc -t inventory -l
```

Para consultar um plugin específico:

```bash
ansible-doc -t inventory <plugin>
```

Isso é particularmente importante ao trabalhar com inventários dinâmicos.

---

# 50. Validando um inventário antes de executar

Antes de executar uma automação importante, um fluxo simples é:

```bash
ansible-inventory -i hosts --graph
```

Depois:

```bash
ansible all -i hosts --list-hosts
```

E então:

```bash
ansible all -i hosts -m ansible.builtin.ping
```

Esse processo verifica, respectivamente:

```text
Estrutura do inventário
        |
        v
Hosts selecionados
        |
        v
Conectividade
```

---

# 51. Testando um grupo

```bash
ansible webservers -i hosts --list-hosts
```

Depois:

```bash
ansible webservers -i hosts \
  -m ansible.builtin.ping
```

---

# 52. Descobrindo erros de grupo

Considere que você espera três hosts em `production`.

Execute:

```bash
ansible production -i hosts --list-hosts
```

Se aparecer apenas um, investigue:

```bash
ansible-inventory -i hosts --graph
```

Isso costuma ser muito mais seguro do que descobrir o problema durante uma
automação.

---

# 53. Inventário e DNS

Quando FQDNs são utilizados:

```ini
[webservers]
web01.example.com
web02.example.com
```

é importante verificar se o Control Node consegue resolvê-los.

Exemplo:

```bash
getent hosts web01.example.com
```

A resolução de nome acontece antes ou durante o estabelecimento da conexão,
dependendo da pilha utilizada.

Um inventário correto não corrige problemas de DNS.

---

# 54. Inventário e SSH

Para hosts Unix-like, a conexão padrão normalmente utiliza SSH.

Portanto, antes de culpar o inventário, pode ser útil testar:

```bash
ssh tux@web01.example.com
```

Depois:

```bash
ansible web01.example.com \
  -m ansible.builtin.ping
```

Isso ajuda a separar:

```text
Problema de DNS
Problema de SSH
Problema de autenticação
Problema de inventário
Problema do Ansible
```

---

# 55. Inventário para Windows

O inventário também pode conter hosts Windows.

Exemplo conceitual:

```ini
[windows]
win01 ansible_host=192.168.56.50

[windows:vars]
ansible_connection=winrm
ansible_user=Administrator
```

Outras configurações de WinRM normalmente serão necessárias conforme o
método de autenticação e a política do ambiente.

Evite colocar senhas em texto claro no arquivo.

---

# 56. Inventário para localhost

É possível adicionar o próprio Control Node:

```ini
[local]
localhost ansible_connection=local
```

Teste:

```bash
ansible local -i hosts \
  -m ansible.builtin.ping
```

Nesse caso, não é necessária uma conexão SSH para executar localmente.

---

# 57. Nome lógico para localhost

Também seria possível:

```ini
[local]
controller ansible_host=127.0.0.1 ansible_connection=local
```

Aqui o nome usado pelo Ansible é:

```text
controller
```

mas a execução ocorre localmente devido a:

```text
ansible_connection=local
```

---

# 58. O inventário não precisa representar somente servidores

Dependendo das Collections, plugins e métodos de conexão utilizados, o
Ansible pode trabalhar com outros tipos de dispositivos.

Exemplos:

- equipamentos de rede;
- APIs;
- appliances;
- plataformas cloud;
- hypervisors.

Portanto, um inventário representa **targets gerenciáveis pelo Ansible**,
não necessariamente apenas servidores Linux.

---

# 59. Inventário não é descoberta automática

Criar:

```ini
[all]
192.168.56.0/24
```

não significa automaticamente que o Ansible fará um scan da rede para
descobrir todos os dispositivos.

O inventário descreve hosts ou utiliza plugins/fontes capazes de fornecê-los.

O Ansible não deve ser confundido com uma ferramenta de descoberta de rede.

---

# 60. Boa prática: utilize nomes significativos

Compare:

```ini
srv001
srv002
srv003
```

com:

```ini
web01
web02
db01
```

ou FQDNs bem definidos:

```ini
web01.prod.example.com
web02.prod.example.com
db01.prod.example.com
```

Uma nomenclatura consistente facilita:

- troubleshooting;
- patterns;
- Playbooks;
- logs;
- auditoria;
- integração com outras ferramentas.

---

# 61. Boa prática: evite excesso de variáveis inline

Isto funciona:

```ini
web01 ansible_host=192.168.56.20 ansible_user=tux ansible_port=22 ansible_become=true app_port=8080 environment=production
```

Mas rapidamente fica difícil de manter.

Prefira:

```ini
[webservers]
web01 ansible_host=192.168.56.20
```

e mova valores comuns para:

```text
group_vars/
```

ou:

```text
host_vars/
```

---

# 62. Boa prática: separe ambientes críticos

Em vez de misturar tudo em um único arquivo enorme, pode ser melhor ter:

```text
inventories/
├── development/
├── homologation/
└── production/
```

Isso reduz erros como executar acidentalmente uma automação de teste em
produção.

Ainda assim, a organização deve refletir a realidade operacional da
empresa.

---

# 63. Boa prática: use `--list-hosts`

Antes de uma operação destrutiva ou sensível:

```bash
ansible 'production:&databases' --list-hosts
```

Confira cuidadosamente a lista.

Depois execute a automação.

Essa pequena etapa pode evitar erros graves.

---

# 64. Boa prática: use `ansible-inventory`

Ao modificar o inventário:

```bash
ansible-inventory --graph
```

Depois:

```bash
ansible-inventory --list --yaml
```

Esses comandos permitem conferir como o Ansible realmente interpretou os
dados.

---

# 65. Boa prática: versionamento

Inventários estáticos, quando apropriado, podem ser mantidos em Git junto
com o projeto Ansible.

Porém:

- não armazene senhas em texto claro;
- não versione chaves privadas;
- não versione tokens;
- proteja informações sensíveis;
- utilize Vault ou um sistema de segredos.

---

# 66. Inventário e idempotência

O inventário não é responsável pela idempotência.

Ele determina:

- quais hosts existem;
- grupos;
- variáveis;
- parâmetros de conexão.

A idempotência depende principalmente da lógica do Playbook e do
comportamento dos módulos utilizados.

Conceitualmente:

```text
Inventory
    |
    | quem?
    v
Managed Hosts

Playbook
    |
    | o quê?
    v
Desired State

Module
    |
    | como verificar/aplicar?
    v
Current State -> Desired State
```

---

# 67. Inventário e Facts

Inventário e Facts também são conceitos diferentes.

O inventário pode dizer:

```yaml
web01:
  ansible_host: 192.168.56.20
```

Já os Facts podem descobrir informações como:

```text
Operating system
Kernel
CPU
Memory
Network interfaces
IP addresses
Architecture
```

Ou seja:

```text
Inventory
    -> informações declaradas ou obtidas da fonte de inventário

Facts
    -> informações coletadas do Managed Node
```

---

# 68. Exercício 1 — inventário básico

Crie:

```bash
mkdir -p ~/ansible-inventory-lab
cd ~/ansible-inventory-lab
```

Crie o arquivo:

```bash
cat > hosts <<'EOF'
192.168.56.10

[rh]
192.168.56.20
EOF
```

Visualize:

```bash
ansible-inventory -i hosts --graph
```

Observe os grupos:

```text
all
ungrouped
rh
```

---

# 69. Exercício 2 — configurar no `ansible.cfg`

Crie:

```bash
cat > ansible.cfg <<'EOF'
[defaults]
inventory = ./hosts
EOF
```

Agora execute:

```bash
ansible-inventory --graph
```

Não é mais necessário informar:

```text
-i hosts
```

---

# 70. Exercício 3 — grupos customizados

Altere o inventário:

```ini
[debian]
deb01 ansible_host=192.168.56.10

[redhat]
rh01 ansible_host=192.168.56.20

[freebsd]
bsd01 ansible_host=192.168.56.30
```

Confira:

```bash
ansible-inventory --graph
```

---

# 71. Exercício 4 — grupo filho

Adicione:

```ini
[unix:children]
debian
redhat
freebsd
```

Agora:

```bash
ansible unix --list-hosts
```

deverá selecionar os membros dos três grupos filhos.

Confira também:

```bash
ansible-inventory --graph
```

---

# 72. Exercício 5 — variáveis de grupo

Adicione:

```ini
[linux:children]
debian
redhat

[linux:vars]
ansible_user=tux
```

Consulte:

```bash
ansible-inventory --host deb01
```

e:

```bash
ansible-inventory --host rh01
```

Observe as variáveis herdadas.

---

# 73. Exercício 6 — patterns

Liste todos:

```bash
ansible all --list-hosts
```

Somente Red Hat:

```bash
ansible redhat --list-hosts
```

Linux:

```bash
ansible linux --list-hosts
```

Tudo menos FreeBSD:

```bash
ansible 'all:!freebsd' --list-hosts
```

Interseção:

```bash
ansible 'linux:&redhat' --list-hosts
```

---

# 74. Exercício 7 — teste de conectividade

Quando os hosts estiverem acessíveis:

```bash
ansible all \
  -m ansible.builtin.ping
```

Para apenas um grupo:

```bash
ansible redhat \
  -m ansible.builtin.ping
```

---

# 75. Fluxo recomendado para trabalhar com inventários

Uma sequência simples e segura é:

```text
1. Editar o inventário
        |
        v
2. ansible-inventory --graph
        |
        v
3. ansible-inventory --list --yaml
        |
        v
4. ansible <pattern> --list-hosts
        |
        v
5. ansible <pattern> -m ansible.builtin.ping
        |
        v
6. Executar Playbooks
```

Isso ajuda a identificar erros antes de realizar mudanças na infraestrutura.

---

# 76. Resumo

O inventário é uma das peças centrais do Ansible.

Ele informa ao Ansible:

```text
Quais hosts existem?
Como eles são chamados?
Como conectar a eles?
A quais grupos pertencem?
Quais variáveis estão associadas?
```

Os conceitos fundamentais são:

```text
Inventory
├── Hosts
│   ├── IP
│   ├── hostname
│   └── FQDN
│
├── Groups
│   ├── all
│   ├── ungrouped
│   └── custom groups
│
├── Children
│
├── Variables
│   ├── host variables
│   └── group variables
│
├── group_vars
├── host_vars
│
├── Static inventory
└── Dynamic inventory
```

E a ferramenta mais importante para verificar como o inventário foi
interpretado é:

```bash
ansible-inventory
```

Sempre que houver dúvida sobre hosts, grupos ou variáveis, comece por:

```bash
ansible-inventory --graph
```

e:

```bash
ansible-inventory --list --yaml
```


ansible-inventory -i hosts --graph 
@all:
  |--@ungrouped:
  |--@debian:
  |  |--192.168.56.10
  |--@rh:
  |  |--192.168.56.20



---

# Referências

- Ansible Community Documentation — How to build your inventory:
  <https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html>

- Ansible Community Documentation — Working with dynamic inventory:
  <https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_dynamic_inventory.html>

- Ansible Community Documentation — Patterns: targeting hosts and groups:
  <https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_patterns.html>

- Ansible Community Documentation — `ansible-inventory`:
  <https://docs.ansible.com/projects/ansible/latest/cli/ansible-inventory.html>

- Ansible Community Documentation — Inventory plugins:
  <https://docs.ansible.com/projects/ansible/latest/plugins/inventory.html>
