#!/bin/bash
# ============================================================================
# run-local.sh — End-to-end local pipeline
# ============================================================================
#
# Convenience orchestrator that:
#   1. Downloads the Cibelex Knowledge Graph from Hugging Face into ./data/transformed/
#   2. Builds the Docker image and starts the container.
#   3. Waits for the Fuseki health endpoint to respond.
#   4. Runs the verification script (a few SPARQL queries).
#
# Usage:
#   ./scripts/run-local.sh
#
# After completion the SPARQL UI is at http://localhost:3030 and the SPARQL
# endpoint at http://localhost:3030/loro/sparql.
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

cd "$(dirname "$0")/.."

# -- Step 1: download data ---------------------------------------------------
if [ ! -f "./data/transformed/legal-resource.ttl" ]; then
    log_info "Step 1/4: downloading Cibelex Knowledge Graph from Hugging Face"
    ./scripts/fetch-data.sh
else
    log_warn "Step 1/4: data already present in ./data/transformed/, skipping download"
fi

# -- Step 2: build & start ---------------------------------------------------
log_info "Step 2/4: building image and starting container (docker compose up -d --build)"
docker compose up -d --build

# -- Step 3: wait for /ping --------------------------------------------------
log_info "Step 3/4: waiting for Fuseki to become healthy..."
LOCAL_PORT="${FUSEKI_LOCAL_PORT:-3030}"
for i in $(seq 1 60); do
    if curl -sf "http://localhost:${LOCAL_PORT}/$/ping" > /dev/null 2>&1; then
        log_info "Fuseki is up after ${i}s"
        break
    fi
    sleep 2
done

# -- Step 4: verify ----------------------------------------------------------
if [ -x "./scripts/verify-data.sh" ]; then
    log_info "Step 4/4: running verification queries"
    FUSEKI_URL="http://localhost:${LOCAL_PORT}" ./scripts/verify-data.sh || true
fi

log_info "============================================"
log_info "loro-fuseki ready"
log_info "============================================"
log_info "  SPARQL UI:       http://localhost:${LOCAL_PORT}"
log_info "  SPARQL endpoint: http://localhost:${LOCAL_PORT}/loro/sparql"
log_info "  Default admin:   iacbx_admin / admin   (override via .env)"
log_info "============================================"
