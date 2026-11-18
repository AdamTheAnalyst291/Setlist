# The API runs as a separate Azure Functions app, not Static Web Apps' built-in functions

Static Web Apps can host an API of its own ("managed functions") next to the web app, and that would be one resource to deploy instead of two. We run the API as a separate Azure Functions app on the Flex Consumption plan instead.

The reason is the database. The API must reach Azure SQL with a managed identity, so that no database password exists (see the spec, #3). The built-in functions of the Static Web Apps Free plan can't use a managed identity, and the Free plan can't link a separate Functions app either. A separate Functions app has a system-assigned identity, which also reads the Anthropic key from Key Vault.

## Consequences

- The web app calls the API at the Functions app's own hostname, so the API allows the web app's origin with CORS.
- The API's address is not part of the web build. Each deploy writes `config.json` next to the web app, so the same build can be promoted from Dev to UAT to Prod.
- Deploying takes two steps (web app, API) instead of one.
- A request after idle time may be slow while a Flex Consumption instance starts.
