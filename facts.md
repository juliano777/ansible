# Capítulo: Facts no Ansible

## 1. O que são facts

Facts são informações que o Ansible coleta automaticamente sobre cada host gerenciado: sistema operacional, versão, memória, CPUs, interfaces de rede, discos, kernel, gerenciador de pacotes e muito mais.

Eles permitem que o mesmo playbook se comporte de forma diferente conforme a máquina em que roda, sem você precisar informar nada manualmente. Foi o que fizemos nos exemplos anteriores, ao usar `ansible_os_family` para escolher entre `apt` e `dnf`.

Facts são **variáveis**: tudo o que foi visto no capítulo de variáveis vale para eles (uso em Jinja2, `when`, templates, `debug` etc.).

---

## 2. Como os facts são coletados

Por padrão, no início de cada play o Ansible executa uma task implícita chamada **Gathering Facts**, que roda o módulo `ansible.builtin.setup` em cada host.

```yaml
---
- name: Exemplo com facts
  hosts: all
  gather_facts: true      # é o padrão

  tasks:
    - name: Mostrar a família do SO
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} é {{ ansible_facts['os_family'] }}"
```

Quando você escreve `gather_facts: false`, essa etapa é pulada, o playbook inicia mais rápido, mas os facts **não existem**. Foi exatamente o problema do `ansible_hostname` no seu primeiro playbook.

### 2.1 Coleta manual com o módulo `setup`

Se desativou a coleta automática mas precisa dos facts em um ponto específico:

```yaml
---
- name: Coleta sob demanda
  hosts: all
  gather_facts: false

  tasks:
    - name: Coletar facts agora
      ansible.builtin.setup:

    - name: Usar um fact
      ansible.builtin.debug:
        msg: "{{ ansible_facts['distribution'] }}"
```

### 2.2 Coleta em linha de comando (ad-hoc)

Excelente para descobrir quais facts existem e quais são seus nomes:

```bash
# Todos os facts de um host
ansible deb00 -i hosts -m ansible.builtin.setup

# Apenas os facts que casam com um padrão
ansible deb00 -i hosts -m ansible.builtin.setup -a "filter=ansible_distribution*"
```

### 2.3 Vendo todos os facts dentro de um playbook

```yaml
- name: Mostrar todos os facts
  ansible.builtin.debug:
    var: ansible_facts
```

---

## 3. Duas formas de acessar um fact

Existem dois estilos de nome para o mesmo valor:

| Estilo | Exemplo | Observação |
|---|---|---|
| Dicionário `ansible_facts` | `ansible_facts['os_family']` | **Recomendado**; sempre disponível |
| Prefixo `ansible_` | `ansible_os_family` | Funciona por padrão, mas depende da opção `inject_facts_as_vars` |

O estilo com prefixo é o mais encontrado em exemplos antigos e continua funcionando, porém o Ansible está caminhando para deixar o dicionário `ansible_facts` como forma principal. Para código novo, prefira:

```yaml
msg: "{{ ansible_facts['os_family'] }}"
msg: "{{ ansible_facts['default_ipv4']['address'] }}"
```

Note que, no dicionário, o nome **não** leva o prefixo `ansible_`.

---

## 4. Facts mais usados

| Fact (`ansible_facts[...]`) | Descrição | Exemplo |
|---|---|---|
| `os_family` | Família do sistema | `Debian`, `RedHat` |
| `distribution` | Distribuição | `Debian`, `Rocky`, `Ubuntu` |
| `distribution_version` | Versão completa | `12.5` |
| `distribution_major_version` | Versão principal | `12` |
| `hostname` | Nome curto do host | `deb00` |
| `fqdn` | Nome completo | `deb00.exemplo.com` |
| `kernel` | Versão do kernel | `6.1.0-21-amd64` |
| `architecture` | Arquitetura | `x86_64` |
| `pkg_mgr` | Gerenciador de pacotes | `apt`, `dnf` |
| `service_mgr` | Gerenciador de serviços | `systemd` |
| `default_ipv4.address` | IP principal | `192.168.1.10` |
| `interfaces` | Lista de interfaces | `['lo', 'eth0']` |
| `memtotal_mb` | Memória total (MB) | `3921` |
| `processor_vcpus` | Número de vCPUs | `4` |
| `mounts` | Lista de pontos de montagem | (lista de dicionários) |
| `date_time` | Data e hora da coleta | (dicionário) |
| `python_version` | Versão do Python no host | `3.11.2` |
| `virtualization_type` | Tipo de virtualização | `kvm`, `docker` |
| `selinux` | Estado do SELinux | (dicionário) |

> O conjunto exato varia conforme o sistema. Use o comando ad-hoc da seção 2.2 para confirmar o que existe no seu ambiente.

---

## 5. Usando facts

### 5.1 Em condições (`when`)

```yaml
- name: Atualizar cache (Debian)
  ansible.builtin.apt:
    update_cache: true
  when: ansible_facts['os_family'] == "Debian"

- name: Atualizar cache (Red Hat)
  ansible.builtin.dnf:
    update_cache: true
  when: ansible_facts['os_family'] == "RedHat"
```

Condições compostas:

```yaml
when:
  - ansible_facts['os_family'] == "RedHat"
  - ansible_facts['distribution_major_version'] | int >= 8
```

O filtro `| int` converte o texto em número, necessário para comparações numéricas, pois versões são coletadas como strings.

### 5.2 Em mensagens e templates

```yaml
- name: Resumo do host
  ansible.builtin.debug:
    msg: >-
      {{ ansible_facts['fqdn'] }} roda {{ ansible_facts['distribution'] }}
      {{ ansible_facts['distribution_version'] }}
      com {{ ansible_facts['processor_vcpus'] }} vCPUs
      e {{ ansible_facts['memtotal_mb'] }} MB de RAM.
```

### 5.3 Para escolher valores conforme o sistema

Combinando com dicionários (ver capítulo de variáveis):

```yaml
vars:
  pacote_web:
    Debian: apache2
    RedHat: httpd

tasks:
  - name: Instalar servidor web
    ansible.builtin.package:
      name: "{{ pacote_web[ansible_facts['os_family']] }}"
      state: present
```

### 5.4 Facts de outros hosts (`hostvars`)

É possível consultar os facts de **outro** host, desde que eles já tenham sido coletados na execução (ou estejam em cache):

```yaml
- name: IP do servidor de banco
  ansible.builtin.debug:
    msg: "{{ hostvars['deb00']['ansible_facts']['default_ipv4']['address'] }}"
```

Se o play tem `hosts: debian` e você consulta um host que não faz parte dele, os facts não terão sido coletados. Nesse caso, ou inclua o host em algum play anterior, ou use cache de facts (seção 8).

---

## 6. Controlando a coleta

Coletar todos os facts pode ser lento, especialmente com muitos hosts. Há duas formas de reduzir o trabalho.

### 6.1 `gather_subset`

Seleciona **quais grupos** de facts coletar:

```yaml
- name: Coleta enxuta
  hosts: all
  gather_facts: true
  gather_subset:
    - "!all"
    - "!min"
    - network
```

| Subconjunto | Conteúdo |
|---|---|
| `all` | Tudo |
| `min` | Básico (`os_family`, `distribution`, `hostname`, `pkg_mgr` e outros essenciais) |
| `network` | Interfaces, IPs, rotas |
| `hardware` | CPU, memória, discos, montagens (é o mais lento) |
| `virtual` | Informações de virtualização |
| `ohai`, `facter` | Facts de Ohai e Facter (se instalados) |

O prefixo `!` exclui o subconjunto. Um valor `["!all"]` mantém apenas o subconjunto `min`.

### 6.2 `filter` no módulo `setup`

Filtra por **nome** os facts retornados:

```yaml
- name: Coletar somente facts de distribuição
  ansible.builtin.setup:
    filter: ansible_distribution*
```

### 6.3 Desativando a coleta

Se o playbook não usa facts, desative:

```yaml
- hosts: all
  gather_facts: false
```

Em playbooks simples de diagnóstico ou que só executam comandos, isso economiza vários segundos por host.

> **Relação com tags:** a coleta de facts é independente de `--tags`. Mesmo rodando apenas uma tag, a etapa de coleta acontece (se `gather_facts` estiver ativo). Se precisa de rapidez ao filtrar por tags e não depende de facts, desative a coleta.

---

## 7. Facts personalizados

Você pode criar seus próprios facts em cada host. Eles aparecem em `ansible_local`.

### 7.1 Como funcionam

1. Crie arquivos com extensão `.fact` no diretório `/etc/ansible/facts.d/` do host.
2. O conteúdo pode ser **INI**, **JSON** ou um **executável** que imprime JSON.
3. O Ansible lê esses arquivos durante a coleta.
4. O acesso é `ansible_local.<nome_do_arquivo>.<seção>.<chave>`, ou `ansible_facts['ansible_local']`.

### 7.2 Exemplo: arquivo INI

`/etc/ansible/facts.d/aplicacao.fact`:

```ini
[geral]
ambiente=producao
responsavel=equipe-infra
```

Uso:

```yaml
- name: Mostrar o ambiente
  ansible.builtin.debug:
    msg: "Ambiente: {{ ansible_local['aplicacao']['geral']['ambiente'] }}"
```

### 7.3 Exemplo: criando o fact pelo próprio Ansible

```yaml
---
- name: Criar fact personalizado
  hosts: all
  become: true

  tasks:
    - name: Garantir diretório de facts
      ansible.builtin.file:
        path: /etc/ansible/facts.d
        state: directory
        mode: "0755"

    - name: Criar o fact
      ansible.builtin.copy:
        dest: /etc/ansible/facts.d/aplicacao.fact
        content: |
          [geral]
          ambiente=producao
          responsavel=equipe-infra
        mode: "0644"

    - name: Recoletar facts locais
      ansible.builtin.setup:
        filter: ansible_local

    - name: Mostrar
      ansible.builtin.debug:
        var: ansible_local
```

A task `setup` com `filter: ansible_local` é necessária porque a coleta automática já ocorreu **antes** da criação do arquivo.

### 7.4 Exemplo: fact dinâmico (script)

Um arquivo `.fact` executável que imprime JSON:

```bash
#!/bin/bash
echo "{\"usuarios_logados\": $(who | wc -l)}"
```

Salve como `/etc/ansible/facts.d/sessoes.fact` com permissão de execução. O valor ficará em `ansible_local['sessoes']['usuarios_logados']`.

---

## 8. Cache de facts

A coleta a cada execução pode ser cara. O cache permite reaproveitar facts coletados anteriormente, o que também viabiliza o uso de `hostvars` entre plays que não incluem todos os hosts.

Em `ansible.cfg`:

```ini
[defaults]
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400
```

| Opção | Efeito |
|---|---|
| `gathering = implicit` | Padrão: coleta sempre, a menos que `gather_facts: false` |
| `gathering = explicit` | Só coleta se o play pedir `gather_facts: true` |
| `gathering = smart` | Coleta uma vez por host e reutiliza o cache durante a execução |
| `fact_caching = jsonfile` | Salva os facts em arquivos JSON |
| `fact_caching_connection` | Diretório do cache |
| `fact_caching_timeout` | Validade em segundos (aqui, 24 horas) |

Outras opções de backend existem (como `redis` e `memory`), conforme a necessidade.

> Cuidado: facts em cache podem estar **desatualizados** (ex.: um pacote instalado ou IP alterado depois da última coleta). Ajuste o timeout conforme o quanto o dado pode envelhecer.

---

## 9. Criando facts durante a execução: `set_fact`

`set_fact` cria variáveis (chamadas "facts" porque ficam associadas ao host) em tempo de execução:

```yaml
- name: Calcular memória em GB
  ansible.builtin.set_fact:
    memoria_gb: "{{ (ansible_facts['memtotal_mb'] / 1024) | round(1) }}"

- name: Mostrar
  ansible.builtin.debug:
    msg: "{{ memoria_gb }} GB"
```

Por padrão, valem durante a execução atual. Para persistir no cache de facts (quando ele está ativo):

```yaml
- ansible.builtin.set_fact:
    ultima_atualizacao: "{{ ansible_facts['date_time']['iso8601'] }}"
    cacheable: true
```

---

## 10. Módulos que retornam facts

Além do `setup`, alguns módulos coletam facts específicos:

### 10.1 `package_facts`: pacotes instalados

```yaml
- name: Coletar pacotes instalados
  ansible.builtin.package_facts:
    manager: auto

- name: Verificar se o nginx está instalado
  ansible.builtin.debug:
    msg: "nginx versão {{ ansible_facts['packages']['nginx'][0]['version'] }}"
  when: "'nginx' in ansible_facts['packages']"
```

### 10.2 `service_facts`: serviços

```yaml
- name: Coletar serviços
  ansible.builtin.service_facts:

- name: Mostrar estado do ssh
  ansible.builtin.debug:
    msg: "{{ ansible_facts['services']['ssh.service']['state'] }}"
  when: "'ssh.service' in ansible_facts['services']"
```

O nome do serviço pode variar entre distribuições (`ssh.service` no Debian, `sshd.service` no Red Hat).

### 10.3 `stat`, `getent` e outros

Módulos como `ansible.builtin.stat` (arquivos) e `ansible.builtin.getent` (usuários, grupos) também registram dados utilizáveis, normalmente com `register`.

---

## 11. Exemplo completo

Relatório de inventário de hardware e sistema, funcionando em Debian e Red Hat:

```yaml
---
- name: Relatório de facts
  hosts: all
  gather_facts: true
  gather_subset:
    - "!all"
    - hardware
    - network

  tasks:
    - name: Resumo do servidor
      ansible.builtin.debug:
        msg:
          - "Host:    {{ ansible_facts['fqdn'] }}"
          - "SO:      {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}"
          - "Kernel:  {{ ansible_facts['kernel'] }}"
          - "CPUs:    {{ ansible_facts['processor_vcpus'] }}"
          - "RAM:     {{ ansible_facts['memtotal_mb'] }} MB"
          - "IP:      {{ ansible_facts['default_ipv4']['address'] | default('n/d') }}"
          - "Pacotes: {{ ansible_facts['pkg_mgr'] }}"
      tags: relatorio

    - name: Alerta de pouca memória
      ansible.builtin.debug:
        msg: "ATENÇÃO: {{ inventory_hostname }} tem menos de 2 GB de RAM"
      when: ansible_facts['memtotal_mb'] < 2048
      tags: alerta
```

Execução:

```bash
ansible-playbook -i hosts facts.yml
ansible-playbook -i hosts facts.yml --tags alerta --limit deb00,deb02
```

---

## 12. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `'ansible_hostname' is undefined` | `gather_facts: false` | Ativar a coleta ou chamar `setup` |
| Fact retorna vazio ou não existe | `gather_subset` excluiu o grupo | Incluir o subconjunto necessário |
| Comparação de versão falha | Valor vem como string | Usar `\| int` ou `is version(...)` |
| `hostvars` de outro host está indefinido | Facts do host não foram coletados | Incluir o host em um play anterior ou usar cache |
| Fact customizado não aparece | Coleta ocorreu antes da criação do arquivo | Rodar `setup` com `filter: ansible_local` |
| `default_ipv4` indefinido | Host sem rota padrão ou subconjunto `network` ausente | Usar `\| default(...)` e verificar o subset |
| Lentidão na coleta | Subconjunto `hardware` em muitos hosts | Restringir com `gather_subset` ou usar cache |

---

## 13. Boas práticas

1. **Prefira `ansible_facts['nome']`** ao estilo com prefixo `ansible_`.
2. **Desative a coleta** quando o playbook não usa facts.
3. **Restrinja com `gather_subset`** quando precisa de poucos dados.
4. **Use cache de facts** em ambientes grandes, definindo um timeout coerente.
5. **Use `default()`** ao acessar facts que podem não existir em todos os sistemas.
6. **Use `os_family`** para decisões amplas (Debian × Red Hat) e `distribution` e `distribution_major_version` para diferenças pontuais entre versões.
7. **Converta versões** com `| int` ou use o teste `version`:

```yaml
when: ansible_facts['distribution_version'] is version('9', '>=')
```

8. **Use facts personalizados** para metadados do próprio ambiente (função do servidor, ambiente, responsável), em vez de espalhar essas informações em vários lugares.
9. **Descubra antes de usar:** rode `setup` ad-hoc para conferir nomes e estrutura dos facts no seu ambiente.

---

## Resumo

| Necessidade | Recurso |
|---|---|
| Coletar facts automaticamente | `gather_facts: true` (padrão) |
| Coletar em um ponto específico | Módulo `ansible.builtin.setup` |
| Ver os facts existentes | `ansible -m setup` ou `debug: var=ansible_facts` |
| Reduzir o que é coletado | `gather_subset` ou `filter` |
| Não coletar | `gather_facts: false` |
| Criar fact em cada host | Arquivos em `/etc/ansible/facts.d/*.fact` |
| Criar fact em tempo de execução | `set_fact` |
| Reaproveitar facts entre execuções | `fact_caching` no `ansible.cfg` |
| Ler facts de outro host | `hostvars['host']['ansible_facts'][...]` |
| Lista de pacotes e serviços | `package_facts` e `service_facts` |
