# csv_upload
Csv generation for inventory to be used in Ansible Tower.

# DPI Reporting Suite

Unified reporting framework for generating CSV reports from CAPS APIs, replacing multiple legacy `dpi_*.sh` and `list-vm-*` scripts with a deterministic, maintainable design.

---

## Components

### `dpi.sh`
Main entry point. Orchestrates report generation.

Responsibilities:
- Parses CLI arguments.
- Decides which reports to generate.
- Initializes CSV files.
- Appends data per product, environment, region, and endpoint.

Supported modes:
- `--report <name>` : Generate a single report.
- `--global`        : Generate one CSV containing all products.
- `--all`           : Generate all individual reports and the global one.
- `--help`          : Show usage.

This script **never fetches data directly**. It delegates all API access to `list-vm-unified.sh`.

---

### `list-vm-unified.sh`
Single data extraction script replacing all historical `list-vm-*` variants.

Responsibilities:
- Calls CAPS API with pagination.
- Selects the correct jq extraction profile.
- Outputs CSV rows to stdout.

Supported profiles (equivalent to legacy scripts):

| Profile        | Legacy Equivalent              | Behavior |
|---------------|--------------------------------|----------|
| `base`        | `list-vm-v2.sh`                | Strict filter on hostname, fqdn, zone, os.version |
| `label`       | `list-vm-v2_label.sh`          | Same as base + mandatory label |
| `iis_vpc`     | `list-vm-v2_iis-vpc.sh`        | Relaxed filtering |
| `sso`         | `list-vm-sso.sh`               | SSO-specific fields |
| `sso_ibm_vdc` | `list-vm-sso_ibm_vdc.sh`       | IBM VDC SSO layout |

Supported endpoints:
- `prd` (default): `CAPS_URL_PRD`
- `ibm`: `CAPS_URL_IBM` (fallback to PRD if unset)

---

## CSV Lifecycle (Critical Design)

CSV generation is explicitly split into two phases:

1. **Initialization**
   - File is created.
   - Header is written exactly once.

2. **Append**
   - Data is appended for each product / environment / region.
   - Multiple endpoints (PRD + IBM) are merged safely.

This guarantees:
- No overwrites.
- Deterministic output.
- Correct behavior for `tomcat`, `global`, and `--all`.

---

## Environment Requirements

Required variables (usually sourced from `~/.caprc`):

- `CAPS_URL_PRD`
- `CAPS_API_KEY_PRD`

Optional (IBM mode):
- `CAPS_URL_IBM`
- `CAPS_API_KEY_IBM`

---

## Examples

Generate a single report:
```bash
./dpi.sh --report weblogic
```

Generate only the global CSV:
```bash
./dpi.sh --global
```

Generate all reports:
```bash
./dpi.sh --all
```