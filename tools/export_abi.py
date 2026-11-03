#!/usr/bin/env python3
"""Export or check ABIs from local, already-built Foundry artifacts. No network or wallet access."""
import argparse
import json
from pathlib import Path

CONTRACTS = ("GameRules", "SeedLedger", "Clans", "Army", "Villages")
ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if an exported ABI is absent or stale")
    args = parser.parse_args()
    for name in CONTRACTS:
        artifact = ROOT / "out" / f"{name}.sol" / f"{name}.json"
        abi = json.loads(artifact.read_text())["abi"]
        dest = ROOT / "docs" / "abi" / f"{name}.json"
        if args.check:
            if not dest.exists() or json.loads(dest.read_text()) != abi:
                raise SystemExit(f"ABI missing or stale: {dest.relative_to(ROOT)}")
        else:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(json.dumps(abi, indent=2) + "\n")
        print(f"{'Checked' if args.check else 'Exported'} {name}")


if __name__ == "__main__":
    main()
