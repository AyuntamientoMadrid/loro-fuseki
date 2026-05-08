#!/bin/bash
# ============================================================================
# fetch-data.sh — Download the Cibelex Knowledge Graph from Hugging Face
# ============================================================================
#
# Downloads the TTL files of the Cibelex Knowledge Graph from
# https://huggingface.co/datasets/MAIA-Madrid-IA/cibelex-graph-core-sampler
# into ./data/transformed/, ready to be auto-loaded by the loro-fuseki
# container on first start (the folder is mounted as /staging).
#
# Requires:
#   - The Hugging Face CLI (`hf`) installed (https://github.com/huggingface/huggingface_hub).
#     `pip install huggingface_hub` or `uv tool install huggingface-hub` work.
#   - Public dataset, no token needed.
#
# Usage:
#   ./scripts/fetch-data.sh              # download into ./data/transformed/
#   DATA_DIR=/path ./scripts/fetch-data.sh
#
# ============================================================================

set -e

DATASET="${HF_DATASET:-MAIA-Madrid-IA/cibelex-graph-core-sampler}"
DATA_DIR="${DATA_DIR:-./data/transformed}"

# -- Logging colors -----------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# -- Locate the Hugging Face CLI ---------------------------------------------
HF_CMD=""
if command -v hf >/dev/null 2>&1; then
    HF_CMD="hf"
elif command -v huggingface-cli >/dev/null 2>&1; then
    HF_CMD="huggingface-cli"
else
    log_error "Neither 'hf' nor 'huggingface-cli' is on the PATH."
    log_error "Install it first, e.g.:"
    log_error "  pip install huggingface_hub"
    log_error "  # or"
    log_error "  uv tool install huggingface-hub"
    exit 1
fi

log_info "Using Hugging Face CLI: ${HF_CMD}"
log_info "Dataset: ${DATASET}"
log_info "Destination: ${DATA_DIR}"

mkdir -p "${DATA_DIR}"

# -- Download ----------------------------------------------------------------
if [ "${HF_CMD}" = "hf" ]; then
    "${HF_CMD}" download \
        --repo-type dataset \
        --local-dir "${DATA_DIR}" \
        "${DATASET}"
else
    # Older huggingface-cli interface
    "${HF_CMD}" download \
        --repo-type dataset \
        --local-dir "${DATA_DIR}" \
        --local-dir-use-symlinks False \
        "${DATASET}"
fi

# -- Quick sanity check ------------------------------------------------------
ttl_count=$(find "${DATA_DIR}" -maxdepth 2 -type f -name '*.ttl' | wc -l | tr -d ' ')
log_info "Files in ${DATA_DIR}:"
find "${DATA_DIR}" -maxdepth 2 -type f -name '*.ttl' -exec ls -lh {} \; | awk '{print "  " $9 " (" $5 ")"}'

if [ "${ttl_count}" -eq 0 ]; then
    log_warn "No .ttl files found after download — verify the dataset structure."
    exit 1
fi

log_info "Done. ${ttl_count} TTL file(s) ready for the container."
log_info "Next step: docker compose up -d --build"
