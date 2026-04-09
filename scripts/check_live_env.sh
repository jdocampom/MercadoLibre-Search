#!/bin/sh

set -eu

data_source="${MELI_DATA_SOURCE:-demo}"
site_id="${MELI_SITE_ID:-MCO}"
access_token="${MELI_ACCESS_TOKEN:-}"
query="${1:-iphone}"

if [ "$data_source" != "live" ]; then
    echo "Skipping live API validation because MELI_DATA_SOURCE=${data_source}."
    exit 0
fi

if [ -z "$access_token" ]; then
    echo "MELI_DATA_SOURCE=live requires MELI_ACCESS_TOKEN." >&2
    exit 1
fi

response_body="$(mktemp)"
trap 'rm -f "$response_body"' EXIT

users_me_status_code="$(curl -sS \
    -o "$response_body" \
    -w "%{http_code}" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    "https://api.mercadolibre.com/users/me")"

case "$users_me_status_code" in
    2??)
        ;;
    401)
        echo "Mercado Libre rejected the token with HTTP 401 while validating /users/me. Refresh the access token." >&2
        cat "$response_body" >&2
        exit 1
        ;;
    403)
        echo "Mercado Libre rejected /users/me with HTTP 403. The token is user-scoped but not allowed for this account or app." >&2
        cat "$response_body" >&2
        exit 1
        ;;
    *)
        echo "Mercado Libre /users/me validation failed with HTTP ${users_me_status_code}." >&2
        cat "$response_body" >&2
        exit 1
        ;;
esac

status_code="$(curl -sS \
    -o "$response_body" \
    -w "%{http_code}" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    --get \
    --data-urlencode "q=${query}" \
    --data-urlencode "status=active" \
    --data-urlencode "site_id=${site_id}" \
    --data-urlencode "limit=1" \
    "https://api.mercadolibre.com/products/search")"

case "$status_code" in
    2??)
        echo "Live Mercado Libre validation succeeded for site ${site_id}."
        ;;
    401)
        echo "Mercado Libre rejected /products/search with HTTP 401. Refresh the access token." >&2
        cat "$response_body" >&2
        exit 1
        ;;
    403)
        echo "Mercado Libre rejected /products/search with HTTP 403. The token is valid for /users/me but not allowed for catalog product search." >&2
        cat "$response_body" >&2
        exit 1
        ;;
    *)
        echo "Mercado Libre validation failed with HTTP ${status_code}." >&2
        cat "$response_body" >&2
        exit 1
        ;;
esac
