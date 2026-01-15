#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PYTHON="/usr/bin/python3"
SCRIPT="/apps/mdw-reporting/dpi_reports/bitbucket_repos/csv_upload/csv2ini.py"
CSV_DIR="/apps/mdw-reporting/dpi_reports/csv"
OUT_DIR="/apps/mdw-reporting/dpi_reports/bitbucket_repos/csv_upload/inventories"
LOG_DIR="/apps/mdw-reporting/dpi_reports/logs"

declare -A TMP_FILES

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

for csv_path in "${CSV_DIR}"/*.csv; do
  csv_name=$(basename "${csv_path}")

  [[ "${csv_name}" == "dpi_global.csv" ]] && continue

  target=$(get_target "${csv_name}")
  [[ "${target}" == "unknown" ]] && continue

  if [[ -z "${TMP_FILES[${target}]+_}" ]]; then
    TMP_FILES[${target}]=$(mktemp)
  fi

  timestamp=$(date '+%Y%m%d_%H%M%S')
  log_file="${LOG_DIR}/${target}_${timestamp}.log"

  "${PYTHON}" "${SCRIPT}" "${csv_path}" \
    >> "${TMP_FILES[${target}]}" 2>> "${log_file}" || {
      echo "ERROR: conversion failed for ${csv_name}" >> "${log_file}"
    }
done

for target in "${!TMP_FILES[@]}"; do
  tmp="${TMP_FILES[$target]}"
  if [[ -s "${tmp}" ]]; then
    mv "${tmp}" "${OUT_DIR}/${target}.ini"
  else
    rm -f "${tmp}"
  fi
done
