# MeLi Lite

MeLi Lite is a SwiftUI iOS challenge app that implements product search and product detail using an MVVM architecture, modern async/await networking, explicit error handling, and unit/UI tests.

## What is included

- Product search flow with user feedback for idle, loading, empty, success and failure states.
- Product detail flow with image gallery, pricing, shipping, attributes and external link.
- MVVM by feature with a repository-driven data layer.
- Demo catalog enabled by default so the app stays fully navigable even when Mercado Libre blocks anonymous requests.
- Demo placeholders are local-only, so the default experience also works in sandboxed environments without outbound network access.
- Live API wiring prepared through environment variables.
- Architecture and AI usage documentation under [`docs/ARCHITECTURE.md`](/Users/juandiegoocampo/Downloads/MeLi-Lite/docs/ARCHITECTURE.md) and [`docs/AI_USAGE.md`](/Users/juandiegoocampo/Downloads/MeLi-Lite/docs/AI_USAGE.md).

## Live API note

The PDF states that search works without authentication, but current Mercado Libre behavior does not match that anymore.

- On April 2, 2026, `GET https://api.mercadolibre.com/sites/MLA/search?q=iphone&limit=1` returned `403 forbidden`.
- On April 2, 2026, `GET https://api.mercadolibre.com/products/MLA10025564` returned `authorization value not present`.
- Mercado Libre official documentation for `Items & Searches`, crawled on March 2026, now documents bearer-token usage for current search-related resources.

Because of that, the app defaults to demo mode and keeps the live integration behind configuration.

## Configuration

The shared scheme now starts in demo mode and does not ship a token. Use demo mode with no extra setup, or enable live mode through local environment variables in your own scheme:

- `MELI_DATA_SOURCE=live`
- `MELI_ACCESS_TOKEN=<your token>`
- `MELI_SITE_ID=MCO`

If `MELI_DATA_SOURCE` is unset, the app still switches to live mode when `MELI_ACCESS_TOKEN` is present. If you want to keep a token locally but force demo, set `MELI_DATA_SOURCE=demo`.

Before running in live mode, you can validate the local configuration with:

```sh
scripts/check_live_env.sh
```

The script exits early when demo mode is active and reports a clearer failure when Mercado Libre rejects the token with `401` or `403`.

## Architecture

The app follows MVVM per feature:

- `Features/Search`: search UI plus `SearchViewModel`.
- `Features/Detail`: detail UI plus `ProductDetailViewModel`.
- `Domain`: app-facing models and repository contract.
- `Data`: live Mercado Libre client, DTO mapping and demo repository.
- `Core`: configuration, logging and unified error model.

More detail is documented in [`docs/ARCHITECTURE.md`](/Users/juandiegoocampo/Downloads/MeLi-Lite/docs/ARCHITECTURE.md).

## Testing

- Swift Testing unit tests cover search state transitions, detail loading behavior and DTO mapping.
- XCTest UI tests cover the demo-mode happy path from search to detail.
