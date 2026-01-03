#!/bin/bash

. ~/.caprc

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

get_header_value() {
  local header="$1"
  local response_headers="$2"
  echo "$response_headers" | grep -i "^$header" | awk '{print $2}' | tr -d '\r'
}

usage() {
  echo -e "\nusage: $0 -product_name xxxx -environment DEV|STG|PRD -region EMEA|AMER|APAC [-ecosystem XXXXX] [-os_version 7|8|9] [-hostname xxxx] [-profile base|label|iis_vpc|sso|sso_ibm_vdc] [--mode prd|ibm] [-debug 1]"
  exit 1
}

page=1
size=100

while [ "$#" -gt 0 ]; do
  case "$1" in
    -product_name) product_name="$2"; shift 2 ;;
    -environment) environment="$2"; shift 2 ;;
    -region) region="$2"; shift 2 ;;
    -ecosystem) ecosystem="$2"; shift 2 ;;
    -os_version) os_version="$2"; shift 2 ;;
    -hostname) vm_hostname="$2"; shift 2 ;;
    -profile) profile="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    -debug) query_debug="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -z "${product_name:-}" ] && usage
[ -z "${environment:-}" ] && usage
[ -z "${region:-}" ] && usage

if [[ $environment != @(DEV|STG|PRD) ]]; then usage; fi
if [[ $region != @(EMEA|AMER|APAC) ]]; then usage; fi

profile="${profile:-base}"
mode="${mode:-prd}"

sh_eco=""
sh_vm_hostname=""
sh_osversion=""

[ -n "${ecosystem:-}" ] && sh_eco="&ecosystem=${ecosystem}"
[ -n "${vm_hostname:-}" ] && sh_vm_hostname="&hostname=${vm_hostname}"
[ -n "${os_version:-}" ] && sh_osversion="&dpi_key=os.version&dpi_value=${os_version}"

case "$mode" in
  prd)
    BASE_URL="${CAPS_URL_PRD}"
    API_KEY="${CAPS_API_KEY_PRD}"
    ;;
  ibm)
    BASE_URL="${CAPS_URL_IBM:-$CAPS_URL_PRD}"
    API_KEY="${CAPS_API_KEY_IBM:-$CAPS_API_KEY_PRD}"
    ;;
  *) usage ;;
esac

[ -z "${BASE_URL:-}" ] && { echo "missing CAPS_URL_PRD" >&2; exit 1; }
[ -z "${API_KEY:-}" ] && { echo "missing CAPS_API_KEY_PRD" >&2; exit 1; }

jq_base='
  .[]
  | select(.dpi != null and (.dpi | length > 0))
  | .region as $region
  | .ecosystem as $ecosystem
  | .product_name as $product_name
  | .product_version as $product_version
  | .environment as $environment
  | .state as $state
  | .dpi[]
  | select(
      [.hostname, .fqdn, .os.version, .zone]
      | all(. != null and . != "")
    )
  | "\"\($region)\",\"\($ecosystem)\",\"\($product_name)\",\"\($product_version)\",\"\($environment)\",\"\($state)\",\"\(.zone)\",\"\(.hostname)\",\"\(.fqdn)\",\"\(.location // \"\")\",\"\(.perimeter // \"\")\",\"\(.domain // \"\")\",\"\(.os.version)\""
'

jq_label='
  .[]
  | select(.dpi != null and (.dpi | length > 0))
  | .sub_id           as $sub_id
  | .region           as $region
  | .ecosystem        as $ecosystem
  | .product_name     as $product_name
  | .product_version  as $product_version
  | .environment      as $environment
  | .state            as $state
  | .workspace_id     as $workspace_id
  | .dpi[]
  | select(
      [.hostname, .fqdn, .os.version, .zone, .label]
      | all(. != null and . != "")
    )
  | [
      $region,
      $ecosystem,
      $product_name,
      $product_version,
      $environment,
      $state,
      .zone,
      .hostname,
      .fqdn,
      (.location // ""),
      (.perimeter // ""),
      (.domain // ""),
      .os.version,
      .label
    ]
  | @csv
'

jq_iis_vpc='
  .[]
  | select(.dpi != null and (.dpi | length > 0))
  | .region           as $region
  | .ecosystem        as $ecosystem
  | .product_name     as $product_name
  | .product_version  as $product_version
  | .environment      as $environment
  | .state            as $state
  | .perimeter        as $perimeter
  | .dpi[]
  | select([.hostname, .fqdn, .os.version, .zone])
  | [
      $region,
      $ecosystem,
      $product_name,
      $product_version,
      $environment,
      $state,
      .zone,
      .hostname,
      .fqdn,
      (if .location   == null then "" else .location   end),
      (if $perimeter  == null then "" else $perimeter  end),
      (if .domain     == null then "" else .domain     end),
      .os.version
    ]
  | @csv
'

jq_sso='
  .[]
  | select(.dpi != null and (.dpi | length > 0))
  | .region as $region
  | .ecosystem as $ecosystem
  | .product_name as $product_name
  | .product_version as $product_version
  | .environment as $environment
  | .state as $state
  | .location as $location
  | .dpi[]
  | select(
      [.hostname, .fqdn, .os.version]
      | all(. != null and . != "")
    )
  | "\"\($region)\",\"\($ecosystem)\",\"\($product_name)\",\"\($product_version)\",\"\($environment)\",\"\($state)\",\"\(.hostname)\",\"\(.fqdn)\",\"\($location)\",\"\(.os.version)\""
'

jq_sso_ibm_vdc='
  .[]
  | select(.dpi != null and (.dpi | length > 0))
  | .region as $region
  | .ecosystem as $ecosystem
  | .product_name as $product_name
  | .product_version as $product_version
  | .environment as $environment
  | .state as $state
  | .perimeter as $perimeter
  | .location as $location
  | .dpi[]
  | "\"\($region)\",\"\($ecosystem)\",\"\($product_name)\",\"\($product_version)\",\"\($environment)\",\"\($state)\",\"\(.hostname)\",\"\(.fqdn)\",\"\($perimeter)\",\"\($location)\",\"\(.os.version)\""
'

case "$profile" in
  base) JQ="$jq_base" ;;
  label) JQ="$jq_label" ;;
  iis_vpc) JQ="$jq_iis_vpc" ;;
  sso) JQ="$jq_sso" ;;
  sso_ibm_vdc) JQ="$jq_sso_ibm_vdc" ;;
  *) usage ;;
esac

while :; do
  if [ -n "${query_debug:-}" ]; then
    echo "product_name=${product_name}&environment=${environment}&region=${region}&state=ACTIVE${sh_eco}${sh_vm_hostname}${sh_osversion}&page_num=$page&page_size=$size" >&2
  fi

  response=$(curl -s -w "\n%{http_code}" -D - \
    "${BASE_URL}?product_name=${product_name}&environment=${environment}&region=${region}&state=ACTIVE${sh_eco}${sh_vm_hostname}${sh_osversion}&page_num=$page&page_size=$size" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --header "x-apikey: ${API_KEY}")

  headers=$(echo "$response" | sed -n '/^\r$/q;p')
  body_and_code=$(echo "$response" | sed -n '/^\r$/,$p' | sed '1d')
  body=$(echo "$body_and_code" | sed '$d')
  http_code=$(echo "$body_and_code" | tail -n 1)

  if [[ "$http_code" -ne 200 ]]; then
    echo "error HTTP $http_code ." >&2
    exit 1
  fi

  x_total=$(get_header_value 'x-total' "$headers")
  x_page=$(get_header_value 'x-page' "$headers")
  x_size=$(get_header_value 'x-size' "$headers")

  x_page=${x_page//None/1}
  x_size=${x_size//None/100}
  x_total=${x_total//None/0}

  x_page=$((x_page + 0))
  x_size=$((x_size + 0))
  x_total=$((x_total + 0))

  echo "$body" | jq -r "$JQ"

  if (( page * x_size >= x_total )); then
    break
  fi
  page=$((page + 1))
done
