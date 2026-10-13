# Introdução ao YAML

## 1. O que é YAML?

YAML é uma linguagem de serialização de dados criada para representar
informações de forma simples, estruturada e legível tanto por pessoas quanto
por programas.

O nome YAML é um acrônimo recursivo para **YAML Ain't Markup Language**.
YAML não é uma linguagem de programação: ele não executa tarefas por conta
própria. Seu papel é descrever dados que serão interpretados por outra
aplicação.

Por isso, YAML é muito utilizado em automação, infraestrutura como código e
arquivos de configuração. Alguns exemplos são:

- Ansible;
- Kubernetes;
- Docker Compose;
- GitHub Actions;
- GitLab CI/CD;
- cloud-init;
- ferramentas de observabilidade;
- pipelines de CI/CD;
- configurações de aplicações.

Um arquivo YAML normalmente utiliza as extensões `.yaml` ou `.yml`.

## 2. As três estruturas fundamentais do YAML

Antes de trabalhar com arquivos YAML maiores, é importante entender três
estruturas básicas:

1. **scalars**: valores simples;
2. **mappings**: pares de chave e valor;
3. **sequences**: listas ordenadas de itens.

A maior parte dos arquivos YAML encontrados no dia a dia é formada pela
combinação dessas três estruturas.

### 2.1. Scalars

Um **scalar** é um valor único. Pode representar, por exemplo:

- uma string;
- um número inteiro;
- um número de ponto flutuante;
- um booleano;
- um valor nulo.

Exemplo:

```yaml
---
application: ansible
port: 22
enabled: true
timeout: 30.5
optional_value: null
```

Nesse exemplo, `ansible`, `22`, `true`, `30.5` e `null` são valores escalares.

### 2.2. Mappings: pares de chave e valor

Um **mapping** é uma coleção de pares de **chave e valor**. Essa é uma das
estruturas mais importantes do YAML.

A forma básica é:

```yaml
key: value
```

Por exemplo:

```yaml
---
name: webserver
port: 8080
enabled: true
```

O documento acima contém um mapping com três pares:

- `name` -> `webserver`;
- `port` -> `8080`;
- `enabled` -> `true`.

A chave aparece à esquerda de `:` e o valor aparece à direita.

#### Mappings aninhados

O valor de uma chave também pode ser outro mapping.

```yaml
---
server:
  name: web01
  address: 192.168.10.20
  port: 22
```

Nesse exemplo:

- `server` é uma chave;
- o valor de `server` é outro mapping;
- esse mapping contém as chaves `name`, `address` e `port`.

A indentação indica que essas três chaves pertencem a `server`.

Outro exemplo:

```yaml
---
application:
  name: portal
  database:
    host: db01
    port: 5432
```

A estrutura pode ser lida assim:

```text
application
├── name: portal
└── database
    ├── host: db01
    └── port: 5432
```

### 2.3. Indentação

YAML utiliza indentação para representar hierarquia.

```yaml
---
application:
  name: portal
  database:
    host: db01
    port: 5432
```

Uma prática muito comum é utilizar **dois espaços por nível de indentação**.

> YAML não deve utilizar TAB para indentação. Utilize espaços.

Uma indentação incorreta pode mudar a estrutura do documento ou torná-lo
inválido.

### 2.4. Sequences: listas ordenadas

Depois de entender mappings, fica mais simples entender **sequences**.

Uma **sequence** é uma lista ordenada de itens. Na sintaxe em bloco, cada item
normalmente começa com `-`.

Exemplo de uma lista simples:

```yaml
---
packages:
  - nginx
  - git
  - curl
```

Nesse exemplo:

- `packages` é uma chave de um mapping;
- o valor de `packages` é uma sequence;
- a sequence possui três valores escalares: `nginx`, `git` e `curl`.

Também é possível ter uma sequence diretamente como conteúdo principal do
documento:

```yaml
---
- nginx
- git
- curl
```

### 2.5. Sequences contendo mappings

Uma lista também pode conter mappings como seus itens.

```yaml
---
servers:
  - name: web01
    address: 192.168.10.20
    role: frontend

  - name: db01
    address: 192.168.10.30
    role: database
```

Nesse caso:

- `servers` é uma chave;
- seu valor é uma sequence;
- cada item da sequence é um mapping;
- cada mapping possui `name`, `address` e `role`.

Esse padrão aparece com frequência em Ansible, Kubernetes e outras ferramentas
de automação.

### 2.6. Mappings contendo sequences

Também é comum que um mapping tenha uma chave cujo valor seja uma sequence.

```yaml
---
application:
  name: portal
  servers:
    - web01
    - web02
    - web03
```

Aqui:

- o documento principal é um mapping;
- `application` aponta para outro mapping;
- `servers` é uma chave desse mapping;
- o valor de `servers` é uma sequence.

### 2.7. Combinando mappings e sequences

Mappings e sequences podem ser combinados para representar estruturas mais
complexas.

```yaml
---
environments:
  production:
    servers:
      - name: web01
        address: 192.168.10.20
      - name: web02
        address: 192.168.10.21

  development:
    servers:
      - name: dev01
        address: 192.168.20.10
```

A leitura dessa estrutura é:

- `environments` é um mapping;
- `production` e `development` são mappings;
- cada ambiente possui uma chave `servers`;
- `servers` contém uma sequence;
- cada item da sequence é um mapping representando um servidor.

Compreender essa combinação é essencial para ler arquivos YAML utilizados em
Ansible e outras ferramentas.

## 3. Tipos de valores

YAML pode representar diferentes tipos de dados.

```yaml
---
name: ansible
version: "2.20"
port: 22
enabled: true
timeout: 30.5
value: null
```

Alguns tipos comuns são:

- strings;
- números inteiros;
- números de ponto flutuante;
- booleanos;
- valores nulos;
- sequences;
- mappings.

Quando for importante garantir que determinado valor seja interpretado como
string, utilize aspas.

```yaml
---
version: "1.20"
code: "00123"
date: "2026-10-04"
```

Isso ajuda a evitar interpretações diferentes entre parsers YAML.

## 4. Aspas

Strings simples normalmente não precisam de aspas.

```yaml
---
name: production
```

Entretanto, aspas são recomendadas quando o valor:

- contém caracteres especiais;
- pode ser confundido com número, data ou booleano;
- precisa preservar exatamente seu formato;
- contém `:` seguido de espaço;
- começa com caracteres que possuem significado especial em YAML.

Exemplo:

```yaml
---
password_example: "abc: 123"
version: "01.10"
message: 'Service is ready'
```

Aspas simples tratam o conteúdo de forma mais literal. Aspas duplas permitem
sequências de escape, como `\n`.

## 5. Comentários

Comentários começam com `#`.

```yaml
---
# Web server configuration
server:
  address: 192.168.10.20
  port: 8080  # Application port
```

Comentários devem explicar decisões ou comportamentos importantes, e não
simplesmente repetir o conteúdo da configuração.

## 6. Textos com várias linhas

YAML oferece duas formas muito úteis de representar textos longos.

### 6.1. Literal block: `|`

O caractere `|` preserva as quebras de linha.

```yaml
---
message: |
  First line.
  Second line.
  Third line.
```

### 6.2. Folded block: `>`

O caractere `>` transforma a maioria das quebras de linha em espaços.

```yaml
---
message: >
  This text was written
  on multiple lines but will
  normally be interpreted as one paragraph.
```

Esse recurso é útil em descrições, mensagens e configurações longas.

## 7. `---` e `...`: início e fim do documento

YAML possui marcadores para delimitar documentos.

```yaml
---
name: web01
address: 192.168.10.20
...
```

O marcador `---` indica explicitamente o início de um documento YAML.
O marcador `...` indica explicitamente o fim desse documento.

### É obrigatório sempre usar os dois?

**Não.**

Um documento YAML pode existir sem `---` e sem `...`.

```yaml
name: web01
address: 192.168.10.20
```

Mesmo assim, utilizar `---` no início é uma convenção bastante comum, pois
deixa explícita a fronteira do documento e melhora a consistência dos arquivos.

O `...` é opcional e aparece com menos frequência em arquivos de configuração.
Ele é útil quando se deseja marcar explicitamente o final de um documento.

Um detalhe importante: o marcador de término é:

```text
...
```

Ele normalmente começa na primeira coluna. Não é necessário escrever ` ...`
com um espaço antes dos três pontos.

No contexto de Ansible, é comum encontrar:

```yaml
---
- name: Configure web servers
  hosts: webservers
  tasks:
    - name: Install nginx
      ansible.builtin.package:
        name: nginx
        state: present
```

Ou seja: `---` no início e, normalmente, sem `...` no final.

## 8. Vários documentos no mesmo arquivo

Um único stream YAML pode conter vários documentos.

```yaml
---
name: web01
role: frontend
---
name: db01
role: database
---
name: cache01
role: redis
```

Esse recurso é bastante comum em manifests Kubernetes.

Também é possível terminar explicitamente cada documento:

```yaml
---
name: web01
...
---
name: db01
...
```

## 9. Sintaxe em bloco e sintaxe flow

A forma mais comum de escrever YAML é a sintaxe em bloco:

```yaml
---
server:
  name: web01
  packages:
    - nginx
    - curl
```

YAML também possui uma sintaxe compacta, chamada **flow style**.

Mapping em flow style:

```yaml
---
server: {name: web01, port: 22}
```

Sequence em flow style:

```yaml
---
packages: [nginx, git, curl]
```

Embora válida, a sintaxe em bloco costuma ser preferida em arquivos de
configuração por ser mais fácil de ler e manter.

## 10. Anchors e aliases

YAML possui mecanismos de reutilização de estruturas chamados **anchors** e
**aliases**.

Um anchor é definido utilizando `&` e referenciado utilizando `*`.

```yaml
---
defaults: &defaults
  timeout: 30
  retries: 3

production:
  settings: *defaults

development:
  settings: *defaults
```

Anchors podem reduzir repetição, mas devem ser usados com moderação.
Configurações com muitos anchors e aliases podem se tornar difíceis de ler.


## 11. Variáveis: um conceito da ferramenta, não do YAML

É comum ouvir expressões como **"variáveis em YAML"**, principalmente ao
trabalhar com Ansible, Docker Compose, GitHub Actions e outras ferramentas.
Porém, é importante fazer uma distinção:

> **YAML, por si só, não possui variáveis, interpolação ou operações.**

YAML apenas representa dados. Uma estrutura como esta:

```yaml
---
web_package: nginx
http_port: 8080
```

contém apenas duas chaves com seus respectivos valores. É a aplicação que lê o
arquivo que pode decidir tratar essas chaves como variáveis.

No Ansible, por exemplo, podemos declarar variáveis dentro de `vars`:

```yaml
---
- name: Variable example
  hosts: webservers

  vars:
    web_package: nginx
    http_port: 8080
```

Nesse contexto, **o Ansible** interpreta `web_package` e `http_port` como
variáveis.

### 11.1. Referenciando variáveis no Ansible

O Ansible utiliza expressões do **Jinja2** para referenciar variáveis em muitos
campos.

```yaml
---
- name: Variable example
  hosts: webservers

  vars:
    web_package: nginx

  tasks:
    - name: Install package
      ansible.builtin.package:
        name: "{{ web_package }}"
        state: present
```

A expressão:

```text
{{ web_package }}
```

não é uma funcionalidade do YAML. Ela é interpretada pelo Ansible por meio do
Jinja2.

### 11.2. É possível fazer operações com variáveis?

**Sim, desde que a ferramenta que interpreta o YAML ofereça esse recurso.**

No caso do Ansible, é possível executar operações e expressões com variáveis
usando Jinja2. Portanto, as variáveis não servem apenas para substituir ou
"chamar" valores.

#### Operações aritméticas

```yaml
---
- name: Arithmetic example
  hosts: localhost

  vars:
    current_users: 10
    new_users: 5

  tasks:
    - name: Show total users
      ansible.builtin.debug:
        msg: "Total users: {{ current_users + new_users }}"
```

Nesse caso, o resultado da expressão será `15`.

Outros operadores aritméticos também podem ser usados:

```text
+   addition
-   subtraction
*   multiplication
/   division
%   remainder
```

Exemplo:

```yaml
---
memory_mb: 4096
memory_gb: "{{ memory_mb / 1024 }}"
```

A expressão é processada pelo Ansible/Jinja2, e não pelo YAML.

#### Operações com strings

Strings também podem ser combinadas.

```yaml
---
host_name: web01
environment: production
full_name: "{{ host_name ~ '-' ~ environment }}"
```

O operador `~` do Jinja2 concatena valores como texto. O resultado será:

```text
web01-production
```

#### Operações com listas

É possível combinar listas:

```yaml
---
base_packages:
  - vim
  - git

extra_packages:
  - curl
  - unzip

all_packages: "{{ base_packages + extra_packages }}"
```

Também podemos consultar propriedades de uma lista com filtros:

```yaml
---
packages:
  - nginx
  - git
  - curl

package_count: "{{ packages | length }}"
```

Nesse exemplo, `package_count` terá o valor `3` quando a expressão for
processada pelo Ansible.

### 11.3. Comparações e expressões lógicas

Variáveis também podem ser usadas em condições.

```yaml
---
- name: Conditional example
  hosts: webservers

  vars:
    free_space_mb: 800

  tasks:
    - name: Warn about disk space
      ansible.builtin.debug:
        msg: "Low disk space"
      when: free_space_mb < 1024
```

Alguns operadores comuns são:

```text
==   equal to
!=   different from
>    greater than
<    less than
>=   greater than or equal to
<=   less than or equal to
and  logical AND
or   logical OR
not  logical NOT
```

Observe que a condição de `when` é uma expressão interpretada pelo Ansible.
Ela não é executada pelo parser YAML.

### 11.4. Filtros

O Ansible também disponibiliza filtros Jinja2 para transformar ou consultar
valores.

```yaml
---
user_name: evailton
```

Alguns exemplos de uso:

```text
{{ user_name | upper }}
{{ user_name | lower }}
{{ packages | length }}
{{ variable | default('default-value') }}
```

Os filtros podem ser encadeados, dependendo da necessidade.

### 11.5. Variáveis em diferentes ferramentas

A forma de declarar e utilizar variáveis depende da aplicação que interpreta o
arquivo YAML.

Por exemplo:

- **Ansible** utiliza variáveis e expressões Jinja2;
- **Docker Compose** pode fazer substituição de variáveis de ambiente;
- **GitHub Actions** possui sua própria sintaxe de expressions e contexts;
- **GitLab CI/CD** possui seu próprio mecanismo de variables;
- **Kubernetes** não transforma automaticamente qualquer chave YAML em uma
  variável reutilizável.

Portanto, não existe uma sintaxe universal de "variável YAML".

### 11.6. Anchors não são variáveis

Os anchors e aliases apresentados anteriormente podem reutilizar estruturas,
mas não devem ser confundidos com variáveis.

```yaml
---
defaults: &defaults
  timeout: 30
  retries: 3

production:
  settings: *defaults
```

Nesse caso, `&defaults` e `*defaults` fazem parte dos mecanismos de composição
do YAML. Eles não realizam cálculos, condições ou interpolação de valores.

Uma forma simples de lembrar é:

```text
YAML            -> representa dados
Anchors/Aliases -> reutilizam nós YAML
Ansible/Jinja2  -> variáveis, expressões, filtros e operações
```


## 12. O que dá para fazer com YAML?

YAML é usado para descrever dados e configurações. Entre os usos mais comuns
estão:

- automação de infraestrutura;
- gerenciamento de configuração;
- infraestrutura como código;
- definição de aplicações em containers;
- manifests de orquestradores;
- pipelines CI/CD;
- configuração de aplicações;
- inventários de hosts;
- políticas e regras;
- configuração de ferramentas de observabilidade;
- arquivos de metadados;
- troca estruturada de dados entre sistemas.

É importante reforçar que YAML descreve os dados. A ferramenta que lê o arquivo
é quem define o significado e executa as ações.

## 13. Exemplo prático com Ansible

YAML é a principal forma de descrever playbooks do Ansible.

```yaml
---
- name: Configure web server
  hosts: webservers
  become: true

  vars:
    web_package: nginx

  tasks:
    - name: Install web server package
      ansible.builtin.package:
        name: "{{ web_package }}"
        state: present

    - name: Ensure service is running
      ansible.builtin.service:
        name: "{{ web_package }}"
        state: started
        enabled: true
```

Observe a combinação das estruturas:

- o documento principal é uma sequence;
- cada play é um mapping;
- `vars` é um mapping;
- `tasks` é uma sequence;
- cada task é um mapping;
- os parâmetros de cada módulo também formam mappings.

O YAML, por si só, não instala pacotes nem inicia serviços. Quem realiza as
ações é o Ansible.

## 14. Outros usos comuns

### Kubernetes

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - name: nginx
      image: nginx:latest
```

### Docker Compose

```yaml
---
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
```

### GitHub Actions

```yaml
---
name: CI

on:
  push:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running tests"
```

Esses exemplos mostram uma característica importante: YAML define a estrutura
dos dados, enquanto cada ferramenta define quais chaves e valores possuem
significado para ela.

Um arquivo pode ser sintaticamente YAML válido e ainda estar incorreto para
Ansible, Kubernetes ou outra aplicação.

## 15. Boas práticas

Algumas práticas ajudam a tornar arquivos YAML mais legíveis e confiáveis:

- utilize espaços e nunca TAB para indentação;
- mantenha uma indentação consistente, normalmente com dois espaços;
- aprenda mappings antes de estruturas mais complexas envolvendo sequences;
- utilize `---` no início quando essa for a convenção do projeto;
- não considere `...` obrigatório;
- mantenha `---` e `...` como marcadores na primeira coluna;
- evite chaves duplicadas;
- utilize `true` e `false` para booleanos quando possível;
- coloque entre aspas valores que possam ser interpretados de forma ambígua;
- evite linhas excessivamente longas;
- utilize comentários para explicar decisões importantes;
- mantenha nomes de chaves consistentes;
- prefira estruturas simples a níveis excessivos de aninhamento;
- utilize anchors e aliases somente quando melhorarem a leitura;
- não confunda recursos da ferramenta com recursos do YAML;
- em Ansible, use nomes de variáveis claros e consistentes;
- mantenha expressões Jinja2 simples quando possível;
- valide os arquivos antes de colocá-los em produção;
- execute um linter no pipeline de CI/CD.

## 16. yamllint

`yamllint` é uma ferramenta que analisa arquivos YAML procurando problemas de
sintaxe e de estilo.

Ele consegue detectar, entre outros problemas:

- erros de indentação;
- espaços desnecessários no final das linhas;
- linhas muito longas;
- chaves duplicadas;
- problemas em sequences e mappings;
- comentários mal formatados;
- ausência do marcador inicial `---`, dependendo da configuração;
- violações das regras de estilo definidas pelo projeto.

É importante observar que `yamllint` valida principalmente YAML e suas regras
de estilo. Ele não substitui validadores específicos da aplicação.

Por exemplo:

```text
yamllint    -> valida sintaxe e estilo YAML
ansible-lint -> valida boas práticas e estruturas do Ansible
kubectl      -> pode validar manifests Kubernetes
```

Um playbook pode passar no `yamllint` e ainda conter uma opção inválida para
um módulo do Ansible.

## 17. Instalando o yamllint no Debian

Em Debian e distribuições derivadas:

```bash
sudo apt update
sudo apt install yamllint
```

Depois da instalação:

```bash
yamllint --version
```

## 18. Instalando o yamllint em Red Hat

Em sistemas da família Red Hat que disponibilizam o pacote:

```bash
sudo dnf install yamllint
```

Em algumas versões do RHEL e derivados, o pacote pode depender do repositório
EPEL. Nesse caso, habilite o EPEL compatível com a versão do sistema e depois
execute:

```bash
sudo dnf install yamllint
```

Outra opção é instalar o `yamllint` em um ambiente Python isolado. Por exemplo,
com `pipx`:

```bash
pipx install yamllint
```

Para ambientes corporativos, prefira os métodos e repositórios homologados
pela organização.

## 19. Utilizando o yamllint

Para verificar um arquivo:

```bash
yamllint arquivo.yaml
```

Para verificar vários arquivos:

```bash
yamllint arquivo1.yaml arquivo2.yaml
```

Para verificar todos os arquivos YAML a partir do diretório atual:

```bash
yamllint .
```

Exemplo de arquivo com problemas:

```yaml
name: web01
packages:
   - nginx
   - git
```

O `yamllint` pode apontar problemas como ausência do marcador inicial e
indentação fora do padrão esperado.

## 20. Arquivo de configuração `.yamllint`

É possível definir as regras adotadas por um projeto utilizando um arquivo
`.yamllint`.

Exemplo:

```yaml
---
extends: default

rules:
  indentation:
    spaces: 2
    indent-sequences: true

  line-length:
    max: 100
    level: warning

  document-start:
    present: true

  document-end:
    present: false

  truthy:
    allowed-values:
      - "true"
      - "false"
```

Com esse arquivo no diretório do projeto:

```bash
yamllint .
```

Também é possível indicar explicitamente o arquivo de configuração:

```bash
yamllint -c .yamllint arquivo.yaml
```

Nesse exemplo, o projeto exige `---` no início, mas não exige `...` no final.

## 21. Uso do yamllint em CI/CD

Uma das melhores formas de utilizar `yamllint` é executá-lo automaticamente
antes que uma alteração seja aceita no repositório.

O fluxo pode ser:

```text
Developer
    |
    v
Git commit / Merge Request
    |
    v
yamllint
    |
    +---- error ----> Pipeline fails
    |
    +---- success --> Continue pipeline
```

Em um pipeline simples:

```bash
yamllint .
```

Se o comando retornar erro, o pipeline pode impedir que a configuração
incorreta seja promovida para outro ambiente.

Esse modelo é especialmente útil para repositórios contendo:

- playbooks Ansible;
- roles Ansible;
- manifests Kubernetes;
- pipelines CI/CD;
- arquivos Docker Compose;
- configurações de aplicações.

## 22. YAML válido não significa configuração válida

Considere o seguinte exemplo:

```yaml
---
server:
  name: web01
  port: 99999
```

O YAML está sintaticamente correto. Porém, uma aplicação pode considerar a
porta `99999` inválida.

O mesmo conceito se aplica ao Ansible:

```yaml
---
- name: Example
  hosts: servers
  tasks:
    - name: Install package
      ansible.builtin.package:
        name: nginx
        state: banana
```

O arquivo pode ser YAML válido, mas `banana` não representa um estado válido
para esse módulo.

Portanto, normalmente existem dois níveis de validação:

1. **Sintaxe e estilo YAML**: `yamllint`;
2. **Semântica da aplicação**: ferramentas específicas, como `ansible-lint`.

## 23. Resumo

Os principais pontos desta introdução são:

- YAML representa dados estruturados;
- scalar é um valor simples;
- mapping representa pares de chave e valor;
- sequence representa uma lista ordenada;
- mappings podem conter outros mappings;
- mappings podem conter sequences;
- sequences podem conter mappings;
- a indentação define a hierarquia;
- comentários começam com `#`;
- `|` preserva quebras de linha;
- `>` trata várias linhas como um texto dobrado;
- `---` marca explicitamente o início de um documento;
- `...` marca explicitamente o fim de um documento;
- `---` e `...` não são obrigatórios em todos os arquivos;
- YAML, por si só, não possui variáveis nem executa operações;
- aplicações como Ansible podem interpretar valores YAML como variáveis;
- no Ansible, Jinja2 permite referências, cálculos, comparações e filtros;
- anchors e aliases reutilizam estruturas, mas não são variáveis;
- `yamllint` ajuda a validar sintaxe e estilo;
- ferramentas como Ansible e Kubernetes acrescentam regras próprias sobre a
  estrutura YAML.

## Referências

- YAML 1.2.2 Specification: https://yaml.org/spec/1.2.2/
- yamllint documentation: https://yamllint.readthedocs.io/
- yamllint Quickstart: https://yamllint.readthedocs.io/en/latest/quickstart.html
