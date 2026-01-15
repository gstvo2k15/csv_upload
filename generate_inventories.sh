#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PYTHON="/usr/bin/python3"
SCRIPT="$PWD/csv2ini.py"
CSV_DIR="$PWD/csv"
OUT_DIR="$PWD/inventories"
LOG_DIR="/apps/mdw-reporting/dpi_reports/logs"
COUNT_AWK="$PWD/ini_section_counts.awk"

declare -A TMP_CSV
declare -A SRC_COUNT

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
  for t in "${!TMP_CSV[@]}"; do
    rm -f "${TMP_CSV[$t]}" 2>/dev/null || true
  done
}
trap cleanup EXIT

RUN_TS="$(date '+%Y%m%d_%H%M%S')"

for csv_path in "${CSV_DIR}"/*.csv; do
  csv_name="$(basename "${csv_path}")"
  [[ "${csv_name}" == "dpi_global.csv" ]] && continue

  target="$(get_target "${csv_name}")"
  [[ "${target}" == "unknown" ]] && continue

  if [[ -z "${TMP_CSV[${target}]+_}" ]]; then
    TMP_CSV["${target}"]="$(mktemp)"
    SRC_COUNT["${target}"]=0
  fi

  if [[ "${SRC_COUNT[${target}]}" -eq 0 ]]; then
    cat "${csv_path}" >> "${TMP_CSV[${target}]}"
  else
    tail -n +2 "${csv_path}" >> "${TMP_CSV[${target}]}"
  fi

  SRC_COUNT["${target}"]=$(( SRC_COUNT["${target}"] + 1 ))
done

for target in "${!TMP_CSV[@]}"; do
  tmp_csv="${TMP_CSV[$target]}"
  out_file="${OUT_DIR}/${target}.ini"
  log_file="${LOG_DIR}/${target}_${RUN_TS}.log"

  if [[ ! -s "${tmp_csv}" ]]; then
    echo "INFO: unified CSV empty for ${target} -> inventory not created" >> "${log_file}"
    continue
  fi

  {
    echo "INFO: target=${target} sources=${SRC_COUNT[$target]} unified_csv=${tmp_csv}"
  } >> "${log_file}"

  "${PYTHON}" "${SCRIPT}" "${tmp_csv}" > "${out_file}" 2>> "${log_file}" || {
    echo "ERROR: conversion failed for target=${target}" >> "${log_file}"
  }

  if [[ ! -s "${out_file}" ]]; then
    rm -f "${out_file}"
    echo "INFO: inventory for ${target} was empty -> file removed" >> "${log_file}"
    continue
  fi

  {
    echo
    echo "INFO: inventory created: ${out_file}"
    echo "INFO: VM count per group (excluding :children/:vars) for ${target}.ini"
    awk -f "${COUNT_AWK}" "${out_file}" | sort
    total="$(awk -f "${COUNT_AWK}" "${out_file}" | awk '{s+=$2} END{print s+0}')"
    echo "INFO: TOTAL VMs for ${target}.ini = ${total}"
    echo
  } | tee -a "${log_file}"
done
