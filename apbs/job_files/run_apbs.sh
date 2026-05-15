#!/bin/bash -ue
#SBATCH --job-name="apbs"
#SBATCH --partition=shared
#SBATCH --time=00-00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --account=sfried3
#SBATCH --export=ALL
#SBATCH --array=1-10000%128
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null
#SBATCH --mail-user=jbeale3@jh.edu
#SBATCH --mail-type=END,FAIL,INVALID_DEPEND,TIME_LIMIT

WK_DIR="${HOME}/scr4_sfried3/apbs_calcs"
PROJECT_DIR="${HOME}/repositories/rockfish-projects/apbs"
CODE_DIR="${PROJECT_DIR}/code_files"
ENV_DIR="${PROJECT_DIR}/env_files"
INPUT_FILE="${WK_DIR}/incomplete_structures.txt"
COMPLETION_LOG="${WK_DIR}/completed_structures.txt"
OUTPUT_DIR="${WK_DIR}/apbs_outputs"
TMPDIR="${TMPDIR:-/tmp}"

ml anaconda3/2024.02-1
conda activate ~/apbsenv

function cleanup() {
	[[ -f "${tmp_pqr}" ]] && rm -f "${tmp_pqr}"
	[[ -f "${tmp_apbs_input}" ]] && rm -f "${tmp_apbs_input}"
	[[ -f "${tmp_apbs_output}" ]] && rm -f "${tmp_apbs_output}"
	[[ -f "${tmp_pqr%%.pqr}.log" ]] && rm -f "${tmp_pqr%%.pqr}.log"
	exit
}

cd "${WK_DIR}" || exit
touch "${COMPLETION_LOG}" || exit
[[ ! -e "${OUTPUT_DIR}" ]] && mkdir -p "${OUTPUT_DIR}"
while read -r cif; do
	# Setup temporary output file for pqr conversion and apbs calcs
	trap cleanup ERR EXIT HUP INT TERM
	# Use of mktemp -u is poor security practice, but it's used here to prevent accidental collision of parallel operations via an anti-clobber guard built into mmcifConvert
	tmp_pqr=$(mktemp -uq -p "${TMPDIR}" "XXXXXXXXXX.pqr")
	tmp_apbs_input=$(mktemp -q -p "${TMPDIR}" "XXXXXXXXXX.apbs_input")
	tmp_apbs_output=$(mktemp -q -p "${TMPDIR}" "XXXXXXXXXX.apbs_output")

	# Convert cif to pqr
	"${CODE_DIR}/mmcifConvert.py" "${cif}" --output "${tmp_pqr}" --to-pqr

	# Prep apbs input file for each calculation
	cat <<-EOF >"${tmp_apbs_input}"
		read
		  mol pqr ${tmp_pqr}
		end
		elec name solv # Electrostatics calculation on the solvated state
		  mg-manual # Specify the mode for APBS to run
		  dime 97 97 97 # The grid dimensions
		  nlev 4 # Multigrid level parameter
		  grid 0.33 0.33 0.33 # Grid spacing
		  gcent mol 1 # Center the grid on molecule 1
		  mol 1 # Perform the calculation on molecule 1
		  lpbe # Solve the linearized Poisson-Boltzmann equation
		  bcfl mdh # Use all multipole moments when calculating the potential
		  pdie 1.0 # Solute dielectric
		  sdie 78.54 # Solvent dielectric
		  chgm spl2 # Spline-based discretization of the delta functions
		  srfm mol # Molecular surface definition
		  srad 1.4 # Solvent probe radius (for molecular surface)
		  swin 0.3 # Solvent surface spline window (not used here)
		  sdens 10.0 # Sphere density for accessibility object
		  temp 298.15 # Temperature
		  calcenergy total # Calculate energies
		  calcforce no # Do not calculate forces
		end
		elec name ref # Calculate potential for reference (vacuum) state
		  mg-manual
		  dime 97 97 97
		  nlev 4
		  grid 0.33 0.33 0.33
		  gcent mol 1
		  mol 1
		  lpbe
		  bcfl mdh
		  pdie 1.0
		  sdie 1.0
		  chgm spl2
		  srfm mol
		  srad 1.4
		  swin 0.3
		  sdens 10.0
		  temp 298.15
		  calcenergy total
		  calcforce no
		end
		# Calculate solvation energy
		print elecEnergy solv - ref end
		print elecEnergy ref end
		quit
	EOF

	# Calculate solvated and vacuum energy for each protein
	singularity exec "${ENV_DIR}/apbs.sif" apbs "${tmp_apbs_input}" >"${tmp_apbs_output}" 2>/dev/null

	# Use regex to parse calculated energies for each protein
	"${CODE_DIR}/apbs_scraper.py" "${tmp_apbs_output}" --output "${OUTPUT_DIR}/calculated_energies.tsv" --protein-name "$(basename "${cif}" .cif)" && printf "%s\n" "${cif}" >>"${COMPLETION_LOG}"
done < <(sed -n "${SLURM_ARRAY_TASK_ID}"p <(comm -23 "${INPUT_FILE}" <(sort -u "${COMPLETION_LOG}")))
