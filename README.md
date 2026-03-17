# Rift Vault

Companion iPhone per giocatori di Riftbound costruito in SwiftUI.

## Include

- Binder con registrazione copie possedute e wishlist.
- Deck builder con validazione di base: 40 main, 12 rune, 3 battlefields, sideboard 0 oppure 8.
- Companion per tenere il punteggio e salvare il risultato della partita.
- Statistics con cronologia, record e winrate per deck.
- Market con refresh prezzi e watchlist.

## Setup API

Compila il progetto anche senza chiavi. Per il catalogo carte e le immagini usa di default RiftCodex:

- `RiftCodexAPIBaseURL`: di default `https://api.riftcodex.com`.

Per i prezzi live invece puoi ancora configurare un provider separato:

- `RiftboundMarketAPIBaseURL`: base URL del provider prezzi.
- `RiftboundMarketAPIKey`: chiave del provider prezzi.
- `RiftboundMarketAPIHost`: eventuale header host RapidAPI.

## Note integrazione

- Le immagini e le informazioni carta arrivano da RiftCodex tramite `GET /cards`, senza richiedere auth.
- Il provider market è volutamente configurabile: la UI usa quote demo finché non inserisci un endpoint live compatibile.

## Price Service

Dentro [price_service](/Users/davidebusa/Documents/local/rift_vault/price_service) trovi il backend/sync giornaliero per i prezzi:

- scarica catalogo da RiftCodex
- scarica prezzi da JustTCG
- converte i valori in EUR
- genera una API statica JSON pronta per l'app
- puo essere pubblicata gratis con GitHub Actions + GitHub Pages
