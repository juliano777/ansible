#!/usr/bin/env bash
# Gerado automaticamente: desfaz a renomeação.
set -eu
mv -n -- 00-ansible_clients.md ansible_clients.md
mv -n -- 01-inventory_files.md inventory_files.md
mv -n -- 02-ansible_cfg.md ansible_cfg.md
mv -n -- 03-ad-hoc.md ad-hoc.md
mv -n -- 04-ansible_doc.md ansible_doc.md
mv -n -- 05-introducao_yaml.md introducao_yaml.md
mv -n -- 06-playbooks.md playbooks.md
mv -n -- 07-ansible_playbook_structure.md ansible_playbook_structure.md
mv -n -- 08-collections.md collections.md
mv -n -- 09-variables.md variables.md
mv -n -- 10-runtime-vars.md runtime-vars.md
mv -n -- 11-vars_prompts.md vars_prompts.md
mv -n -- 12-playbooks_prompts.md playbooks_prompts.md
mv -n -- 13-facts.md facts.md
mv -n -- 14-ansible_inventory.md ansible_inventory.md
mv -n -- 15-register_outputs.md register_outputs.md
mv -n -- 16-filters.md filters.md
mv -n -- 17-conditionals.md conditionals.md
mv -n -- 18-stat.md stat.md
mv -n -- 19-loops.md loops.md
mv -n -- 20-with_items.md with_items.md
mv -n -- 21-with_sequence.md with_sequence.md
mv -n -- 22-loop_control.md loop_control.md
mv -n -- 23-loop_inner.md loop_inner.md
mv -n -- 24-blocks.md blocks.md
mv -n -- 25-tags.md tags.md
mv -n -- 26-handlers.md handlers.md
mv -n -- 27-delegate_to.md delegate_to.md
mv -n -- 28-vault.md vault.md
mv -n -- 29-ansible_console.md ansible_console.md
mv -n -- 30-roles.md roles.md
mv -n -- 31-galaxy.md galaxy.md
mv -n -- 32-plugins.md plugins.md
mv -n -- 33-ansible_python_api.md ansible_python_api.md
