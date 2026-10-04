
ansible.cfg

$ANSIBLE_CONFIG -> ./ansible.cfg -> ~/.ansible.cfg -> /etc/ansible/ansible.cfg


Comandos ad hoc

sudo apt install python3-argcomplete bash-completion
sudo dnf install python3-argcomplete bash-completion

activate-global-python-argcomplete --user

source ~/.bash_completion


cat << EOF > hosts
192.168.56.10
192.168.56.20
EOF


ansible -i hosts all -u tux -m ping

[WARNING]: Host '192.168.56.10' is using the discovered Python interpreter at '/usr/bin/python3.13', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
[WARNING]: sftp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
[WARNING]: scp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
192.168.56.10 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
[WARNING]: Host '192.168.56.20' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
192.168.56.20 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.9"
    },
    "changed": false,
    "ping": "pong"
}


ansible -i hosts all -u tux -m ping --list-hosts 
  hosts (2):
    192.168.56.10
    192.168.56.20

    
cat << EOF > hosts
[debian]
192.168.56.10

[rh]
192.168.56.20
EOF
    
ansible debian -i hosts -u tux -m ping --list-hosts 
  hosts (1):
    192.168.56.10

    
ansible debian -i hosts -m ping --list-hosts 
  hosts (1):
    192.168.56.10    
    
ansible all -a pwd
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'

ansible all -i hosts -a pwd
[WARNING]: Host '192.168.56.10' is using the discovered Python interpreter at '/usr/bin/python3.13', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
[WARNING]: sftp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
[WARNING]: scp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
192.168.56.10 | CHANGED | rc=0 >>
/home/tux
[WARNING]: Host '192.168.56.20' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
192.168.56.20 | CHANGED | rc=0 >>
/home/tux


cat << EOF > ansible.cfg
[defaults]
inventory = ./hosts
EOF


ansible-config validate ansible.cfg 
All configurations seem valid!

cat ansible.cfg 
[defaults]
inventory = ./hosts


ansible all -m shell -a '/sbin/reboot'
[WARNING]: Host '192.168.56.10' is using the discovered Python interpreter at '/usr/bin/python3.13', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
[WARNING]: sftp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
[WARNING]: scp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
[ERROR]: Task failed: Module failed: non-zero return code
Origin: <adhoc 'shell' task>

{'action': 'shell', 'args': {'_raw_params': '/sbin/reboot'}, 'timeout': 0, 'async_val': 0, 'poll': 15}

192.168.56.10 | FAILED | rc=1 >>
Call to Reboot failed: Interactive authentication required.non-zero return code
[WARNING]: Host '192.168.56.20' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
192.168.56.20 | FAILED | rc=1 >>
Call to Reboot failed: Interactive authentication required.non-zero return code


ansible all -m shell -a '/sbin/reboot' -b
[WARNING]: Host '192.168.56.10' is using the discovered Python interpreter at '/usr/bin/python3.13', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
[WARNING]: sftp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
[WARNING]: scp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
[ERROR]: Task failed: Failed to connect to the host via ssh: Shared connection to 192.168.56.10 closed.
Origin: <adhoc 'shell' task>

{'action': 'shell', 'args': {'_raw_params': '/sbin/reboot'}, 'timeout': 0, 'async_val': 0, 'poll': 15}

192.168.56.10 | UNREACHABLE! => {
    "changed": false,
    "msg": "Task failed: Failed to connect to the host via ssh: Shared connection to 192.168.56.10 closed.",
    "unreachable": true
}
[WARNING]: Host '192.168.56.20' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
[ERROR]: Task failed: Failed to connect to the host via ssh: Shared connection to 192.168.56.20 closed.
Origin: <adhoc 'shell' task>

{'action': 'shell', 'args': {'_raw_params': '/sbin/reboot'}, 'timeout': 0, 'async_val': 0, 'poll': 15}

192.168.56.20 | UNREACHABLE! => {
    "changed": false,
    "msg": "Task failed: Failed to connect to the host via ssh: Shared connection to 192.168.56.20 closed.",
    "unreachable": true
}


ansible all -a pwd
[WARNING]: Host '192.168.56.10' is using the discovered Python interpreter at '/usr/bin/python3.13', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
[WARNING]: sftp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
[WARNING]: scp transfer mechanism failed on [192.168.56.10]. Use ANSIBLE_DEBUG=1 to see detailed information
192.168.56.10 | CHANGED | rc=0 >>
/home/tux
[WARNING]: Host '192.168.56.20' is using the discovered Python interpreter at '/usr/bin/python3.9', but future installation of another Python interpreter could cause a different interpreter to be discovered. See https://docs.ansible.com/ansible-core/2.19/reference_appendices/interpreter_discovery.html for more information.
192.168.56.20 | CHANGED | rc=0 >>
/home/tux


ansible rh -m dnf -a 'name=* state=latest' -b

. . .


ansible debian -m apt -a 'name=* state=latest' -b

. . .


ansible debian -m systemd -a 'name=ssh state=restarted' -b


ansible all -m copy -a 'src=./ansible.cfg dest=/tmp'


ansible all -m copy -a 'src=./ansible.cfg dest=/tmp mode=0600 owner=tux'


ansible localhost -m debug -a "msg={{ '123' | password_hash('sha512', 'secretsakt') }}"
localhost | SUCCESS => {
    "msg": "$6$rounds=656000$secretsakt$NEzmlV8MHLprPvpanKWeMQA6oiEua9WjjbpysnHghRVqDgIAAbyhmQm.TVbr9HMGL.DqEt2g6twfFXv5iTt5s1"
}


ansible all -m user -a "name=test password='$6$rounds=656000$secretsakt$NEzmlV8MHLprPvpanKWeMQA6oiEua9WjjbpysnHghRVqDgIAAbyhmQm.TVbr9HMGL.DqEt2g6twfFXv5iTt5s1'" -b


ansible all -m user -a "name=test state='absent'" -b



ansible-doc dnf


ansible-doc --list


ansible-doc --list | grep 'postgres' | wc -l
44


Facts

ansible-doc setup

ansible-doc setup

ansible all -m setup -a 'filter=ansible_architecture' 

ansible all -m setup -a 'filter=ansible_architecture' | grep ansible_architecture
        "ansible_architecture": "x86_64",
        "ansible_architecture": "x86_64",
        
ansible all -m setup -a 'filter=ansible_all_ipv4_addresses'         

ansible all -m setup -a 'filter=ansible_all_ipv4_addresses,ansible_all_ipv6_addresses'


Inventory file

Pode passar mais de um arquivo `-i`.







    
