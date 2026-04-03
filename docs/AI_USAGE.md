# AI Usage

## Agent

- Agent: Codex desktop coding agent
- Model family used by the agent: GPT-5 class coding model

## Prompt used for this implementation

The implementation was guided by the following intent:

> Implement the Mercado Libre mobile challenge described in the PDF inside the existing iOS project, keep the code in English, document the architecture, use MVVM, and follow modern iOS patterns with strong error handling and tests.

## Skills consulted

The implementation decisions were guided by the iOS-relevant skills available in the environment:

- `swiftui-expert-skill`: view composition, state ownership and accessibility.
- `swiftui-ui-patterns`: screen composition and modern SwiftUI flow structure.
- `swiftui-view-refactor`: ordering and dependency injection conventions for SwiftUI views.
- `swift-concurrency`: async/await, actor boundaries and request flow.
- `swift-concurrency-expert`: minimal and safe concurrency choices for a MainActor-default project.
- `swift-testing-expert`: Swift Testing structure and migration-friendly test style.
- `swiftui-performance-audit`: stable identities, lightweight view trees and avoiding expensive view work.
- `core-data-expert`: used as a decision aid to avoid unnecessary persistence complexity for this challenge.

## Practical outcome

- Chose MVVM by feature because the request explicitly asked for it and the challenge centers on screen state transitions.
- Used a repository boundary so live API behavior and demo fixtures can coexist without infecting the UI layer.
- Defaulted to demo mode because current Mercado Libre endpoints no longer behave as the PDF describes without authorization.
- Added Swift Testing unit tests plus one UI smoke test to keep the project reviewable.
