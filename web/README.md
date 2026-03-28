# RuneShelf Web

Webapp di RuneShelf costruita con `React + TypeScript + Vite`.

## Come avviarla in locale

1. Apri il terminale nella cartella:

```bash
cd /Users/davidebusa/Documents/local/rift_vault/web
```

2. Installa le dipendenze:

```bash
npm install
```

3. Avvia il server locale:

```bash
npm run dev
```

4. Apri l'URL mostrato da Vite, di solito:

```text
http://localhost:5173
```

## Come pubblicarla online

La strada piu semplice che ti consiglio e' `Vercel`.

### Opzione consigliata: Vercel

1. Crea un repository Git con dentro questa cartella `web/`.
2. Vai su `https://vercel.com/`.
3. Fai login con GitHub.
4. Importa il repository.
5. Nelle impostazioni del progetto imposta:
   - `Root Directory`: `web`
   - `Build Command`: `npm run build`
   - `Output Directory`: `dist`
6. Premi `Deploy`.

Documentazione ufficiale:

- `https://vercel.com/docs/frameworks/vite`

### Opzione semplice per la sola privacy policy: GitHub Pages

Se ti serve pubblicare velocemente la privacy policy per App Store Connect, puoi
usare anche GitHub Pages senza pubblicare tutta la webapp.

Il file pronto da usare e':

- `web/public/privacy-policy.html`

URL finale atteso dopo il deploy:

- `https://<tuo-account>.github.io/<nome-repo>/privacy-policy.html`

Passaggi rapidi:

1. Pusha il repository su GitHub.
2. Vai nelle impostazioni del repository.
3. Apri `Pages`.
4. Scegli il branch principale e la cartella corretta del sito statico.
5. Pubblica e usa l'URL finale come `Privacy Policy URL` in App Store Connect.

### Alternativa: Netlify

Puoi fare la stessa cosa anche con Netlify:

- `Base directory`: `web`
- `Build command`: `npm run build`
- `Publish directory`: `web/dist`

## Struttura attuale

- `src/`
  - componenti condivisi
  - pagine principali corrispondenti alle tab dell'app iOS
- `public/illustrations/`
  - illustrazioni dei binder
- `public/domains/`
  - simboli dei domini

## Obiettivo della base creata

Questa prima webapp replica la struttura principale di RuneShelf:

- Community
- Binder
- Deck
- Companion
- Friends

Il passo successivo naturale e' collegarla a:

- `Supabase`
- snapshot prezzi pubblici
- dati reali dei deck/community
