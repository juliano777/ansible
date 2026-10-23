#!/usr/bin/env bash
# Renomeia os capítulos da apostila de Ansible para a sequência <NN>-<assunto>.md
#
# Uso (dentro da pasta com os arquivos .md):
#   ./renomear_apostila.sh                              # SIMULAÇÃO: só mostra os comandos
#   DRY_RUN=0 ./renomear_apostila.sh                    # executa de verdade
#   MV="git mv" DRY_RUN=0 ./renomear_apostila.sh        # executa usando git mv
#
# Para desfazer (depois de executar de verdade), o próprio script gera:
#   ./desfazer_renomeacao.sh
#
# Observações:
#   - Arquivos da lista que não existirem são ignorados, e a numeração continua
#     sem lacunas (ex.: se role_tests.md não existir, galaxy.md ocupa o seu número).
#   - O script não sobrescreve nada: se algum destino já existir, aborta antes de mover.

set -euo pipefail
shopt -s nullglob

DRY_RUN="${DRY_RUN:-1}"
MV="${MV:-mv -n}"
DESFAZER="desfazer_renomeacao.sh"

read -r -a CMD <<< "$MV"

# ----------------------------------------------------------------------------
# A ORDEM DE ESTUDO (sem a numeração e sem a extensão .md)
# ----------------------------------------------------------------------------
ORDEM=(
  # Parte 1: Primeiros passos
  ansible_clients
  inventory_files
  ansible_cfg
  ad-hoc
  ansible_doc

  # Parte 2: Playbooks
  introducao_yaml
  playbooks
  ansible_playbook_structure
  collections

  # Parte 3: Variáveis, facts e dados
  variables
  runtime-vars
  vars_prompts
  playbooks_prompts
  facts
  ansible_inventory
  register_outputs
  filters

  # Parte 4: Controle de fluxo
  conditionals
  stat
  loops
  with_items
  with_sequence
  loop_control
  loop_inner
  blocks
  tags
  handlers
  delegate_to

  # Parte 5: Segredos, console e reuso
  vault
  ansible_console
  roles
  role_tests
  galaxy
  plugins
  ansible_python_api
)

# ----------------------------------------------------------------------------
# 1ª passada: montar o plano e verificar colisões (nada é movido ainda)
# ----------------------------------------------------------------------------
ORIGENS=()
DESTINOS=()
n=0

for nome in "${ORDEM[@]}"; do
  origem="${nome}.md"
  if [[ ! -f "$origem" ]]; then
    echo "AVISO: '$origem' não encontrado; ignorado (a numeração segue sem lacunas)" >&2
    continue
  fi
  destino="$(printf '%02d-%s.md' "$n" "$nome")"
  if [[ -e "$destino" ]]; then
    echo "ERRO: o destino '$destino' já existe. Nada foi alterado." >&2
    exit 1
  fi
  ORIGENS+=("$origem")
  DESTINOS+=("$destino")
  n=$((n + 1))
done

if [[ ${#ORIGENS[@]} -eq 0 ]]; then
  echo "Nenhum arquivo da lista foi encontrado nesta pasta." >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 2ª passada: mostrar (e, se DRY_RUN=0, executar) os comandos
# ----------------------------------------------------------------------------
if [[ "$DRY_RUN" == "0" ]]; then
  printf '#!/usr/bin/env bash\n# Gerado automaticamente: desfaz a renomeação.\nset -eu\n' > "$DESFAZER"
else
  echo "# SIMULAÇÃO: nada será alterado. Use DRY_RUN=0 para executar."
fi

for i in "${!ORIGENS[@]}"; do
  echo "${CMD[*]} -- ${ORIGENS[$i]} ${DESTINOS[$i]}"
  if [[ "$DRY_RUN" == "0" ]]; then
    "${CMD[@]}" -- "${ORIGENS[$i]}" "${DESTINOS[$i]}"
    printf '%s -- %q %q\n' "${CMD[*]}" "${DESTINOS[$i]}" "${ORIGENS[$i]}" >> "$DESFAZER"
  fi
done

# ----------------------------------------------------------------------------
# Relatório: arquivos .md que ficaram fora da lista
# ----------------------------------------------------------------------------
echo
echo "Arquivos .md que NÃO estão na lista (não foram renomeados):"
fora=0
for f in *.md; do
  [[ "$f" == "README.md" ]] && continue
  [[ "$f" =~ ^[0-9]{2}- ]] && continue
  nome="${f%.md}"
  encontrado=0
  for o in "${ORDEM[@]}"; do
    [[ "$o" == "$nome" ]] && encontrado=1
  done
  if [[ $encontrado -eq 0 ]]; then
    echo "  $f"
    fora=$((fora + 1))
  fi
done
[[ $fora -eq 0 ]] && echo "  (nenhum)"

if [[ "$DRY_RUN" == "0" ]]; then
  echo
  chmod +x "$DESFAZER"
  echo "Concluído: ${#ORIGENS[@]} arquivos renomeados. Para desfazer: ./$DESFAZER"
fi
