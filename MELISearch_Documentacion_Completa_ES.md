# Documentación completa de MELISearch

## 1. Qué es esta app

`MELISearch` es una aplicación SwiftUI que permite:

- Buscar productos en Mercado Libre.
- Ver el detalle de un producto.
- Autenticarse con OAuth para usar la API real.
- Cambiar en tiempo de ejecución entre datos demo y API live.
- Guardar productos favoritos y volver a verlos sin hacer la búsqueda otra vez.

En este momento la app está diseñada como una app multiplataforma Apple moderna:

- Swift 6.
- SwiftUI.
- Observation (`@Observable`, `@Bindable`) en lugar de `ObservableObject`.
- `async/await` para networking y autenticación.
- `URLSession`, `NWPathMonitor`, `WKWebView`, `Keychain`, `UserDefaults`.

No usa Combine ni Core Data. Toda la persistencia actual es:

- `Keychain` para sesión OAuth y configuración OAuth persistida.
- `UserDefaults` para favoritos.

## 2. Resumen de arquitectura

La arquitectura real de la app es una mezcla muy limpia de:

- `Composition Root` en la capa `App`.
- `Repository Pattern` para desacoplar UI de la fuente de datos.
- `DTO -> Domain Mapping` en la capa `Data/API`.
- `ViewModel + SwiftUI View` por feature.
- `Session Coordinator` dedicado para autenticación OAuth.

La separación por carpetas es:

- `App`: arranque, composición de dependencias y navegación raíz.
- `Core`: configuración, errores, logging, autenticación, reachability, keychain y favoritos.
- `Domain`: modelos de negocio y el contrato de repositorio.
- `Data/API`: endpoints, cliente HTTP y DTOs del backend.
- `Data/Repositories`: implementación live y demo del repositorio.
- `Features/Search`: búsqueda, UI principal y flujo OAuth.
- `Features/Detail`: detalle del producto.
- `Features/Favorites`: lista de favoritos.
- `Tests` y `UITests`: validación de comportamiento.

## 3. Flujo general de ejecución

### 3.1 Arranque

1. `MELISearchApp` crea un `AppContainer.main()`.
2. `AppContainer` resuelve:
   - `AppConfiguration`
   - `MELIAuthenticationSession`
   - `ProductRepository` live o demo
   - `ConnectivityMonitor`
   - `FavoritesStore`
3. `ContentView` recibe ese contenedor y crea el árbol principal.

### 3.2 Navegación raíz

La raíz usa `TabView` con dos pestañas:

- `Search`
- `Favorites`

Cada pestaña tiene su propio `NavigationStack`. Eso es importante porque:

- La navegación de búsqueda y la de favoritos no se pisan.
- Ambas pueden navegar al mismo `ProductDetailScreen`.

### 3.3 Cambio de fuente de datos

La app permite cambiar entre:

- `demo`
- `live`

Cuando el usuario cambia de fuente:

- `ContentView` construye un `AppContainer` nuevo.
- Reinyecta `authenticationSession`, `productRepository` y `connectivityMonitor`.
- Conserva el mismo `FavoritesStore`, así que los favoritos no se pierden.
- Cambia `navigationIdentity` para resetear la pila de navegación.

## 4. Configuración del proyecto y plataforma

### 4.1 Ajustes observados en el proyecto

Según `project.pbxproj` y `xcodebuild -showBuildSettings`:

- `SWIFT_VERSION = 6.0`
- `PRODUCT_BUNDLE_IDENTIFIER = com.jdocampo.MeLi-Lite`
- `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`
- `TARGETED_DEVICE_FAMILY = 1,2,7`
- `IPHONEOS_DEPLOYMENT_TARGET = 26.4`
- `MACOSX_DEPLOYMENT_TARGET = 26.4`

Eso significa que el proyecto está preparado para:

- iPhone
- iPad
- macOS
- visionOS

La app que ejecuté y probé localmente corre sobre macOS, pero el código tiene ramas condicionales para iOS y macOS.

### 4.2 Entitlements

`MELISearch.entitlements` define:

- `com.apple.security.app-sandbox = true`
- `com.apple.security.files.user-selected.read-only = true`
- `com.apple.security.network.client = true`

Interpretación:

- La app corre sandboxed.
- Puede hacer networking saliente.
- Puede leer archivos seleccionados por el usuario, pero no tiene acceso arbitrario al disco.

## 5. Capa App

### 5.1 `MELISearchApp`

Archivo: `MELISearch/App/MELISearchApp.swift`

Responsabilidad:

- Es el entry point de SwiftUI (`@main`).
- Construye una sola vez el `AppContainer`.
- Inyecta `ContentView`.
- Fuerza `preferredColorScheme(.light)`.

Detalle importante:

- La decisión de composición ocurre muy temprano. La UI nunca construye dependencias por su cuenta.

### 5.2 `AppContainer`

Archivo: `MELISearch/App/AppContainer.swift`

Responsabilidad:

- Es el `composition root`.
- Reúne dependencias compartidas para toda la app.

Objetos que contiene:

- `configuration: AppConfiguration`
- `authenticationSession: MELIAuthenticationSession`
- `productRepository: ProductRepository`
- `connectivityMonitor: ConnectivityMonitor`
- `favoritesStore: FavoritesStore`

Detalle importante:

- Si `configuration.isUsingDemoData == true`, usa `DemoProductRepository`.
- Si no, usa `LiveProductRepository`.
- Reutiliza el mismo `FavoritesStore` cuando se cambia de data source.

### 5.3 `ContentView`

Archivo: `MELISearch/App/ContentView.swift`

Responsabilidad:

- Es la raíz visual real de la aplicación.
- Conserva estado de alto nivel.
- Define la navegación principal.

Estado que mantiene:

- `activeContainer`
- `authenticationSession`
- `viewModel` de búsqueda
- `connectivityMonitor`
- `favoritesStore`
- `navigationIdentity`
- `selectedTab`

Subtipos y helpers:

- `RootTab`
  - `.search`
  - `.favorites`

Puntos clave:

- Usa `TabView`.
- Cada tab tiene su propio `NavigationStack`.
- Ambas rutas navegan a `ProductDetailScreen` usando `navigationDestination(for: ProductSummary.self)`.
- Atiende callbacks OAuth con `.onOpenURL`.
- Llama `authenticationSession.prepareIfNeeded()` en `.task`.

Detalle fino:

- `SearchScreen` también llama `prepareIfNeeded()`.
- Eso no genera problema porque `MELIAuthenticationSession` protege la preparación con `hasPrepared`.

### 5.4 `AppNavigationBarStyle`

Archivo: `MELISearch/App/AppNavigationBarStyle.swift`

Responsabilidad:

- Uniformar estilo de barra de navegación.

Comportamiento:

- En iOS aplica color de toolbar, esquema claro y `toolbarTitleDisplayMode(.inlineLarge)`.
- En macOS no altera el comportamiento por defecto.

## 6. Capa Core

## 6.1 `AppConfiguration`

Archivo: `MELISearch/Core/AppConfiguration.swift`

Es uno de los tipos más importantes de la app.

Responsabilidad:

- Resolver la configuración runtime desde variables de entorno.
- Determinar si la app corre en modo demo o live.
- Construir la configuración OAuth completa si los datos existen.
- Reusar configuración OAuth persistida cuando la app se relanza fuera de Xcode.

Propiedades principales:

- `dataSource`
- `siteID`
- `accessToken`
- `oauthClientID`
- `oauthClientSecret`
- `oauthRedirectURL`
- `oauthAuthorizationHost`
- `uiTestAuthenticationState`

Subtipos:

- `PersistedOAuthConfiguration`
  - Guarda `siteID`, `oauthClientID`, `oauthClientSecret`, `oauthRedirectURL`, `oauthAuthorizationHost`.
- `DataSource`
  - `.demo`
  - `.live`
- `UITestAuthenticationState`
  - `.authenticated`

Variables de entorno soportadas:

- `MELI_DATA_SOURCE`
- `MELI_SITE_ID`
- `MELI_ACCESS_TOKEN`
- `MELI_APP_ID`
- `MELI_CLIENT_SECRET`
- `MELI_REDIRECT_URL`
- `MELI_AUTH_HOST`
- `MELI_UI_TEST_AUTH_STATE`

Reglas de resolución:

- Si `MELI_DATA_SOURCE=demo`, demo gana aunque exista token.
- Si no hay `MELI_DATA_SOURCE` pero sí token o configuración OAuth completa, entra en live.
- Si no hay nada, cae en demo.
- Si no se informa `siteID`, usa `MCO` por defecto.

Propiedades derivadas importantes:

- `isUsingDemoData`
- `environmentBadge`
- `oauthConfiguration`
- `assistantNote`

Métodos importantes:

- `resolve(environment:)`
- `resolve(environment:persistedOAuthConfiguration:)`
- `overriding(dataSource:)`

### 6.1.1 `PersistedOAuthConfigurationStore`

Es un tipo `private` dentro del mismo archivo.

Responsabilidad:

- Persistir una configuración OAuth completa en Keychain.
- Mezclar variables de entorno nuevas con configuración persistida previa.

Qué guarda:

- No guarda la sesión OAuth.
- Guarda la configuración necesaria para volver a autorizar más tarde.

Diferencia importante:

- Configuración OAuth persistida: app id, secret, redirect y host.
- Sesión OAuth persistida: access token, refresh token, expiración y user id.

### 6.1.2 `String.trimmedNonEmptyValue`

Helper privado.

Responsabilidad:

- Normalizar strings del entorno.
- Evitar usar strings vacíos como si fueran configuración válida.

## 6.2 `AppError`

Archivo: `MELISearch/Core/AppError.swift`

Responsabilidad:

- Ser el error de dominio unificado de la app.
- Traducir errores técnicos en mensajes consistentes para UI, logging y recuperación.

Casos:

- `missingAccessToken`
- `invalidUserAccessToken`
- `missingOAuthConfiguration`
- `invalidAuthorizationCallback`
- `invalidURL`
- `invalidResponse`
- `unauthorized`
- `forbidden`
- `httpStatus(Int)`
- `decoding(String)`
- `transport(URLError.Code)`
- `unknown(String)`

Capacidades:

- `from(_ error: Error)`
- `errorDescription`
- `recoverySuggestion`
- `developerDescription`

Por qué importa:

- La UI nunca muestra errores de `URLSession` o `DecodingError` crudos.
- Todo pasa por este tipo.

## 6.3 `AppLogger`

Archivo: `MELISearch/Core/AppLogger.swift`

Responsabilidad:

- Centralizar categorías de `OSLog`.

Categorías:

- `authentication`
- `networking`
- `ui`

## 6.4 `ConnectivityMonitor`

Archivo: `MELISearch/Core/ConnectivityMonitor.swift`

Responsabilidad:

- Observar conectividad de red con `NWPathMonitor`.
- Exponer estado observable para la UI.
- Emitir `NotificationCenter` para observadores no SwiftUI.

Tipos relacionados:

- `Notification.Name.connectivityStatusDidChange`
- `ConnectivityStatus`
  - `.unknown`
  - `.connected`
  - `.disconnected`
- `ConnectivityStatusNotificationKey`
  - `previousStatus`
  - `currentStatus`
  - `isConnected`

Puntos importantes:

- Es `@Observable` y `@MainActor`.
- Tiene dos inicializadores:
  - uno real con `NWPathMonitor`
  - uno para tests con `AsyncStream<ConnectivityStatus>`
- Solo emite notificación si el estado realmente cambió.

## 6.5 `KeychainStore`

Archivo: `MELISearch/Core/KeychainStore.swift`

Responsabilidad:

- Encapsular acceso a Keychain.

API:

- `load()`
- `save(_:)`
- `delete()`

Campos:

- `service`
- `account`

Error asociado:

- `KeychainStoreError.unexpectedStatus(OSStatus)`

Uso dentro de la app:

- Persistencia de configuración OAuth.
- Persistencia de sesión OAuth.

## 6.6 `MELIOAuthConfiguration`

Archivo: `MELISearch/Core/MELIOAuthConfiguration.swift`

Responsabilidad:

- Representar la configuración OAuth lista para usarse.

Campos:

- `clientID`
- `clientSecret`
- `redirectURL`
- `authorizationHost`

Propiedades derivadas:

- `authorizationEndpoint`
- `tokenEndpoint`

Método clave:

- `defaultAuthorizationHost(forSiteID:)`

Observación importante:

- El host de autorización cambia por país.
- El token endpoint sí es único: `https://api.mercadolibre.com/oauth/token`.

## 6.7 `MELIAuthenticationSession`

Archivo: `MELISearch/Core/MELIAuthenticationSession.swift`

Es el coordinador de autenticación de la app.

Responsabilidad:

- Resolver si la app está en demo, live con token de entorno, live con sesión persistida o signed out.
- Construir URL de autorización OAuth.
- Intercambiar authorization code por tokens.
- Refrescar tokens expuestos por Keychain.
- Validar la sesión actual con `/users/me`.
- Hacer fallback a `MELI_ACCESS_TOKEN` cuando una sesión persistida falla.
- Exponer estado legible por la UI.

### 6.7.1 Estados públicos

`Status`:

- `demoMode`
- `usingEnvironmentAccessToken`
- `missingConfiguration`
- `signedOut`
- `authorizing`
- `exchangingCode`
- `refreshing`
- `authenticated`
- `failed(AppError)`

`SessionValidation`:

- `idle`
- `validating`
- `validated(ValidatedUser)`
- `failed(AppError)`

`ValidatedUser`:

- `id`
- `nickname`
- `siteID`

### 6.7.2 Estado interno relevante

- `configuration`
- `oauthConfiguration`
- `keychainStore`
- `urlSession`
- `status`
- `currentUserID`
- `currentSiteID`
- `latestError`
- `sessionValidation`
- `persistedCredentials`
- `pendingAuthorization`
- `hasPrepared`

### 6.7.3 API pública importante

- `prepareIfNeeded()`
- `authorizationURL()`
- `canHandleAuthorizationCallback(_:)`
- `completeAuthorization(from:)`
- `completeAuthorizationIfPossible(from:)`
- `cancelInteractiveAuthorization()`
- `signOut()`
- `validAccessToken()`
- `resolvedSearchSiteID()`
- `validateCurrentSession()`

### 6.7.4 Cómo arranca la sesión

`prepareIfNeeded()` sigue este orden:

1. Aplica override de UI tests si existe.
2. Si está en demo, queda en `demoMode`.
3. Intenta cargar credenciales persistidas.
4. Si las credenciales existen:
   - si necesitan refresh, intenta refresh
   - si no, entra en `authenticated`
5. Si no hay sesión persistida válida, intenta usar `MELI_ACCESS_TOKEN`.
6. Si el token de entorno existe pero no es `APP_USR-`, lo considera inválido.
7. Si no puede usar token y sí puede hacer OAuth, queda en `signedOut`.
8. Si tampoco tiene OAuth completo, queda en `missingConfiguration`.

### 6.7.5 Reglas de token

La app exige token user-scoped para búsquedas live:

- válido: `APP_USR-...`
- inválido para search: `APP-...`

Eso se valida tanto en la sesión como en el API client.

### 6.7.6 OAuth Authorization Code Flow

Paso a paso:

1. `authorizationURL()` crea `PendingAuthorization`.
2. Genera un `state` aleatorio.
3. Construye la URL de autorización con:
   - `response_type=code`
   - `client_id`
   - `redirect_uri`
   - `state`
4. La web view carga esa URL.
5. Cuando Mercado Libre redirige al `redirectURL`, la app captura la URL completa.
6. `completeAuthorization(from:)` valida:
   - URL bien formada
   - redirect exacto
   - `code`
   - `state` correcto
7. `exchangeAuthorizationCode(using:)` hace POST a `/oauth/token`.
8. La respuesta se persiste en Keychain como `StoredCredentials`.

### 6.7.7 Importante: no usa PKCE

Hay una prueba explícita que confirma que la URL no incluye:

- `code_challenge`
- `code_challenge_method`

Implicación:

- El flujo actual depende de `client_secret`.
- Para una app de escritorio o móvil productiva, esto es un punto de discusión fuerte de seguridad/arquitectura.

En una entrevista, esto se puede presentar como:

- una simplificación deliberada para el challenge
- un área clara de mejora

### 6.7.8 Refresh token

Si hay sesión persistida:

- `StoredCredentials.requiresRefresh` devuelve `true` si expira en menos de 5 minutos.
- `refreshStoredCredentials()` usa `grant_type=refresh_token`.
- Al refrescar, vuelve a persistir la sesión.

### 6.7.9 Validación con `/users/me`

`validateCurrentSession()`:

- pide `validAccessToken()`
- llama a `https://api.mercadolibre.com/users/me`
- decodifica `ValidatedUser`
- rellena `currentUserID` y `currentSiteID`
- actualiza `sessionValidation`

Esto sirve para:

- confirmar que el bearer token funciona
- saber el `site_id` real del usuario

### 6.7.10 Tipos privados internos

`AuthorizationCode`

- wrapper mínimo del código ya normalizado.

`PendingAuthorization`

- guarda el `state` del intento OAuth activo.

`StoredCredentials`

- `accessToken`
- `refreshToken`
- `expirationDate`
- `scope`
- `userID`

`TokenResponse`

- DTO interno de la respuesta OAuth.

`CharacterSet.urlQueryValueAllowed`

- helper para percent-encoding de form data.

Helpers privados importantes:

- `mapStatusCode(_:)`
- `applyUITestAuthenticationOverride()`
- `validatedEnvironmentAccessToken(loggingFallbackFrom:)`
- `activateEnvironmentAccessTokenIfAvailable(loggingFallbackFrom:)`

## 6.8 `FavoritesStore`

Archivo: `MELISearch/Core/FavoritesStore.swift`

Responsabilidad:

- Persistir favoritos en `UserDefaults`.
- Exponerlos como estado observable.

API:

- `contains(_:)`
- `add(_:)`
- `remove(id:)`
- `remove(_:)`
- `toggle(_:)`

Comportamiento:

- Si agregas un favorito existente, lo mueve al frente.
- Evita duplicados por `id`.
- Persiste después de mutar.

Limitación actual:

- Guarda `ProductSummary`, no el `ProductDetail`.
- Eso está bien porque la pantalla de favoritos solo necesita la información resumida para listar y navegar.

## 7. Capa Domain

## 7.1 `ProductSummary`

Archivo: `MELISearch/Domain/ProductModels.swift`

Responsabilidad:

- Modelo ligero para resultados de búsqueda y navegación.

Campos:

- `id`
- `title`
- `subtitle`
- `price`
- `currencyCode`
- `thumbnailURL`
- `permalinkURL`
- `condition`
- `availableQuantity`
- `soldQuantity`
- `attributes`
- `shipping`

Protocolos:

- `Identifiable`
- `Hashable`
- `Codable`
- `Sendable`

`Codable` es importante porque ahora se persiste en favoritos.

## 7.2 `ProductDetail`

Responsabilidad:

- Modelo rico para la pantalla de detalle.

Campos adicionales respecto a `ProductSummary`:

- `imageURLs`
- `warranty`
- `description`

## 7.3 `ProductAttribute`

- `id`
- `name`
- `value`

Uso:

- chips y grids de atributos.
- persistible porque es `Codable`.

## 7.4 `ShippingInfo`

- `isFreeShipping`
- `isStorePickupAvailable`
- `static let unavailable`

Uso:

- resume shipping sin exponer DTOs del backend a la UI.

## 7.5 `ProductRepository`

Responsabilidad:

- contrato de acceso a productos.

Implementación:

- no es un protocolo; es un struct con closures:
  - `search`
  - `detail`

Ventaja:

- es muy fácil de mockear en tests.
- la UI no depende de una clase concreta.

## 8. Capa Data/API

## 8.1 `MELIEndpoint`

Archivo: `MELISearch/Data/API/MELIEndpoint.swift`

Responsabilidad:

- centralizar definición de endpoints de Mercado Libre.

Casos:

- `productSearch(query:siteID:)`
- `productDetail(id:)`

Comportamiento:

- arma `URLRequest`
- agrega `Accept: application/json`
- agrega `Authorization: Bearer ...` si hay token

Políticas declaradas:

- `prefersAnonymousAccess`
- `allowsAnonymousAccess`
- `requiresUserAccessToken`

Estado actual:

- ambos endpoints requieren token user-scoped
- no hay endpoints públicos activos en esta app

Rutas:

- búsqueda: `/products/search`
- detalle: `/products/{id}`

Query de búsqueda:

- `status=active`
- `site_id`
- `q`

## 8.2 `MELIAPIClient`

Archivo: `MELISearch/Data/API/MELIAPIClient.swift`

Responsabilidad:

- ejecutar requests live autenticados
- mapear payloads
- traducir fallos a `AppError`
- cachear detalle en memoria

Dependencias:

- `configuration`
- `accessTokenProvider`
- `searchSiteIDProvider`
- `urlSession`

Estado:

- `detailCache: [String: ProductDetail]`

API pública:

- `searchProducts(matching:)`
- `fetchProductDetail(id:)`

Flujo de request:

1. decide el endpoint
2. pide token al `accessTokenProvider`
3. valida que el token sea `APP_USR-` si el endpoint lo requiere
4. ejecuta `URLSession.data(for:)`
5. valida `HTTPURLResponse`
6. decodifica con `JSONDecoder` y `convertFromSnakeCase`
7. mapea errores a `AppError`

Aspectos importantes:

- tiene soporte para request anónima y retry sin auth, pero hoy está apagado porque `allowsAnonymousAccess == false`
- usa cache in-memory solo para detalle, no para búsqueda

Helper privado:

- `String.isMercadoLibreUserAccessToken`

## 8.3 DTOs de Mercado Libre

Archivo: `MELISearch/Data/API/MercadoLibreDTOs.swift`

Esta es la capa que traduce JSON de Mercado Libre a modelos de dominio.

### 8.3.1 `MercadoProductSearchResponseDTO`

- representa la respuesta top-level de búsqueda
- expone `results`

### 8.3.2 `MercadoProductSearchResultDTO`

- representa un producto de catálogo en búsqueda
- expone `summary`

### 8.3.3 `MercadoProductDTO`

- representa el payload de detalle
- expone `detail`

### 8.3.4 `MercadoCatalogProductPayload`

Protocolo privado usado para compartir lógica entre búsqueda y detalle:

- `familyName`
- `attributes`
- `pictures`
- `buyBoxWinner`
- `buyBoxWinnerPriceRange`

Esto evita duplicar:

- `mappedAttributes`
- `normalizedSubtitle`
- `resolvedPrice`
- `resolvedCurrencyCode`
- `imageURLs`

### 8.3.5 DTOs auxiliares

- `MercadoPictureDTO`
- `MercadoShippingDTO`
- `MercadoBuyBoxWinnerDTO`
- `MercadoPriceRangeDTO`
- `MercadoPriceDTO`
- `MercadoProductPickerDTO`
- `MercadoProductPickerOptionDTO`
- `MercadoShortDescriptionDTO`
- `MercadoAttributeDTO`

### 8.3.6 Regla de precio actual

La app resuelve precio así:

```swift
buyBoxWinner?.price ?? buyBoxWinnerPriceRange?.min?.price ?? 0
```

Implicación:

- Si el backend no trae `buy_box_winner.price`
- y tampoco trae `buy_box_winner_price_range.min.price`
- la UI termina mostrando `0`

Eso no significa necesariamente que el precio real sea cero.
Significa que el payload de catálogo no incluyó precio usable.

### 8.3.7 Regla de currency actual

La app resuelve moneda así:

```swift
buyBoxWinner?.currencyId ?? buyBoxWinnerPriceRange?.min?.currencyId ?? "ARS"
```

Implicación:

- si no llega moneda del backend, cae en `ARS` como default
- eso puede ser incorrecto si el producto realmente pertenece a otro sitio

### 8.3.8 Regla de imágenes

En search:

- usa `pictures`

En detail:

- usa `pictures`
- si no existen, usa thumbnails de `pickers`

### 8.3.9 Atributos

`MercadoAttributeDTO.model`:

- ignora atributos sin `valueName`
- solo convierte a `ProductAttribute` si hay valor visible

Helper privado:

- `String.nilIfEmpty`

## 9. Repositorios

## 9.1 `LiveProductRepository`

Archivo: `MELISearch/Data/Repositories/LiveProductRepository.swift`

Responsabilidad:

- crear un `ProductRepository` backed por `MELIAPIClient`

Es una factory, no guarda estado propio.

## 9.2 `DemoProductRepository`

Archivo: `MELISearch/Data/Repositories/DemoProductRepository.swift`

Responsabilidad:

- ofrecer un catálogo local in-memory
- permitir demo, previews, CI y desarrollo offline

Qué contiene:

- `catalog: [ProductDetail]` estático
- productos demo: iPhone, Sony, Kindle, Garmin, JBL

Cómo busca:

- trim del query
- ignora query vacío
- busca por título y atributos

Cómo devuelve detalle:

- busca por `id`
- si no existe, lanza `AppError.unknown`

Decisión importante:

- `imageURLs(for:)` siempre devuelve `[]`
- eso mantiene demo mode libre de dependencias externas y estable en CI

Helper:

- `ProductDetail.summary`

## 10. Feature Search

## 10.1 `SearchViewModel`

Archivo: `MELISearch/Features/Search/SearchViewModel.swift`

Responsabilidad:

- manejar el ciclo de vida de la búsqueda
- coordinar estado de UI
- guardar último query válido y timestamp

Estado:

- `query`
- `results`
- `state`
- `lastSubmittedQuery`
- `lastUpdatedAt`
- `searchGeneration`

Enum `State`:

- `idle`
- `loading`
- `loaded`
- `empty`
- `failed(AppError)`

Decisiones importantes:

- si `query` queda vacío, vuelve a `idle`
- trimea whitespace antes de buscar
- usa `searchGeneration` para invalidar resultados viejos de requests concurrentes

API:

- `search()`
- `repeatLastSearch()`
- `applySuggestion(_:)`

## 10.2 `SearchScreen`

Archivo: `MELISearch/Features/Search/SearchScreen.swift`

Es la pantalla principal de la app.

Responsabilidad:

- mostrar búsqueda
- mostrar banners de entorno, auth y conectividad
- mostrar estados `idle/loading/empty/error/results`
- abrir el sheet OAuth

Dependencias:

- `SearchViewModel`
- `ConnectivityMonitor`
- `MELIAuthenticationSession`
- callback `onSelectDataSource`

Estado UI local:

- `isSearchFieldFocused`
- `isOAuthSheetPresented`
- `isAuthenticationBannerExpanded`

Elementos importantes:

- `searchBar`
- `connectivityBanner`
- `environmentBanner`
- `liveAuthorizationBanner`
- `idleState`
- `loadingState`
- `emptyState`
- `errorState`
- `resultsState`

Toolbar:

- botón para enfocar/desenfocar búsqueda
- menú para cambiar entre demo y live

Lógica de auth visible:

- si está en demo, muestra banner explicativo
- si está en live, muestra banner de autorización
- si `shouldPromptForAuthorization` es `true`, abre el sheet automáticamente

Comportamiento refinado:

- cuando ya está autenticado, el banner live arranca colapsado
- se puede expandir para ver acciones
- si no está autenticado, queda expandido

## 10.3 `ProductRowView`

Archivo: `MELISearch/Features/Search/ProductRowView.swift`

Responsabilidad:

- renderizar una tarjeta de producto reutilizable para search y favorites

Muestra:

- thumbnail con `AsyncImage`
- título
- subtítulo
- precio
- chips de shipping y condición

## 10.4 `OAuthSetupSheet`

Archivo: `MELISearch/Features/Search/OAuthSetupSheet.swift`

Responsabilidad:

- guiar al usuario en el flujo OAuth

Estado local:

- `callbackInput`
- `browserSession`
- `localErrorMessage`
- `isSubmitting`

Secciones:

- `Status`
- `Authorize`
- `Callback`
- `Validate Session`
- `Session`

Acciones:

- abrir página de autorización
- intercambiar code manual o automáticamente
- validar `/users/me`
- olvidar sesión almacenada

Subtipo:

- `BrowserSession`

## 10.5 `OAuthAuthorizationWebViewSheet`

Archivo: `MELISearch/Features/Search/OAuthAuthorizationWebViewSheet.swift`

Responsabilidad:

- presentar la página de Mercado Libre dentro de la app
- capturar el redirect registrado

Dos implementaciones lógicas:

- macOS con wrapper explícito de `WKWebView`
- iOS usando `WebPage` y `WebView`

Estado:

- `didCaptureCallback`
- `loadErrorMessage`
- `isLoading`
- `estimatedProgress`
- `page` en iOS

Comportamiento clave:

- si la navegación llega al callback válido, captura la URL y cierra el sheet
- si el usuario cierra antes y no se autenticó, llama `cancelInteractiveAuthorization()`

Tipos privados relacionados:

- `OAuthAuthorizationWebView`
- `OAuthAuthorizationWebView.Coordinator`

Por qué existe el wrapper custom en macOS:

- el comentario del código dice que la solución SwiftUI previa causaba warnings de recursión de layout y fallas de carga
- por eso se usa `WKWebView` directamente

## 11. Feature Detail

## 11.1 `ProductDetailViewModel`

Archivo: `MELISearch/Features/Detail/ProductDetailViewModel.swift`

Responsabilidad:

- mantener el estado de carga del detalle
- exponer valores derivados listos para UI
- preservar el `ProductSummary` mientras el detalle completo carga

Estado:

- `product`
- `configuration`
- `state`
- `detail`

Enum `State`:

- `idle`
- `loading`
- `loaded`
- `failed(AppError)`

API:

- `loadIfNeeded()`
- `reload()`

Propiedades derivadas:

- `displayedTitle`
- `displayedSubtitle`
- `displayedPrice`
- `currencyCode`
- `imageURLs`
- `shipping`
- `displayedAttributes`
- `permalinkURL`
- `condition`
- `availableQuantity`
- `soldQuantity`
- `warranty`
- `descriptionText`

Decisión importante:

- antes de que llegue `detail`, la UI usa `summary`
- si el reload falla después de haber cargado una vez, mantiene el detalle anterior visible

## 11.2 `ProductDetailScreen`

Archivo: `MELISearch/Features/Detail/ProductDetailScreen.swift`

Responsabilidad:

- renderizar la pantalla de detalle completa

Secciones:

- galería
- resumen
- shipping
- atributos
- descripción
- error
- link a Mercado Libre

Estado local:

- `selectedImageIndex`
- `viewModel`
- `favoritesStore`

Elementos reutilizables:

- `FactCard`
- `ProductDetailNavigationTitleStyle`

Comportamiento:

- hace `loadIfNeeded()` en `.task`
- permite pull to refresh
- usa `AsyncImage`
- muestra placeholder si no hay imágenes
- guarda o quita favoritos desde toolbar

Detalle importante:

- el favorito se guarda usando `viewModel.product`, o sea el `ProductSummary` original
- no persiste el detalle enriquecido

## 12. Feature Favorites

## 12.1 `FavoritesScreen`

Archivo: `MELISearch/Features/Favorites/FavoritesScreen.swift`

Responsabilidad:

- mostrar el listado persistido de favoritos

Comportamiento:

- si no hay favoritos, muestra `ContentUnavailableView`
- si hay favoritos, muestra count y lista
- cada fila navega a `ProductDetailScreen`
- cada fila permite eliminar desde `contextMenu`

Importante:

- la pestaña Favorites es parte del root, no un modal ni una pantalla secundaria
- eso hace que el acceso a favoritos sea inmediato al abrir la app

## 13. Persistencia

### 13.1 Qué se guarda en Keychain

Configuración OAuth persistida:

- siteID
- app id
- client secret
- redirect URL
- authorization host

Sesión OAuth persistida:

- access token
- refresh token
- expiration date
- scope
- user id

### 13.2 Qué se guarda en UserDefaults

Favoritos:

- array de `ProductSummary`

Ventaja:

- simple
- rápido
- suficiente para el tamaño actual del feature

Desventaja:

- no hay metadata adicional
- no hay sincronización multi-device
- no hay orden manual, solo orden de último guardado

## 14. Navegación explicada de punta a punta

### 14.1 Flujo Search -> Detail

1. `SearchScreen` muestra resultados.
2. Cada fila usa `NavigationLink(value: product)`.
3. `ContentView` resuelve `navigationDestination(for: ProductSummary.self)`.
4. Se crea `ProductDetailScreen`.
5. `ProductDetailViewModel` arranca con `ProductSummary`.
6. Hace fetch del detalle completo.

### 14.2 Flujo Favorites -> Detail

1. `FavoritesScreen` lista `favoritesStore.favorites`.
2. Cada fila también navega con `NavigationLink(value: product)`.
3. Se reutiliza exactamente el mismo destino de detalle.

### 14.3 Flujo de cambio demo/live

1. Usuario abre `dataSourceMenu`.
2. Selecciona demo o live.
3. `ContentView.switchDataSource(to:)` reconstruye dependencias.
4. Se resetea la navegación.
5. Se preservan favoritos.

## 15. Estrategia de pruebas

La app tiene tres niveles de prueba.

### 15.1 Unit tests de Core

`AppConfigurationTests`

- validan resolución de entorno
- precedencia demo/live
- OAuth persistido
- override de host
- mensajes para UI

`MELIOAuthConfigurationTests`

- validan resolución de host por site

`MELIAuthenticationSessionTests`

- validan:
  - estado con token de entorno
  - falta de config
  - rechazo de callback inválido
  - construcción de URL auth
  - ausencia de PKCE
  - captura de user id
  - preferencia por sesión persistida
  - fallback desde token inválido a interactive OAuth
  - validación de `/users/me`
  - sign out

`AppErrorTests`

- validan mapeo y mensajes

`ConnectivityMonitorTests`

- validan transición de estados y notificaciones

`FavoritesStoreTests`

- validan persistencia, toggle y deduplicación

### 15.2 Tests de Data

`MELIMappingTests`

- validan DTO -> dominio

`MELIAPIClientTests`

- validan:
  - uso del bearer token
  - rechazo de tokens `APP-`
  - uso del site resuelto
  - endpoint de detalle de catálogo

### 15.3 UI tests

`MELISearchUITests`

- search -> detail
- filtrado de resultados demo
- banner live autenticado colapsable

`MELISearchUITestsLaunchTests`

- smoke test de lanzamiento

## 16. Objetos de test y por qué existen

La suite crea varios helpers de test. También vale la pena conocerlos porque muestran cómo está pensada la testabilidad.

Helpers de test:

- `StubMercadoLibreURLProtocol`
- `PublicCatalogFallbackURLProtocol`
- `PublicCatalogFallbackRequestRecorder`
- `SearchQueryRecorder`
- `TestDateProvider`
- `DetailCallCounter`
- `DetailSequence`
- `NotificationRecorder`
- extensiones mock de `ProductRepository`

Lo que demuestra:

- la app fue diseñada para ser testeable por composición
- no depende de singletons de red
- no depende de `ObservableObject` clásico
- no requiere mocks complejos de herencia

## 17. Inventario completo de tipos por archivo

Esta sección es el inventario explícito de objetos/tipos de la app.

### 17.1 App

`MELISearchApp.swift`

- `MELISearchApp`

`AppContainer.swift`

- `AppContainer`

`ContentView.swift`

- `ContentView`
- `ContentView.RootTab`

`AppNavigationBarStyle.swift`

- `AppNavigationBarStyle`

### 17.2 Core

`AppConfiguration.swift`

- `AppConfiguration`
- `AppConfiguration.PersistedOAuthConfiguration`
- `AppConfiguration.DataSource`
- `AppConfiguration.UITestAuthenticationState`
- `PersistedOAuthConfigurationStore`
- `String.trimmedNonEmptyValue`

`AppError.swift`

- `AppError`

`AppLogger.swift`

- `AppLogger`

`ConnectivityMonitor.swift`

- `Notification.Name.connectivityStatusDidChange`
- `ConnectivityStatus`
- `ConnectivityStatusNotificationKey`
- `ConnectivityMonitor`

`KeychainStore.swift`

- `KeychainStore`
- `KeychainStoreError`

`MELIOAuthConfiguration.swift`

- `MELIOAuthConfiguration`

`MELIAuthenticationSession.swift`

- `MELIAuthenticationSession`
- `MELIAuthenticationSession.Status`
- `MELIAuthenticationSession.SessionValidation`
- `MELIAuthenticationSession.ValidatedUser`
- `MELIAuthenticationSession.AuthorizationCode`
- `MELIAuthenticationSession.PendingAuthorization`
- `MELIAuthenticationSession.StoredCredentials`
- `MELIAuthenticationSession.TokenResponse`
- `CharacterSet.urlQueryValueAllowed`

`FavoritesStore.swift`

- `FavoritesStore`

### 17.3 Domain

`ProductModels.swift`

- `ProductSummary`
- `ProductDetail`
- `ProductAttribute`
- `ShippingInfo`

`ProductRepository.swift`

- `ProductRepository`

### 17.4 Data/API

`MELIEndpoint.swift`

- `MELIEndpoint`

`MELIAPIClient.swift`

- `MELIAPIClient`
- `String.isMercadoLibreUserAccessToken`

`MercadoLibreDTOs.swift`

- `MercadoProductSearchResponseDTO`
- `MercadoProductSearchResultDTO`
- `MercadoProductDTO`
- `MercadoCatalogProductPayload`
- `MercadoPictureDTO`
- `MercadoShippingDTO`
- `MercadoBuyBoxWinnerDTO`
- `MercadoPriceRangeDTO`
- `MercadoPriceDTO`
- `MercadoProductPickerDTO`
- `MercadoProductPickerOptionDTO`
- `MercadoShortDescriptionDTO`
- `MercadoAttributeDTO`
- `String.nilIfEmpty`

### 17.5 Data/Repositories

`LiveProductRepository.swift`

- `LiveProductRepository`

`DemoProductRepository.swift`

- `DemoProductRepository`
- `ProductDetail.summary`

### 17.6 Features/Search

`SearchViewModel.swift`

- `SearchViewModel`
- `SearchViewModel.State`

`SearchScreen.swift`

- `SearchScreen`
- `SearchNavigationSubtitleStyle`
- `SearchNavigationTitleStyle`
- `SearchTextFieldPlatformStyle`

`ProductRowView.swift`

- `ProductRowView`

`OAuthSetupSheet.swift`

- `OAuthSetupSheet`
- `OAuthSetupSheet.BrowserSession`

`OAuthAuthorizationWebViewSheet.swift`

- `OAuthAuthorizationWebViewSheet`
- `OAuthAuthorizationWebView`
- `OAuthAuthorizationWebView.Coordinator`

### 17.7 Features/Detail

`ProductDetailViewModel.swift`

- `ProductDetailViewModel`
- `ProductDetailViewModel.State`

`ProductDetailScreen.swift`

- `ProductDetailScreen`
- `ProductDetailNavigationTitleStyle`
- `FactCard`

### 17.8 Features/Favorites

`FavoritesScreen.swift`

- `FavoritesScreen`

### 17.9 Tests

`AppConfigurationTests.swift`

- `AppConfigurationTests`
- `MELIOAuthConfigurationTests`
- `MELIAuthenticationSessionTests`
- `StubMercadoLibreURLProtocol`

`AppErrorTests.swift`

- `AppErrorTests`

`ConnectivityMonitorTests.swift`

- `ConnectivityMonitorTests`
- `NotificationRecorder`

`MELIMappingTests.swift`

- `MELIMappingTests`

`MELIAPIClientTests.swift`

- `MELIAPIClientTests`
- `PublicCatalogFallbackRequestRecorder`
- `PublicCatalogFallbackURLProtocol`

`SearchViewModelTests.swift`

- `SearchViewModelTests`
- `SearchQueryRecorder`
- `TestDateProvider`
- `TestFixtures`
- `ProductRepository.mock`

`ProductDetailViewModelTests.swift`

- `ProductDetailViewModelTests`
- `DetailFixtures`
- `DetailCallCounter`
- `DetailSequence`
- `ProductRepository.detailMock`
- `ProductRepository.failingDetailMock`

`FavoritesStoreTests.swift`

- `FavoritesStoreTests`
- `TestFixtures`

`MELISearchUITests.swift`

- `MELISearchUITests`
- `XCUIApplication.element(withID:)`

`MELISearchUITestsLaunchTests.swift`

- `MELISearchUITestsLaunchTests`

## 18. Decisiones de diseño que conviene mencionar en una entrevista

### 18.1 Lo que está bien resuelto

- Composición de dependencias clara.
- Repository pattern simple y testeable.
- DTOs separados de dominio.
- Auth session encapsulada en un solo coordinador.
- Soporte demo/live en runtime.
- Persistencia mínima pero suficiente.
- UI tests y unit tests cubriendo casos importantes.
- `Observation` moderna en lugar de patrones más antiguos.

### 18.2 Tradeoffs / limitaciones actuales

- El flujo OAuth actual no usa PKCE.
- La API de catálogo a veces no trae precio y la app cae a `0`.
- El default de moneda cae a `ARS` aunque el payload no lo confirme.
- No hay cache persistente de detalle ni de búsqueda.
- Los favoritos solo guardan `ProductSummary`.
- No hay paginación.
- No hay manejo avanzado de expiración de cache ni invalidación de búsquedas previas fuera del `searchGeneration`.
- No hay capa de analytics, metrics ni tracing.

### 18.3 Si te preguntan “¿cómo la mejorarías?”

Puedes responder algo así:

1. Migraría OAuth a un flujo más robusto con PKCE si el proveedor lo soporta.
2. Agregaría una estrategia explícita para productos sin precio, en vez de mostrar `0`.
3. Haría persistencia local de resultados/favoritos con una store más estructurada si la app creciera.
4. Agregaría paginación y caché por query.
5. Extraería strings a localización.
6. Mejoraría separación entre UI copy y lógica de negocio.
7. Agregaría observabilidad más fuerte para networking y auth.

## 19. Cómo explicar la app en 90 segundos

Versión corta para entrevista:

`MELISearch` es una app SwiftUI multiplataforma que busca productos de Mercado Libre, permite ver detalle y guardar favoritos. La arquitectura está separada en `App`, `Core`, `Domain`, `Data` y `Features`. La UI habla con un `ProductRepository`; en modo demo usa fixtures en memoria y en modo live usa un `MELIAPIClient` autenticado. Toda la autenticación está encapsulada en `MELIAuthenticationSession`, que resuelve configuración desde el entorno, soporta OAuth Authorization Code, refresh token, Keychain y validación de sesión con `/users/me`. La navegación raíz usa `TabView` con `Search` y `Favorites`, ambos con su propio `NavigationStack`. Los favoritos viven en `UserDefaults`, la sesión OAuth en `Keychain`, y la app está bien cubierta con unit tests y UI tests.`

## 20. Conclusión

La app está bien estructurada para un challenge o una base de producto pequeña:

- composición limpia
- responsabilidades claras
- capa de auth razonablemente robusta
- buena testabilidad
- UI moderna con SwiftUI y Observation

Lo más importante para entenderla es pensarla en cuatro ejes:

1. Configuración runtime: demo vs live.
2. Sesión OAuth: token de entorno, sesión persistida o autorización interactiva.
3. Datos: DTOs de Mercado Libre mapeados a dominio.
4. Navegación: búsqueda, detalle y favoritos sobre `ProductSummary`.

Si entiendes esos cuatro ejes, entiendes prácticamente toda la app.
