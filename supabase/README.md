# Supabase Setup

Questa cartella contiene la base backend consigliata per `RuneShelf`.

## Perche questa scelta

- backend unico per iOS e Android
- login + database nello stesso servizio
- free tier adatto per partire con binder, deck e match
- costo contenuto quando si cresce

## Cosa salviamo

- `profiles`: profilo utente
- `user_collection_entries`: carte possedute e wishlist
- `user_decks`: metadati del mazzo
- `user_deck_entries`: carte dentro ogni mazzo
- `user_matches`: partite e statistiche

## Cosa NON salviamo nel DB

- immagini ufficiali delle carte
- catalogo statico RiftCodex
- prezzi live del market

Questi restano esterni, quindi il database utente resta leggero.

## Setup rapido

1. Crea un progetto Supabase.
2. Apri `SQL Editor`.
3. Incolla ed esegui [schema.sql](/Users/davidebusa/Documents/local/rift_vault/supabase/schema.sql).
4. In `Authentication` abilita:
   - Email / Magic Link
   - Google
5. Recupera:
   - `Project URL`
   - `anon public key`

## Strategia consigliata

- app continua a salvare anche in locale come cache/offline layer
- Supabase diventa la fonte cloud dell'utente loggato
- sync iniziale:
  - upload stato locale se cloud vuoto
  - merge guidato in seguito

## Stima spazio

Per questo progetto il peso vero non e nei dati utente, ma negli asset.

Anche con:
- centinaia di entry collezione
- decine o centinaia di deck
- molte partite registrate

il DB resta normalmente molto sotto il free tier da `500 MB`, perche stiamo salvando quasi solo testo, ID e numeri.
