# Changelog

## [fix/run_report] 03/01/2025:

### Summary
Hotfix branch created to correct a critical design flaw in the report generation flow where CSV files were unintentionally overwritten when combining data from multiple execution modes (PRD + IBM).

This branch does **not** introduce new functionality. It restores correct and deterministic behavior while preserving full backward compatibility with the original per-product scripts.

### Fixed
- **Critical bug** where calling the report generator multiple times for the same output file (`tomcat`, `global`, `--all`) caused earlier data to be overwritten.
- CSV files are now initialized exactly once and subsequently appended to, ensuring no data loss.

### Changed
- Removed the `run_report()` function which recreated CSV files on every invocation.
- Introduced two explicit lifecycle functions:
  - `init_csv()` – creates the CSV and writes the header once.
  - `append_products()` – appends rows for a set of products without modifying the header.
- Refactored `tomcat` and `global` execution paths to correctly merge:
  - PRD endpoint data
  - IBM endpoint data
- Refactored `--all` execution path to follow the same safe pattern.

### Scope
- Changes are limited to `dpi.sh`.
- `list-vm-unified.sh` behavior and all jq profiles remain unchanged.
- Output CSV structure, filters, and semantics are identical to the legacy scripts.

### Impact
- Prevents silent data loss.
- Makes report generation idempotent and predictable.
- Safe to backport or deploy without side effects.

### Notes
- This branch is a **hot corrective operation (HCO)**, not a feature release.
- Any future changes altering filters, columns, or normalization must be tracked as functional changes.
