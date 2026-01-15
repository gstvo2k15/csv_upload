#!/usr/bin/env python3

import csv
import re
import sys
from collections import defaultdict
from pathlib import Path
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from typing import Dict, List, TextIO, Set


def _clean_name(text: str) -> str:
    """Normalizes values that make up group names."""
    text = (text or "").strip().replace(" ", "_").replace("-", "_")
    text = re.sub(r"[^\w]+", "_", text)
    return text.lower().strip("_")


def _group_name(product: str, region: str, env: str, location: str) -> str:
    """Unique name of the host group."""
    return f"{product}_{region}_{env}_{location}"


def _write_children(out_stream: TextIO, group_type: str, index: Dict[str, Set[str]]) -> None:
    """
    Write blocks like:

    [<key>:children]
    <group_detailed_1>
    <group_detailed_2>
    """
    for key, grp_set in sorted(index.items()):
        out_stream.write(f"[{key}:{group_type}]\n")
        for grp in sorted(grp_set):
            out_stream.write(f"{grp}\n")
        out_stream.write("\n")


def csv_to_ini(csv_file: Path, out_stream: TextIO) -> None:
    """
    Convert a CSV with columns:

    PRODUCT, REGION, ENV, LOCATION, HOSTNAME

    to an INI inventory that contains:
    * groups "detailed" (product_region_env_location) with their hosts,
    * child groups by environment, region and location.
    """
    detailed_groups: Dict[str, List[str]] = defaultdict(list)

    env_index: Dict[str, Set[str]] = defaultdict(set)
    region_index: Dict[str, Set[str]] = defaultdict(set)
    loc_index: Dict[str, Set[str]] = defaultdict(set)

    with csv_file.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, skipinitialspace=True)

        required = {"PRODUCT", "REGION", "ENV", "LOCATION", "HOSTNAME"}
        missing = required - set(reader.fieldnames or [])
        if missing:
            raise KeyError(f"Missing required CSV columns: {', '.join(sorted(missing))}")

        for row in reader:
            product = _clean_name(row["PRODUCT"])
            region = _clean_name(row["REGION"])
            env = _clean_name(row["ENV"])
            location = _clean_name(row["LOCATION"])
            hostname = (row["HOSTNAME"] or "").strip()

            if not hostname:
                continue

            grp_name = _group_name(product, region, env, location)
            host_line = f"{hostname} region={region} env={env} location={location}"

            detailed_groups[grp_name].append(host_line)
            env_index[env].add(grp_name)
            region_index[region].add(grp_name)
            loc_index[location].add(grp_name)

    for grp_name, hosts in detailed_groups.items():
        out_stream.write(f"[{grp_name}]\n")
        for host in hosts:
            out_stream.write(f"{host}\n")
        out_stream.write("\n")

    _write_children(out_stream, "children", env_index)
    _write_children(out_stream, "children", region_index)
    _write_children(out_stream, "children", loc_index)


def _parse_cli() -> ArgumentParser:
    parser = ArgumentParser(
        description="Convert CSV to Ansible INI inventory, adding *children* groups for env, region and location.",
        formatter_class=ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("csv_file", help="Path to csv file")
    return parser


def main() -> None:
    args = _parse_cli().parse_args()
    csv_path = Path(args.csv_file)

    if not csv_path.is_file():
        print(f"ERROR: file not found - {csv_path}", file=sys.stderr)
        sys.exit(1)

    try:
        csv_to_ini(csv_path, sys.stdout)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()