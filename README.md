# MeLi Lite

MeLi Lite is a SwiftUI Mercado Libre sample app focused on product search and product detail flows. The project uses MVVM by feature, async/await networking, an explicit repository boundary, and two runtime data sources: deterministic demo fixtures and the live Mercado Libre API.

## Highlights

- Search, empty, loading, error, and detail states built with SwiftUI.
- `demo` mode backed by local fixtures for previews, CI, and offline review.
- `live` mode backed by Mercado Libre endpoints through an authenticated API client.
- OAuth session bootstrap with browser handoff, pasted callback validation, token exchange, refresh, and Keychain persistence.
- Runtime toolbar switch between `demo` and `live` without relaunching the app.
- Swift Testing unit coverage plus demo-mode UI smoke tests.

## Project Structure

- `MELISearch/App`: application entry point, dependency container, and root navigation.
- `MELISearch/Core`: configuration, error modeling, logging, reachability, OAuth, and Keychain storage.
- `MELISearch/Domain`: app-facing models and repository contract.
- `MELISearch/Data`: Mercado Libre endpoints, DTO mapping, API client, and repository factories.
- `MELISearch/Features/Search`: search screen, row UI, OAuth sheet, and search view model.
- `MELISearch/Features/Detail`: detail screen and detail view model.
- `MELISearchTests`: Swift Testing unit tests.
- `MELISearchUITests`: XCTest UI smoke tests.

## Architecture

The app keeps UI code isolated from the transport layer:

- `ContentView` owns the active `AppContainer` and rebuilds it when the runtime data source changes.
- `SearchViewModel` and `ProductDetailViewModel` are `@Observable` `@MainActor` state holders for SwiftUI.
- `ProductRepository` hides whether data comes from demo fixtures or Mercado Libre.
- `MELIAPIClient` centralizes authenticated requests, decoding, status mapping, and light detail caching.
- `MELIAuthenticationSession` resolves the active live credential source and manages OAuth lifecycle work.

### Runtime architecture

```mermaid
flowchart LR
    A["MeLiLiteApp"] --> B["ContentView"]
    B --> C["AppContainer"]
    C --> D["SearchScreen"]
    D --> E["SearchViewModel"]
    E --> F["ProductRepository"]
    F --> G["DemoProductRepository"]
    F --> H["LiveProductRepository"]
    H --> I["MELIAPIClient"]
    I --> J["MELIAuthenticationSession"]
    J --> K["KeychainStore"]
    J --> L["Mercado Libre OAuth /oauth/token"]
    I --> M["Mercado Libre API /sites, /items"]
```

### Composition root

```mermaid
flowchart TD
    A["ContentView"] --> B["AppConfiguration"]
    A --> C["MELIAuthenticationSession"]
    A --> D["AppContainer"]
    D --> E["ProductRepository"]
    D --> F["SearchViewModel"]
    D --> G["ConnectivityMonitor"]
    A --> H{"Toolbar switch"}
    H -- "Use Demo Data" --> I["Rebuild container with demo repository"]
    H -- "Use Live API" --> J["Rebuild container with live repository"]
```

### Layer overview

```mermaid
flowchart LR
    A["SearchScreen"] --> B["SearchViewModel"]
    C["ProductDetailScreen"] --> D["ProductDetailViewModel"]
    B --> E["ProductRepository"]
    D --> E
    E --> F["LiveProductRepository"]
    E --> G["DemoProductRepository"]
    F --> H["MELIAPIClient"]
    H --> I["Mercado Libre API"]
```

## Data Sources

### Demo mode

`demo` mode uses `DemoProductRepository` and in-memory fixtures only. It is the safest way to review the app because it does not depend on network connectivity or external API behavior.

### Live mode

`live` mode uses `LiveProductRepository`, `MELIAPIClient`, and `MELIAuthenticationSession`. Mercado Libre product requests may reject anonymous access, so live requests should be treated as authenticated-only in practice.

The search screen exposes a runtime menu to switch between both modes. Switching mode rebuilds the app container and resets navigation and search state so the UI reflects the newly selected backend immediately.

## OAuth Flow

`MELIAuthenticationSession` supports three live credential sources:

1. `MELI_ACCESS_TOKEN` from the process environment.
2. A previously stored OAuth session loaded from Keychain.
3. A new authorization-code flow started from the in-app OAuth sheet.

The in-app OAuth flow is intentionally manual:

- The app opens Mercado Libre authorization in the system browser.
- After consent, the user pastes the full callback URL back into the app.
- The app validates the redirect origin and `state` before exchanging the code.
- The resulting session is stored in Keychain and refreshed automatically when needed.

Unless you add Universal Links or a custom URL scheme, the callback will not return to the app automatically.

### Launch auth resolution

```mermaid
flowchart TD
    A["App Launch"] --> B["AppContainer creates MELIAuthenticationSession"]
    B --> C{"MELI_DATA_SOURCE == demo?"}
    C -- Yes --> D["Use Demo Repository"]
    C -- No --> E{"MELI_ACCESS_TOKEN present?"}
    E -- Yes --> F["Use environment bearer token"]
    E -- No --> G{"OAuth config complete?"}
    G -- No --> H["Show missing configuration state"]
    G -- Yes --> I{"Stored Keychain session exists?"}
    I -- No --> J["Prompt for interactive OAuth"]
    I -- Yes --> K{"Token near expiry?"}
    K -- No --> L["Use stored access token"]
    K -- Yes --> M["Refresh token via /oauth/token"]
```

### Authorization-code flow

```mermaid
sequenceDiagram
    participant User
    participant App
    participant Browser
    participant MercadoLibre
    participant Keychain

    User->>App: Open "Connect OAuth"
    App->>Browser: Open authorization URL with state
    Browser->>MercadoLibre: Request user consent
    MercadoLibre-->>Browser: Redirect to registered callback URL
    User->>App: Paste full callback URL
    App->>App: Validate redirect origin and state
    App->>MercadoLibre: POST /oauth/token
    MercadoLibre-->>App: access_token + refresh_token + user_id + scope
    App->>Keychain: Persist refreshable session
    App->>MercadoLibre: Search and item requests with Bearer token
```

## Environment Variables

The runtime configuration is resolved from scheme or process environment variables:

- `MELI_DATA_SOURCE`: `demo` or `live`.
- `MELI_SITE_ID`: Mercado Libre site identifier such as `MCO`.
- `MELI_ACCESS_TOKEN`: optional bearer token for immediate live access.
- `MELI_APP_ID`: OAuth client id.
- `MELI_CLIENT_SECRET`: OAuth client secret.
- `MELI_REDIRECT_URL`: redirect URL registered in Mercado Libre.
- `MELI_AUTH_HOST`: optional Mercado Libre auth host override.

For live mode, the app needs either:

- `MELI_ACCESS_TOKEN`, or
- a complete OAuth configuration made of `MELI_APP_ID`, `MELI_CLIENT_SECRET`, and `MELI_REDIRECT_URL`.

The shared `MELISearch` scheme currently includes live-mode environment variables. Review `Edit Scheme > Run > Environment Variables` before sharing the project, changing accounts, or validating a different Mercado Libre app configuration. UI tests override those values and always launch the app in `demo` mode.

## Running The App

1. Open `MELISearch.xcodeproj` in Xcode.
2. Select the `MELISearch` scheme.
3. Decide whether you want to review the app in `demo` or `live` mode.
4. If needed, adjust the environment variables in the scheme.
5. Run the app on macOS or iOS and use the toolbar menu to switch data source at runtime.

If you want to validate a token from the shell before launching the app, run:

```sh
scripts/check_live_env.sh
```

The script exits early in `demo` mode and reports clearer failures for common live-mode authorization problems.

## Testing

Build tests from the command line with:

```sh
xcodebuild build-for-testing -project MELISearch.xcodeproj -scheme MELISearch -destination 'platform=macOS'
```

Run the suite with:

```sh
xcodebuild test -project MELISearch.xcodeproj -scheme MELISearch -destination 'platform=macOS'
```

Coverage currently includes:

- `AppConfiguration`, `AppError`, `ConnectivityMonitor`, and OAuth session behavior.
- `SearchViewModel` and `ProductDetailViewModel` state transitions.
- Mercado Libre DTO-to-domain mapping.
- Demo-mode UI smoke tests for launch, search, and navigation to detail.

### Request sequence

```mermaid
sequenceDiagram
    participant User
    participant SearchScreen
    participant SearchViewModel
    participant Repository
    participant API

    User->>SearchScreen: Submit query
    SearchScreen->>SearchViewModel: search()
    SearchViewModel->>Repository: searchProducts(query)
    Repository->>API: GET /sites/{site}/search?q=...
    API-->>Repository: Search payload
    Repository-->>SearchViewModel: [ProductSummary]
    SearchViewModel-->>SearchScreen: loaded state
```

## Documentation

- The app source now includes SwiftDoc comments for the main types, properties, and behaviors across `App`, `Core`, `Domain`, `Data`, and feature modules.
- AI-assisted implementation notes live in [`docs/AI_USAGE.md`](docs/AI_USAGE.md).
