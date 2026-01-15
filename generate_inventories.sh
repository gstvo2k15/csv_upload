#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

PYTHON="/usr/bin/python3"
SCRIPT="/apps/mdw-reporting/dpi_reports/elastic_inventory/csv2ini.py"
CSV_DIR="/apps/mdw-reporting/dpi_reports/csv"

OUT_DIR="/apps/mdw-reporting/dpi_reports/elastic_inventory/inventories"
LOG_DIR="/apps/mdw-reporting/dpi_reports/logs"

COUNT_AWK="/apps/mdw-reporting/dpi_reports/elastic_inventory/ini_section_counts.awk"

for CSV_PATH in "${CSV_DIR}"/*.csv; do
    CSV_BASENAME="$(basename "${CSV_PATH}")"

    if [[ "${CSV_BASENAME}" == "dpi_global.csv" ]]; then
        continue
    fi

    CSV_NO_EXT="${CSV_BASENAME%.*}"
    if [[ "${CSV_NO_EXT}" == dpi_* ]]; then
        PRODUCT="${CSV_NO_EXT#dpi_}"
    else
        PRODUCT="${CSV_NO_EXT}"
    fi

    PRODUCT_LC="${PRODUCT,,}"

    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    OUT_FILE="${OUT_DIR}/${PRODUCT_LC}.ini"
    LOG_FILE="${LOG_DIR}/${PRODUCT_LC}_${TIMESTAMP}.log"

    "${PYTHON}" "${SCRIPT}" "${CSV_PATH}" \
        > "${OUT_FILE}" 2>> "${LOG_FILE}" || {
            echo "ERROR: conversion failed for ${CSV_BASENAME}" >> "${LOG_FILE}"
        }

    if [[ ! -s "${OUT_FILE}" ]]; then
        rm -f "${OUT_FILE}"
        echo "INFO: inventory for ${PRODUCT} was empty -> file removed" >> "${LOG_FILE}"
        continue
    fi

    {
        echo "INFO: VM count per group (excluding :children/:vars) for ${PRODUCT_LC}"
        awk -f "${COUNT_AWK}" "${OUT_FILE}" | sort
    } >> "${LOG_FILE}"

done
