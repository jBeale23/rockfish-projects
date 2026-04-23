#!/usr/bin/env python
"""Converts MMCIF files to PDB or PQR format."""

import tempfile
from pathlib import Path
from subprocess import CalledProcessError, run
from warnings import warn

from Bio.PDB.MMCIFParser import MMCIFParser
from Bio.PDB.PDBIO import PDBIO


def convert_cif(
    input_path: Path,
    output_path: Path | None = None,
    *,
    convert_to_pqr: bool = False,
    clobber_output_file: bool = False,
) -> Path:
    """Converts the provided input MMCIF to PDB or PQR format.

    Arguments:
        input_path: Path
        The path to the input MMCIF format file to be converted.
        output_path: Path | None = None
        The optional path to the output PDB or PQR file. If None or not provided, defaults to input_path.[pdb|pqr]
        convert_to_pqr: bool = False
        If true, converts to PQR format instead of PDB. Defaults to false.
        clobber_output_file: bool = False
        If true, replace existing PDB file at the output path. Defaults to false.

    Raises:
        FileNotFoundError if input_file does not exist or is not accessible.
        ValueError if input_file does not have the .cif extension.

    Warns:
        UserWarning if output_path exists and clobber_output_file is False.

    Returns:
        output_path: Path
        The path to the output PDB or PQR file.
    """
    # Validates that input_path exists and is in .cif format, then attempts to parse it into a structure named for its filename.
    if not input_path.exists():
        msg = f"Input file {input_path} does not exist or is not accessible."
        raise FileNotFoundError(msg)
    if input_path.suffix != ".cif":
        msg = f"Input file {input_path} is not in .cif format."
        raise ValueError(msg)
    parser = MMCIFParser(QUIET=True, PERMISSIVE=False)
    structure = parser.get_structure(input_path.stem, input_path)

    # Parses output_path, if not provided, from input_path, and warns the end user if output_path exists and clobber_output_file is False.
    if output_path is None:
        output_path = input_path.with_suffix(".pqr") if convert_to_pqr else input_path.with_suffix(".pdb")
    if output_path.exists() and not clobber_output_file:
        warn(f"WARNING: Output file {output_path} exists, and clobber_output_file is False.", UserWarning, stacklevel=2)
        return output_path

    # Converts from .cif to .pdb or .pqr
    io = PDBIO(is_pqr=False)
    io.set_structure(structure)

    if convert_to_pqr:
        with tempfile.NamedTemporaryFile(mode="w+t") as tmp:
            io.save(str(tmp.name))
            try:
                # S603 is explicitly disabled as unfortunately pdb2pqr doesn't make a programmatic API readily available, thus a subprocess is the easiest solution.
                run(  # noqa: S603
                    # S607 is explicitly disabled as pdb2pqr may be available from too many sources to reasonably account for all possibilities here.
                    ["pdb2pqr", "-ff=PARSE", str(tmp.name), str(output_path.absolute())],  # noqa: S607
                    check=True,
                    capture_output=True,
                )
            except CalledProcessError as e:
                message = f"{str(e)[:-1]}:\n{e.output}"
                raise OSError(message) from None
    else:
        io.save(str(output_path.absolute()))

    return output_path


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(prog="MMCIF Converter", description="Converts MMCIF files to PDB or PQR format.")
    parser.add_argument("input", type=Path, help="The input file in MMCIF format to be converted.")
    parser.add_argument(
        "-o",
        "--output",
        required=False,
        default=None,
        type=Path,
        help="Optional: The output file name and path. If not provided, defaults to input_file.[pdb|pqr].",
    )
    parser.add_argument(
        "--to-pqr",
        required=False,
        action="store_true",
        default=False,
        help="Optional: If present, output will be in PQR format instead of PDB.",
    )
    parser.add_argument(
        "--clobber-output-file",
        required=False,
        action="store_true",
        default=False,
        help="Optional: If present, existing output files will be overwritten.",
    )
    args = parser.parse_args()
    output_file = convert_cif(
        input_path=args.input,
        output_path=args.output,
        convert_to_pqr=args.to_pqr,
        clobber_output_file=args.clobber_output_file,
    )
