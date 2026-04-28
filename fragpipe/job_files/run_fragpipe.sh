#!/bin/bash -ue
#SBATCH --job-name="fragpipe"
#SBATCH --partition=shared
#SBATCH --time=01-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=32
#SBATCH --account=sfried3
#SBATCH --export=ALL
#SBATCH --output=results_%j.log
#SBATCH --error=errors_%j.log
#SBATCH --mail-user=jbeale3@jh.edu
#SBATCH --mail-type=END,FAIL,INVALID_DEPEND,TIME_LIMIT

PROJECT_DIR="${HOME}/repositories/rockfish-projects/fragpipe"
ENV_DIR="${PROJECT_DIR}/env_files"
RUN_CMD="singularity exec "${ENV_DIR}/fragpipe_24.0.sif" fragpipe"

WK_DIR="${HOME}/scr4_sfried3/fragpipe"
MANIFEST_FILE="${WK_DIR}/filelist.fp-manifest"
WORKFLOW_FILE="${WK_DIR}/fragpipe.workflow"
OUTPUT_DIR="${WK_DIR}/fragpipe_outputs"

function err_log() {
	status="${?}"
	printf "[%(%Y-%m-%d %H:%M:%S)T]: %s failed at %s with exit code %s\n" -1 "${BASH_COMMAND}" "${LINENO}" "${status}" >&2
	exit "${status}"
}
trap err_log ERR

cd "${WK_DIR}" || exit 1
[[ ! -e "${OUTPUT_DIR}" ]] && mkdir -p "${OUTPUT_DIR}"
printf "[%(%Y-%m-%d %H:%M:%S)T]: FragPipe run started with FragPipe version: %s\n" -1 "$("${RUN_CMD}" --help | sed -n '1p' | cut -d " " -f2)" >&1
"${RUN_CMD}" --headless --threads="${SLURM_NTASKS_PER_NODE}" --ram="$((SLURM_NTASKS_PER_NODE * 4))" --manifest="${MANIFEST_FILE}" --workflow="${WORKFLOW_FILE}" --workdir="${OUTPUT_DIR}"
printf "[%(%Y-%m-%d %H:%M:%S)T]: FragPipe run finished.\n" -1 >&1
