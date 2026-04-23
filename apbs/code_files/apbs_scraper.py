#!/usr/bin/env python
import re
from pathlib import Path
from warnings import warn


def scientific_to_decimal(match: re.Match) -> str:
    """Converts a regex match of scientific notation to a string in decimal notation."""
    return str(float(match.group(1)) * (10 ** int(match.group(2))))


def pull_apbs_data(apbs_output: Path, output_file: Path | None, protein_name: str | None) -> None:
    """Finds electrical energies in APBS outputs and writes the energies to an output file."""
    if output_file is None:
        output_file = apbs_output.with_stem(f"{apbs_output.stem}_energies.tsv")
    if protein_name is None:
        protein_name = apbs_output.stem
    with apbs_output.open("r") as infile, output_file.open("a") as outfile:
        matches = [
            re.search(r"^(?:  Global net ELEC energy = )(-?\d\.\d+)(?:E\+0+)(\d+)(?: kJ\/mol)$", line)
            for line in infile
        ]
        matches = [scientific_to_decimal(match) for match in matches if match is not None]
        if len(matches) > 2:  # noqa: PLR2004 This comparison is against the known correct number of outputs for this particular calculation
            warn(f"WARNING: Input file {apbs_output} contains more than two energies.", UserWarning, stacklevel=2)
        outfile.write(f"{protein_name}\t{'\t'.join(matches)}\n")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(prog="APBS Scraper", description="Scrapes electrical energies from APBS outputs.")
    parser.add_argument("input", type=Path, help="The input file in APBS output format to be scraped.")
    parser.add_argument(
        "-o",
        "--output",
        required=False,
        default=None,
        type=Path,
        help="Optional: The output file name and path. If not provided, defaults to input_file_energies.tsv",
    )
    parser.add_argument(
        "-p",
        "--protein-name",
        required=False,
        default=None,
        type=str,
        help="Optional: The name of the protein being analyzed. If not provided, defaults to the stem of the input path.",
    )
    args = parser.parse_args()
    pull_apbs_data(apbs_output=args.input, output_file=args.output, protein_name=args.protein_name)
