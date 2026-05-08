# ==============================================================================
# loro-fuseki — Apache Jena Fuseki container with the LoRO Knowledge Graph
# ==============================================================================
#
# Standalone Apache Jena Fuseki image with the dataset configuration and the
# LoRO ontology baked in. Triples are loaded into a TDB2 store at first start
# from TTL files mounted on `/staging` (e.g. the contents of
# https://huggingface.co/datasets/MAIA-Madrid-IA/cibelex-graph-core-sampler).
#
# Three-role authentication via Apache Shiro (admin/app/read). For local
# development the docker-compose.yml provides a default admin password; for
# production deployments inject the password as an environment variable
# (e.g. from a secrets manager).
#
# Runtime environment variables:
#   PORT                 - HTTP port the server listens on (default: 8080)
#   IACBX_ADMIN_PASSWORD - Admin password (REQUIRED to start)
#   IACBX_APP_PASSWORD   - Optional app-role password (write access)
#   IACBX_READ_PASSWORD  - Optional read-only password (SPARQL query)
#   JVM_ARGS             - JVM tuning (default: -Xmx2g -Xms512m)
#   FUSEKI_READONLY      - "true" disables write endpoints
#   LOAD_DATA_ON_START   - "true" auto-loads TTL files from /staging at first run
#
# ==============================================================================

FROM eclipse-temurin:21-jre-alpine AS base

# Apache Jena Fuseki version — modify here to upgrade
ARG FUSEKI_VERSION=5.6.0

LABEL maintainer="MAIA initiative — Ayuntamiento de Madrid"
LABEL description="Apache Jena Fuseki container with the LoRO Knowledge Graph"
LABEL fuseki.version="${FUSEKI_VERSION}"
LABEL org.opencontainers.image.source="https://github.com/AyuntamientoMadrid/loro-fuseki"
LABEL org.opencontainers.image.licenses="MIT"

# -- System dependencies ------------------------------------------------------
RUN apk add --no-cache \
    bash \
    curl \
    tini

# -- Non-root user ------------------------------------------------------------
RUN addgroup -S fuseki && \
    adduser -S -G fuseki -h /fuseki fuseki

# -- Download and install Apache Jena Fuseki ----------------------------------
WORKDIR /tmp
RUN curl -fSL \
      "https://archive.apache.org/dist/jena/binaries/apache-jena-fuseki-${FUSEKI_VERSION}.tar.gz" \
      -o fuseki.tar.gz && \
    tar xzf fuseki.tar.gz && \
    mv apache-jena-fuseki-${FUSEKI_VERSION} /opt/fuseki && \
    rm fuseki.tar.gz

# -- Directory layout ---------------------------------------------------------
RUN mkdir -p \
    /fuseki/configuration \
    /fuseki/databases \
    /fuseki/run \
    /fuseki/logs \
    /staging

# -- Dataset configuration ----------------------------------------------------
COPY config/ /fuseki/configuration/

# -- Ontology bundled in the image (copied to /staging at build time) ---------
COPY ontology/ /staging/ontology/

# -- Entrypoint ----------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# -- Permissions ---------------------------------------------------------------
RUN chown -R fuseki:fuseki /fuseki /opt/fuseki /staging

USER fuseki
WORKDIR /fuseki

# -- Default environment ------------------------------------------------------
# Passwords have no default in the image (set them in docker-compose or runtime)
ENV PORT=8080 \
    IACBX_ADMIN_PASSWORD="" \
    IACBX_APP_PASSWORD="" \
    IACBX_READ_PASSWORD="" \
    JVM_ARGS="-Xmx2g -Xms512m" \
    FUSEKI_READONLY="false" \
    LOAD_DATA_ON_START="false" \
    FUSEKI_HOME="/opt/fuseki" \
    FUSEKI_BASE="/fuseki"

EXPOSE ${PORT}

# Health check — Fuseki exposes /$/ping as a health endpoint without auth
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT}/$/ping || exit 1

# tini as PID 1 for proper signal handling
ENTRYPOINT ["tini", "--"]
CMD ["/entrypoint.sh"]
