# loro-fuseki

[![Apache Jena Fuseki 5.6.0](https://img.shields.io/badge/Fuseki-5.6.0-blue)](https://jena.apache.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Ontology: CC-BY 4.0](https://img.shields.io/badge/Ontology-CC--BY%204.0-blue.svg)](https://creativecommons.org/licenses/by/4.0/)

A self-contained [Apache Jena Fuseki](https://jena.apache.org/) container with the **Cibelex Knowledge Graph** preloaded against the **LoRO ontology** ([Local Regulations Ontology](https://doi.org/10.5281/zenodo.20076577)), developed by the Municipality of Madrid as part of the [MAIA initiative](https://ayuntamientomadrid.github.io/loro-local-regulations-ontology/).

The container ships with the LoRO ontology baked in. The actual graph data (RDF triples for legal resources, organizations, people, taxonomy, places, etc.) is downloaded once from Hugging Face and mounted as a read-only volume — the container loads it into a TDB2 store and builds a Lucene full-text index on first start.

After it boots you have:

- **SPARQL UI** at `http://localhost:3030`
- **SPARQL endpoint** at `http://localhost:3030/loro/sparql`
- A read/write Graph Store Protocol endpoint at `http://localhost:3030/loro/data`

## What you get out of the box

| Component | Source | Notes |
|---|---|---|
| Apache Jena Fuseki 5.6.0 | Apache foundation | Standalone JAR, run with tini as PID 1 |
| LoRO ontology v1.0 | [Zenodo deposit](https://doi.org/10.5281/zenodo.20076577) | Baked into the image at `ontology/loro.ttl` |
| Cibelex Knowledge Graph | [Hugging Face dataset](https://huggingface.co/datasets/MAIA-Madrid-IA/cibelex-graph-core-sampler) | Downloaded by you with `./scripts/fetch-data.sh` |
| Lucene full-text index | Built on first start | Indexes `eli:title`, `skos:prefLabel`, `geonames:name`, `eli:description` (Spanish stemmer + stopwords) |
| Authentication | Apache Shiro, three-role IAM | `loro_admin` / `loro_app` / `loro_read` |

## Quick start

You need [Docker](https://docs.docker.com/get-docker/) (with Compose v2) and the [Hugging Face CLI](https://github.com/huggingface/huggingface_hub) (`pip install huggingface_hub`).

```bash
# 1. Get this repository
git clone https://github.com/AyuntamientoMadrid/loro-fuseki.git
cd loro-fuseki

# 2. (Optional) override defaults
cp .env.example .env

# 3. Run the end-to-end pipeline (fetch data + build + start + verify)
./scripts/run-local.sh
```

`run-local.sh` wraps the three core commands:

```bash
./scripts/fetch-data.sh             # download Cibelex Graph TTL files into ./data/transformed/
docker compose up -d --build        # build the image and start the container
./scripts/verify-data.sh            # run a few SPARQL queries to confirm everything is loaded
```

When it's done, open `http://localhost:3030` and log in as `loro_admin` with the password set in `.env` (default: `admin`).

## Running queries

### From the web UI

Browse to `http://localhost:3030`, click the `loro` dataset, then the **Query** tab. The default SPARQL prefixes are pre-populated.

### From the command line

```bash
curl -u loro_admin:admin \
     -X POST http://localhost:3030/loro/sparql \
     -H "Accept: text/csv" \
     --data-urlencode "query=SELECT (COUNT(*) AS ?triples) WHERE { ?s ?p ?o }"
```

### From `cibelex-mcp-fuseki`

Point the MCP server at this Fuseki instance:

```bash
export FUSEKI_ENDPOINT=http://localhost:3030/loro/sparql
```

See [AyuntamientoMadrid/cibelex-mcp-fuseki](https://github.com/AyuntamientoMadrid/cibelex-mcp-fuseki) for the MCP integration details.

### Example: count triples per named graph

```sparql
SELECT ?g (COUNT(*) AS ?triples)
WHERE { GRAPH ?g { ?s ?p ?o } }
GROUP BY ?g
ORDER BY DESC(?triples)
```

## Repository layout

```
.
├── Dockerfile              # Apache Jena Fuseki 5.6.0 image
├── docker-compose.yml      # Local orchestration with TDB2 persistence
├── entrypoint.sh           # Generates Shiro security config, loads data, runs Fuseki
├── .env.example            # Environment variables template
├── config/
│   └── loro.ttl            # TDB2 dataset + Lucene assembler configuration
├── ontology/
│   └── loro.ttl            # LoRO ontology v1.0 (baked into the image)
└── scripts/
    ├── fetch-data.sh       # Downloads the Cibelex Graph from Hugging Face
    ├── run-local.sh        # End-to-end: fetch + build + start + verify
    └── verify-data.sh      # SPARQL sanity-check queries
```

## Configuration

All knobs live in `.env` (see `.env.example`). The defaults are tuned for local development; review them before any deployment.

| Variable | Default | Purpose |
|---|---|---|
| `FUSEKI_LOCAL_PORT` | `3030` | Port exposed on the host |
| `PORT` | `8080` | Port inside the container |
| `JVM_ARGS` | `-Xmx4g -Xms1g` | JVM tuning. Increase `-Xmx` for the full graph |
| `LOAD_DATA_ON_START` | `true` | Auto-load TTL files from `/staging` on first start |
| `FUSEKI_READONLY` | `false` | Disable write endpoints when `true` |
| `LORO_ADMIN_PASSWORD` | `admin` | Required to start; admin role |
| `LORO_APP_PASSWORD` | _empty_ | Optional write role |
| `LORO_READ_PASSWORD` | _empty_ | Optional read-only role |

### Authentication model

Three Shiro roles, defined in `entrypoint.sh`:

- **`loro_admin`** — full access (UI, server admin API, write, read). Required.
- **`loro_app`** — same as `read` plus SPARQL Update / GSP write. Optional.
- **`loro_read`** — SPARQL query and GSP read. Optional.

A role is only provisioned if its password env var is set. Health endpoints (`/$/ping`, `/$/status`) are always public.

## Updating the data

Triples come from a versioned dataset on Hugging Face. To pick up a newer release:

```bash
docker compose down -v        # wipe the local TDB2 store
./scripts/fetch-data.sh       # pull the latest TTL files
docker compose up -d --build  # rebuild and load
```

## Citation

If you use this container or the Knowledge Graph in your research please cite both:

- **LoRO ontology** — [https://doi.org/10.5281/zenodo.20076577](https://doi.org/10.5281/zenodo.20076577)
- **Cibelex Knowledge Graph** — see the dataset card at [huggingface.co/datasets/MAIA-Madrid-IA/cibelex-graph-core-sampler](https://huggingface.co/datasets/MAIA-Madrid-IA/cibelex-graph-core-sampler)

## License

- The container code (Dockerfile, scripts, configuration) is released under the **MIT License** — see [`LICENSE`](LICENSE).
- The bundled LoRO ontology (`ontology/loro.ttl`) is released under **CC-BY 4.0**.
- The Cibelex Knowledge Graph downloaded from Hugging Face is released under **CC-BY 4.0** as declared in the dataset card.

## Maintenance

Maintained by the **MAIA team** (Madrid Artificial Intelligence) at the IT Department (IAM) of the Municipality of Madrid. Issues, suggestions and pull requests are welcome via this repository.
