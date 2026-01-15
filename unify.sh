#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PYTHON="/usr/bin/python3"
SCRIPT="$PWD/csv2ini.py"
CSV_DIR="$PWD/csv"
OUT_DIR="$PWD/inventories"
LOG_DIR="/apps/mdw-reporting/dpi_reports/logs"

# Counts hosts per INI section, ignoring :children and :vars
COUNT_AWK="$PWD/ini_section_counts.awk"

declare -A TMP_FILES
declare -A TARGET_LOGS

get_target() {
  local f=$1
  case "$f" in
    dpi_apache_sso*|dpi_apache_sso_ibm_vdc*) echo "sso" ;;
    dpi_apache*|dpi_apache_csa*)            echo "apache" ;;
    dpi_tomcat*|dpi_upgraded_jboss_ews*|dpi_jboss_ews*|dpi_jboss_EWS*) echo "tomcat" ;;
    dpi_iis*|dpi_iis_vpc*)                  echo "iis" ;;
    dpi_was*)                               echo "was" ;;
    dpi_weblogic*)                          echo "weblogic" ;;
    dpi_jbossEAP*)                          echo "jbossap" ;;
    *)                                      echo "unknown" ;;
  esac
}

cleanup() {
  for t in "${!TMP_FILES[@]}"; do
    rm -f "${TMP_FILES[$t]}" 2>/dev/null || true
  done
}
trap cleanup EXIT

mkdir -p "${OUT_DIR}" "${LOG_DIR}"

# One execution timestamp for all outputs/logs in this run
RUN_TS="$(date '+%Y%m%d_%H%M%S')"

for csv_path in "${CSV_DIR}"/*.csv; do
  csv_name="$(basename "${csv_path}")"
  [[ "${csv_name}" == "dpi_global.csv" ]] && continue

  target="$(get_target "${csv_name}")"
  [[ "${target}" == "unknown" ]] && continue

  # One tmp per target
  if [[ -z "${TMP_FILES[${target}]+_}" ]]; then
    TMP_FILES["${target}"]="$(mktemp)"
  fi

  # One log per target per run
  if [[ -z "${TARGET_LOGS[${target}]+_}" ]]; then
    TARGET_LOGS["${target}"]="${LOG_DIR}/${target}_${RUN_TS}.log"
  fi
  log_file="${TARGET_LOGS[${target}]}"

  {
    echo "INFO: source csv=${csv_name}"
  } >> "${log_file}"

  # Append INI output into the target tmp
  "${PYTHON}" "${SCRIPT}" "${csv_path}" \
    >> "${TMP_FILES[${target}]}" 2>> "${log_file}" || {
      echo "ERROR: conversion failed for ${csv_name}" >> "${log_file}"
    }
done

for target in "${!TMP_FILES[@]}"; do
  tmp="${TMP_FILES[$target]}"
  out_file="${OUT_DIR}/${target}.ini"
  log_file="${TARGET_LOGS[$target]:-${LOG_DIR}/${target}_${RUN_TS}.log}"

  if [[ -s "${tmp}" ]]; then
    mv -f "${tmp}" "${out_file}"

    {
      echo
      echo "INFO: inventory created: ${out_file}"
      echo "INFO: VM count per group (excluding :children/:vars) for ${target}.ini"
      awk -f "${COUNT_AWK}" "${out_file}" | sort
      total="$(awk -f "${COUNT_AWK}" "${out_file}" | awk '{s+=$2} END{print s+0}')"
      echo "INFO: TOTAL VMs for ${target}.ini = ${total}"
      echo
    } | tee -a "${log_file}"

    if [[ ! -s "${out_file}" ]]; then
      rm -f "${out_file}"
      echo "INFO: inventory for ${target} was empty -> file removed" | tee -a "${log_file}"
    fi
  else
    rm -f "${tmp}"
    echo "INFO: inventory for ${target} empty -> not created" >> "${log_file}"
  fi
done
