#!/bin/bash

DST_FOLDER=/apps/dpi-reports/reports/csv
timereport=$(date +"%d/%m/%Y-%H:%Mh")

list_env=("DEV" "STG" "PRD")
list_reg=("EMEA" "APAC" "AMER")

usage() {
  cat <<'EOF'
usage:
  ./dpi.sh --global
  ./dpi.sh --all
  ./dpi.sh --report <name>
  ./dpi.sh --help

reports:
  apache
  apache_csa
  iis
  iis_vpc
  jbosseap
  jbossews
  tomcat
  tomcat_ibmcloud
  weblogic
  was
  sso
  sso_ibm_vdc
  global

notes:
  --global  -> generate only dpi_global.csv (single file for all product)
  --all     -> generate all CSV individually and also including dpi_global.csv
EOF
  exit 0
}

die(){ echo "$*" >&2; exit 1; }

init_csv() {
  local out="$1" header="$2"
  echo "$header" | sudo tee "$DST_FOLDER/$out" > /dev/null
}

append_products() {
  local out="$1" profile="$2" mode="$3"
  shift 3
  local -a prods=("$@")

  for product in "${prods[@]}"; do
    echo -e "\n### Starting csv for $product at $timereport ###"
    for environment in "${list_env[@]}"; do
      for region in "${list_reg[@]}"; do
        ./list-vm-unified.sh \
          -environment "$environment" \
          -region "$region" \
          -product_name "$product" \
          -profile "$profile" \
          --mode "$mode" \
        | sudo tee -a "$DST_FOLDER/$out" > /dev/null
      done
    done
  done

  echo -e "\n### Finished report with exit code: $? ###"
}

products_apache=(
  "dpi_upgraded_apache"
  "apache"
  "apache_dmzi"
  "apache_dmzi_emea"
  "apache_dmzi_apac"
  "apache_dmzi_amer"
  "apache_ibmcloud_vpc"
  "csa_imported_apache_dmzi_emea"
  "apache_wsgi"
)

products_apache_csa=(
  "csa_imported_apache_dmzi_emea"
)

products_iis=(
  "CSA_IMPORTED_iis_dmzi_emea"
  "iis_all_windows_version"
  "iis_dmzi_apac"
  "iis_vpc"
  "iis_dmzi"
  "iis_mzr"
  "iis_dmzi_amer"
  "iis_ets"
)

products_iis_vpc=(
  "iis_vpc"
)

products_jbosseap=(
  "jbosseap"
  "CSA_IMPORTED_jbosseap"
)

products_jbossews=(
  "jboss_ews"
  "dpi_upgraded_jboss_ews"
  "jboss_ews_ibm"
)

products_tomcat=(
  "dpi_upgraded_tomcat"
  "tomcat"
  "tomcat_ibmcloud_vpc"
  "tomcat_ibm"
)

products_tomcat_ibmcloud=(
  "tomcat_ibmcloud_vpc"
)

products_weblogic=(
  "weblogic"
  "weblogic_windows"
)

products_was=(
  "was"
  "websphere_base"
  "wasbase_admin_vmware"
  "wasbase_nodes_vmware"
  "DPI_UPGRADED_wasbase_admin_vmware"
  "csa_imported_websphere_imported"
  "wasnd"
)

products_sso=(
  "sso_as_a_service"
  "DPI_UPGRADED_sso_as_a_service"
  "sso_as_a_service_ibm_vdc"
  "sso_as_a_service_ibm_dmzr"
)

products_sso_ibm_vdc=(
  "sso_as_a_service_ibm_vdc"
)

products_global=(
  "dpi_upgraded_apache"
  "apache"
  "apache_dmzi"
  "apache_dmzi_emea"
  "apache_dmzi_apac"
  "apache_dmzi_amer"
  "apache_ibmcloud_vpc"
  "csa_imported_apache_dmzi_emea"
  "apache_wsgi"
  "CSA_IMPORTED_iis_dmzi_emea"
  "iis_all_windows_version"
  "iis_dmzi_apac"
  "iis_vpc"
  "iis_dmzi"
  "iis_mzr"
  "jbosseap"
  "CSA_IMPORTED_jbosseap"
  "dpi_upgraded_tomcat"
  "tomcat"
  "jboss_ews"
  "dpi_upgraded_jboss_ews"
  "jboss_ews_ibm"
  "tomcat_ibmcloud_vpc"
  "tomcat_ibm"
  "websphere_base"
  "was"
  "wasbase_admin_vmware"
  "wasbase_nodes_vmware"
  "DPI_UPGRADED_wasbase_admin_vmware"
  "csa_imported_websphere_imported"
  "wasnd"
  "weblogic"
  "weblogic_windows"
  "dpi_upgraded_iis_all_windows_version_vmware"
  "dpi_upgraded_sso_as_a_service"
)

hdr_base='"REGION","ECOSYSTEM","PRODUCT","PRODUCT_VERSION","ENV","STATUS","ZONE","HOSTNAME","FDQN","LOCATION","PERIMETER","DOMAIN","OS_VERSION"'
hdr_label='"REGION","ECOSYSTEM","PRODUCT","PRODUCT_VERSION","ENV","STATUS","ZONE","HOSTNAME","FDQN","LOCATION","PERIMETER","DOMAIN","OS_VERSION","LABEL"'
hdr_sso='REGION,ECOSYSTEM,PRODUCT,PRODUCT_VERSION,ENV,STATUS,HOSTNAME,FDQN,LOCATION,OS_VERSION'
hdr_sso_ibm='REGION,ECOSYSTEM,PRODUCT,PRODUCT_VERSION,ENV,STATUS,HOSTNAME,FDQN,PERIMETER,LOCATION,OS_VERSION'

[ -d "$DST_FOLDER" ] || die "DST_FOLDER does not exist: $DST_FOLDER"
[ -x ./list-vm-unified.sh ] || die "missing or not executable: ./list-vm-unified.sh"

action=""
report_name=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) usage ;;
    --global) action="global"; shift ;;
    --all) action="all"; shift ;;
    --report) action="report"; report_name="$2"; shift 2 ;;
    *) die "unknown arg: $1 (use --help)" ;;
  esac
done

[ -n "$action" ] || usage

case "$action" in
  global)
    init_csv "dpi_global.csv" "$hdr_label"
    append_products "dpi_global.csv" "base" "prd" "${products_global[@]}"
    append_products "dpi_global.csv" "base" "ibm" "${products_tomcat_ibmcloud[@]}"
    ;;
  report)
    case "$report_name" in
      apache)
        init_csv "dpi_apache.csv" "$hdr_base"
        append_products "dpi_apache.csv" "base" "prd" "${products_apache[@]}"
        ;;
      apache_csa)
        init_csv "dpi_apache_csa.csv" "$hdr_base"
        append_products "dpi_apache_csa.csv" "base" "prd" "${products_apache_csa[@]}"
        ;;
      iis)
        init_csv "dpi_iis.csv" "$hdr_base"
        append_products "dpi_iis.csv" "base" "prd" "${products_iis[@]}"
        ;;
      iis_vpc)
        init_csv "dpi_ii_vpc.csv" "$hdr_base"
        append_products "dpi_ii_vpc.csv" "iis_vpc" "prd" "${products_iis_vpc[@]}"
        ;;
      jbosseap)
        init_csv "dpi_jbossEAP.csv" "$hdr_base"
        append_products "dpi_jbossEAP.csv" "base" "prd" "${products_jbosseap[@]}"
        ;;
      jbossews)
        init_csv "dpi_jbossews.csv" "$hdr_base"
        append_products "dpi_jbossews.csv" "base" "prd" "${products_jbossews[@]}"
        ;;
      tomcat)
        init_csv "dpi_tomcat.csv" "$hdr_base"
        append_products "dpi_tomcat.csv" "base" "prd" "${products_tomcat[@]}"
        append_products "dpi_tomcat.csv" "base" "ibm" "${products_tomcat_ibmcloud[@]}"
        ;;
      tomcat_ibmcloud)
        init_csv "dpi_tomcat_ibmcloud.csv" "$hdr_base"
        append_products "dpi_tomcat_ibmcloud.csv" "base" "ibm" "${products_tomcat_ibmcloud[@]}"
        ;;
      weblogic)
        init_csv "dpi_weblogic.csv" "$hdr_label"
        append_products "dpi_weblogic.csv" "label" "prd" "${products_weblogic[@]}"
        ;;
      was)
        init_csv "dpi_was.csv" "$hdr_label"
        append_products "dpi_was.csv" "label" "prd" "${products_was[@]}"
        ;;
      sso)
        init_csv "dpi_sso.csv" "$hdr_sso"
        append_products "dpi_sso.csv" "sso" "prd" "${products_sso[@]}"
        ;;
      sso_ibm_vdc)
        init_csv "dpi_sso_ibm_vdc.csv" "$hdr_sso_ibm"
        append_products "dpi_sso_ibm_vdc.csv" "sso_ibm_vdc" "prd" "${products_sso_ibm_vdc[@]}"
        ;;
      global)
        init_csv "dpi_global.csv" "$hdr_label"
        append_products "dpi_global.csv" "base" "prd" "${products_global[@]}"
        append_products "dpi_global.csv" "base" "ibm" "${products_tomcat_ibmcloud[@]}"
        ;;
      *)
        die "unknown report name: $report_name (use --help)"
        ;;
    esac
    ;;
  all)
    init_csv "dpi_apache.csv" "$hdr_base"
    append_products "dpi_apache.csv" "base" "prd" "${products_apache[@]}"

    init_csv "dpi_apache_csa.csv" "$hdr_base"
    append_products "dpi_apache_csa.csv" "base" "prd" "${products_apache_csa[@]}"

    init_csv "dpi_iis.csv" "$hdr_base"
    append_products "dpi_iis.csv" "base" "prd" "${products_iis[@]}"

    init_csv "dpi_ii_vpc.csv" "$hdr_base"
    append_products "dpi_ii_vpc.csv" "iis_vpc" "prd" "${products_iis_vpc[@]}"

    init_csv "dpi_jbossEAP.csv" "$hdr_base"
    append_products "dpi_jbossEAP.csv" "base" "prd" "${products_jbosseap[@]}"

    init_csv "dpi_jbossews.csv" "$hdr_base"
    append_products "dpi_jbossews.csv" "base" "prd" "${products_jbossews[@]}"

    init_csv "dpi_tomcat.csv" "$hdr_base"
    append_products "dpi_tomcat.csv" "base" "prd" "${products_tomcat[@]}"
    append_products "dpi_tomcat.csv" "base" "ibm" "${products_tomcat_ibmcloud[@]}"

    init_csv "dpi_tomcat_ibmcloud.csv" "$hdr_base"
    append_products "dpi_tomcat_ibmcloud.csv" "base" "ibm" "${products_tomcat_ibmcloud[@]}"

    init_csv "dpi_weblogic.csv" "$hdr_label"
    append_products "dpi_weblogic.csv" "label" "prd" "${products_weblogic[@]}"

    init_csv "dpi_was.csv" "$hdr_label"
    append_products "dpi_was.csv" "label" "prd" "${products_was[@]}"

    init_csv "dpi_sso.csv" "$hdr_sso"
    append_products "dpi_sso.csv" "sso" "prd" "${products_sso[@]}"

    init_csv "dpi_sso_ibm_vdc.csv" "$hdr_sso_ibm"
    append_products "dpi_sso_ibm_vdc.csv" "sso_ibm_vdc" "prd" "${products_sso_ibm_vdc[@]}"

    init_csv "dpi_global.csv" "$hdr_label"
    append_products "dpi_global.csv" "base" "prd" "${products_global[@]}"
    append_products "dpi_global.csv" "base" "ibm" "${products_tomcat_ibmcloud[@]}"
    ;;
esac
