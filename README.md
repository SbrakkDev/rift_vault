# RuneShelf

Companion iPhone per giocatori di Riftbound costruito in SwiftUI.

## Struttura progetto

- `app/`
  - progetto iOS `RuneShelf`
- `web/`
  - webapp `RuneShelf` in `React + TypeScript + Vite`
- `supabase/`
  - schema e setup cloud
- `price_service/`
  - sync prezzi e output pubblico
- `scripts/`
  - utility locali

## Include

- Binder con registrazione copie possedute e wishlist.
- Deck builder con validazione di base: 40 main, 12 rune, 3 battlefields, sideboard 0 oppure 8.
- Companion per tenere il punteggio e salvare il risultato della partita.
- Statistics con cronologia, record e winrate per deck.
- Market con refresh prezzi e watchlist.

## Setup API

Compila il progetto anche senza chiavi. Per il catalogo carte e le immagini usa di default RiftCodex:

- `RiftCodexAPIBaseURL`: di default `https://api.riftcodex.com`.

Per i prezzi live invece l'app puo leggere uno snapshot pubblico separato:

- `RuneShelfPriceServiceBaseURL`: base URL del Price Service pubblico, ad esempio la root GitHub Pages del progetto.

## Note integrazione

- Le immagini e le informazioni carta arrivano da RiftCodex tramite `GET /cards`, senza richiedere auth.
- Il market non usa piu API key lato app: legge prezzi gia sincronizzati dal Price Service pubblico.

## Price Service

Dentro [price_service](/Users/davidebusa/Documents/local/rift_vault/price_service) trovi il backend/sync giornaliero per i prezzi:

- scarica catalogo da RiftCodex
- scarica prezzi da CardTrader
- genera una API statica JSON pronta per l'app
- puo essere pubblicata gratis con GitHub Actions + GitHub Pages

## Cloud Sync

Per login e salvataggio cloud di:

- binder personale
- deck creati
- match e statistiche

la base consigliata e Supabase. Ho gia preparato uno starter in [supabase](/Users/davidebusa/Documents/local/rift_vault/supabase):

- [schema.sql](/Users/davidebusa/Documents/local/rift_vault/supabase/schema.sql)
- [README.md](/Users/davidebusa/Documents/local/rift_vault/supabase/README.md)

Questa scelta resta economica anche per il futuro Android, perche il backend e unico e non dipende da servizi solo Apple.

## Progetto iOS

Apri il progetto da:

- [RuneShelf.xcodeproj](/Users/davidebusa/Documents/local/rift_vault/app/RuneShelf.xcodeproj)

## Progetto Web

La webapp si trova in:

- [web](/Users/davidebusa/Documents/local/rift_vault/web)

Per avviarla:

```bash
cd /Users/davidebusa/Documents/local/rift_vault/web
npm install
npm run dev
```

## Privacy Policy su GitHub Pages

La strada piu semplice per pubblicare la privacy policy per App Store Connect e usare:

- branch: `main`
- cartella: `docs`

File pronti:

- [docs/index.html](/Users/davidebusa/Documents/local/rift_vault/docs/index.html)
- [docs/privacy-policy.html](/Users/davidebusa/Documents/local/rift_vault/docs/privacy-policy.html)

Configurazione GitHub:

1. vai nel repository su GitHub
2. apri `Settings`
3. apri `Pages`
4. in `Build and deployment` scegli `Deploy from a branch`
5. seleziona:
   - branch: `main`
   - folder: `/docs`

L'URL finale sara del tipo:

- `https://TUO-USERNAME.github.io/NOME-REPO/privacy-policy.html`
