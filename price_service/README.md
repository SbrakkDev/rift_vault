# Rift Vault Price Service

Servizio di sync giornaliero per catalogo e prezzi carte Riftbound.

Questa parte del progetto evita di fare richieste live da iPhone verso JustTCG. Invece:

1. scarica il catalogo da RiftCodex
2. scarica i prezzi da JustTCG
3. converte USD -> EUR
4. genera una API statica in JSON
5. la pubblica ogni giorno con GitHub Actions

## Perche questa architettura

Per un job giornaliero completo e gratuito, una snapshot statica e piu affidabile di un cron serverless che deve rispettare limiti molto stretti su piani free.

## Prerequisiti

- Node 20+
- chiave `JUSTTCG_API_KEY`

## Esecuzione locale

```bash
cd price_service
export JUSTTCG_API_KEY="tcg_..."
npm run sync
npm run serve
```

Poi apri:

- `http://localhost:8787`
- `http://localhost:8787/api/meta.json`
- `http://localhost:8787/api/catalog.json`
- `http://localhost:8787/api/prices.json`

## Output generato

- `public/api/meta.json`
- `public/api/catalog.json`
- `public/api/prices.json`
- `public/api/cards/<card-id>.json`
- `public/api/sets/<set-slug>.json`

## Variabili ambiente

- `JUSTTCG_API_KEY`: obbligatoria
- `RIFTCODEX_API_BASE_URL`: default `https://api.riftcodex.com`
- `JUSTTCG_API_BASE_URL`: default `https://api.justtcg.com/v1`
- `FRANKFURTER_API_BASE_URL`: default `https://api.frankfurter.dev/v1`
- `PORT`: porta del server locale statico, default `8787`

## GitHub Actions

Il workflow giornaliero e in:

- `.github/workflows/daily-price-sync.yml`

Secrets richiesti:

- `JUSTTCG_API_KEY`

Una volta abilitato GitHub Pages, la cartella `price_service/public` viene pubblicata automaticamente ad ogni sync.
