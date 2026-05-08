#!/bin/bash
# =============================================================================
# Verify Data - Ejecuta consultas de verificación en los datos cargados
# =============================================================================

set -e

FUSEKI_URL="${FUSEKI_URL:-http://localhost:3030}"
# Credentials: default to the local-dev admin user/password; override via env vars
ADMIN_USER="${ADMIN_USER:-iacbx_admin}"
ADMIN_PASS="${ADMIN_PASS:-${IACBX_ADMIN_PASSWORD:-admin}}"

echo "=== Verificación de Datos LoRO ==="
echo ""

# Función para ejecutar consulta SPARQL
run_query() {
    local description="$1"
    local query="$2"
    
    echo "--- ${description} ---"
    curl -s -u "${ADMIN_USER}:${ADMIN_PASS}" \
        -X POST "${FUSEKI_URL}/loro/sparql" \
        -H "Accept: text/csv" \
        -d "query=${query}" | column -t -s,
    echo ""
}

# 1. Contar triples por grafo
run_query "Triples por grafo" \
    "SELECT ?g (COUNT(*) as ?triples) WHERE { GRAPH ?g { ?s ?p ?o } } GROUP BY ?g ORDER BY DESC(?triples)"

# 2. Contar recursos legales
run_query "Total de recursos legales" \
    "PREFIX loro: <http://maia.madrid.es/ontologies/def/local-regulations#>
     SELECT (COUNT(DISTINCT ?r) as ?total)
     FROM <http://maia.madrid.es/ontologies/loro/legal-resource>
     WHERE { ?r a loro:LegalResource }"

# 3. Contar organizaciones
run_query "Total de organizaciones" \
    "PREFIX loro: <http://maia.madrid.es/ontologies/def/local-regulations#>
     SELECT (COUNT(DISTINCT ?o) as ?total)
     FROM <http://maia.madrid.es/ontologies/loro/organization>
     WHERE { ?o a loro:Organization }"

# 4. Contar personas
run_query "Total de personas" \
    "PREFIX loro: <http://maia.madrid.es/ontologies/def/local-regulations#>
     SELECT (COUNT(DISTINCT ?p) as ?total)
     FROM <http://maia.madrid.es/ontologies/loro/person>
     WHERE { ?p a loro:Person }"

# 5. Contar eventos
run_query "Total de eventos" \
    "PREFIX schema: <http://schema.org/>
     SELECT (COUNT(DISTINCT ?e) as ?total)
     FROM <http://maia.madrid.es/ontologies/loro/event>
     WHERE { ?e a schema:Event }"

# 6. Contar lugares (features)
run_query "Total de lugares (Features)" \
    "PREFIX geonames: <https://www.geonames.org/ontology#>
     SELECT (COUNT(DISTINCT ?f) as ?total)
     FROM <http://maia.madrid.es/ontologies/loro/feature>
     WHERE { ?f a geonames:Feature }"

# 7. Muestra de recursos legales
run_query "Muestra de 5 recursos legales" \
    "PREFIX eli: <http://data.europa.eu/eli/ontology#>
     PREFIX loro: <http://maia.madrid.es/ontologies/def/local-regulations#>
     SELECT ?recurso (SUBSTR(STR(?titulo), 1, 80) as ?titulo_corto)
     FROM <http://maia.madrid.es/ontologies/loro/legal-resource>
     WHERE { 
       ?recurso a loro:LegalResource ;
                eli:title ?titulo .
     }
     LIMIT 5"

# 8. Muestra de organizaciones
run_query "Muestra de 5 organizaciones" \
    "PREFIX skos: <http://www.w3.org/2008/05/skos#>
     PREFIX loro: <http://maia.madrid.es/ontologies/def/local-regulations#>
     SELECT ?org ?nombre
     FROM <http://maia.madrid.es/ontologies/loro/organization>
     WHERE { 
       ?org a loro:Organization ;
            skos:prefLabel ?nombre .
     }
     LIMIT 5"

# 9. Verificar namespace de URIs (confirmar transformación)
run_query "Verificar namespace Madrid en URIs" \
    "PREFIX loro: <http://maia.madrid.es/ontologies/def/local-regulations#>
     SELECT ?uri
     FROM <http://maia.madrid.es/ontologies/loro/organization>
     WHERE { ?uri a loro:Organization }
     LIMIT 3"

echo "=== Verificación completada ==="
