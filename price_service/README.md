# RuneShelf Price Service

Servizio di sync giornaliero per catalogo e prezzi carte Riftbound.

Questa parte del progetto evita di fare richieste live da iPhone verso provider esterni. Invece:

1. scarica il catalogo da RiftCodex
2. scarica i prezzi da CardTrader
3. genera una API statica in JSON
4. la pubblica ogni giorno con GitHub Actions

## Perche questa architettura

Per un job giornaliero completo e gratuito, una snapshot statica e piu affidabile di un cron serverless che deve rispettare limiti molto stretti su piani free.

## Prerequisiti

- Node 20+
- token `CARDTRADER_BEARER_TOKEN`

## Esecuzione locale

```bash
cd price_service
export CARDTRADER_BEARER_TOKEN="ct_..."
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

Lo snapshot salva:

- `price`
  - compatibilita con l'app attuale
  - corrisponde al minimo assoluto trovato in inglese
- `languagePrices.english`
  - minimo assoluto inglese
- `languagePrices.chinese`
  - minimo assoluto cinese

In `prices.json` resta presente anche `prices`, mentre i prezzi separati per lingua sono esposti in `languagePrices`.

## Variabili ambiente

- `CARDTRADER_BEARER_TOKEN`: obbligatoria
- `RIFTCODEX_API_BASE_URL`: default `https://api.riftcodex.com`
- `CARDTRADER_API_BASE_URL`: default `https://api.cardtrader.com/api/v2`
- `PORT`: porta del server locale statico, default `8787`

## GitHub Actions

Il workflow giornaliero e in:

- `.github/workflows/daily-price-sync.yml`

Secrets richiesti:

- `CARDTRADER_BEARER_TOKEN`

Una volta abilitato GitHub Pages, la cartella `price_service/public` viene pubblicata automaticamente ad ogni sync.
