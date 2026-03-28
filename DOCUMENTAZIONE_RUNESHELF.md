# Documentazione RuneShelf

Questa guida descrive:

1. le funzioni principali dell'app e dove sono implementate nel codice
2. tutti i passaggi esterni necessari per far funzionare il progetto (`Supabase`, `Brevo`, `GitHub Actions`, `GitHub Pages`, `CardTrader`, `RiftCodex`)
3. la struttura del progetto iOS e della nuova webapp

Il progetto iOS e' in:

- `app/RuneShelf/`
- `app/RuneShelf.xcodeproj`

La webapp e' in:

- `web/`

## 0.1 Web app

La webapp e' stata inizializzata con:

- `React`
- `TypeScript`
- `Vite`

Percorsi principali:

- `web/src/App.tsx`
  - routing principale
- `web/src/components/`
  - shell, card deck, card binder, header
- `web/src/pages/`
  - `CommunityPage`
  - `BinderPage`
  - `DeckPage`
  - `CompanionPage`
  - `FriendsPage`
- `web/src/data/mock.ts`
  - dati mock iniziali per sviluppo UI
- `web/public/illustrations/`
  - illustrazioni binder
- `web/public/domains/`
  - icone dominio

### Avvio locale web

```bash
cd /Users/davidebusa/Documents/local/rift_vault/web
npm install
npm run dev
```

### Deploy web consigliato

La soluzione piu semplice consigliata e':

- `Vercel`

Configurazione:

- Root Directory: `web`
- Build Command: `npm run build`
- Output Directory: `dist`

Documentazione ufficiale:

- `https://vercel.com/docs/frameworks/vite`

### Privacy Policy pubblica

Per App Store Connect e' stato aggiunto un file statico pronto per essere pubblicato:

- `web/public/privacy-policy.html`

Per la pubblicazione piu semplice via GitHub Pages e' stata aggiunta anche una versione dedicata in:

- `docs/privacy-policy.html`
- `docs/support.html`
- `docs/index.html`

Configurazione consigliata GitHub Pages:

1. repository GitHub -> `Settings`
2. `Pages`
3. `Deploy from a branch`
4. branch: `main`
5. folder: `/docs`

In questo modo l'URL da usare in App Store Connect sara':

- `https://TUO-USERNAME.github.io/NOME-REPO/privacy-policy.html`
- `https://TUO-USERNAME.github.io/NOME-REPO/support.html`

La copia in `web/public/privacy-policy.html` puo' restare come sorgente webapp, ma la strada piu veloce per l'App Store e' usare `docs/privacy-policy.html`.

## 1. Panoramica architettura

### 1.1 Struttura generale

I punti centrali del progetto sono:

- `RuneShelf/ContentView.swift`
  - decide cosa mostrare all'avvio: loader, login, completamento profilo o app principale
- `RuneShelf/Services/BinderListViewModel.swift`
  - contiene `RuneShelfStore`
  - e' lo store principale dell'app
  - gestisce stato locale, sync cloud, deck, binder, match, community, amici, auth
- `RuneShelf/Models/Binder.swift`
  - contiene i modelli dati principali: `RiftCard`, `Deck`, `DeckEntry`, `MatchRecord`, `CollectionEntry`, `DeckReference`
- `RuneShelf/Views/`
  - contiene tutte le schermate SwiftUI
- `RuneShelf/Services/`
  - contiene i servizi API e i servizi cloud

### 1.2 Persistenza locale

Il salvataggio locale e' implementato in:

- `RuneShelf/Services/BinderListViewModel.swift`
  - `actor VaultPersistence`
  - `func load()`
  - `func save(snapshot:)`
  - `private func persistSoon()`

Il file locale viene scritto in:

- `Application Support/RuneShelf/vault_state.json`

Questo snapshot salva:

- catalogo
- collezione personale
- deck
- match
- quote prezzi
- stato companion

### Nota prestazioni persistena locale

Per rendere l'app piu reattiva ai tap rapidi (soprattutto nel `Companion`), il salvataggio locale non parte piu immediatamente ad ogni singolo click:

- `persistSoon()` usa un piccolo debounce
- gli update UI avvengono subito
- il salvataggio su disco parte poco dopo, in background

Questo evita il lag visibile quando l'utente incrementa punteggi, round o altri contatori in rapida sequenza.

### 1.3 Configurazione app

Le chiavi di configurazione runtime sono in:

- `RuneShelf/Info.plist`

Chiavi usate:

- `RiftCodexAPIBaseURL`
- `RuneShelfPriceServiceBaseURL`
- `SupabaseProjectURL`
- `SupabaseAnonKey`

La lettura di queste chiavi e' in:

- `RuneShelf/Services/BinderListViewModel.swift`
  - `struct AppConfiguration`

### 1.4 Icona app

L'icona dell'app e' nel catalogo asset iOS:

- `RuneShelf/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

L'ultima versione usa il file sorgente locale:

- `/Users/davidebusa/Documents/local/ill/appicon.png`

e il fondo bianco e' stato rimosso in fase di preparazione dell'asset finale.

## 2. Funzioni dell'app e codice relativo

## 2.1 Avvio app, sessione e navigazione

### Cosa fa

- mostra un loader iniziale
- ripristina la sessione locale
- se l'utente non e' autenticato mostra il login
- se l'utente non ha completato il profilo mostra la schermata username
- altrimenti apre le tab principali

### Dove nel codice

- `RuneShelf/ContentView.swift`
  - `struct ContentView`
  - `struct MainTabView`
  - `struct AuthLoadingView`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func bootstrapIfNeeded() async`
  - `func hydrateCachedAuthIfPossible() async`
  - `func restoreAuthIfPossible() async`

### Tab attuali

In `MainTabView` ci sono:

- `Community`
- `Binder`
- `Deck`
- `Companion`
- `Friends`

## 2.2 Login via email OTP

### Cosa fa

- invia un codice via email
- verifica il codice OTP
- supporta sia utente esistente sia nuova registrazione
- salva la sessione locale e la ripristina alle aperture successive

### Dove nel codice

- `RuneShelf/Views/AuthenticationView.swift`
  - UI del login
  - pulsanti `Invia codice` e `Verifica codice`

- `RuneShelf/Services/SupabaseAuthService.swift`
  - `func requestEmailOTP(email:configuration:)`
  - `func verifyEmailOTP(email:code:configuration:)`
  - fallback automatico tra verify type `email` e `signup`
  - `func refresh(session:configuration:)`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func sendAuthCode(to:) async`
  - `func verifyAuthCode(_:) async`
  - `func signOut() async`

### Persistenza sessione

- `RuneShelf/Services/SupabaseAuthService.swift`
  - `actor SupabaseSessionStore`
  - `actor SupabaseProfileStore`

Chiavi locali:

- `runeshelf.supabase.session`
- `runeshelf.supabase.profile`

## 2.3 Completamento profilo

### Cosa fa

- al primo accesso chiede uno `username`
- salva opzionalmente anche un `display name`
- lo username e' usato per community, amici e deck pubblici

### Dove nel codice

- `RuneShelf/Views/ProfileCompletionView.swift`
  - form UI per `username` e `displayName`

- `RuneShelf/Services/SupabaseAuthService.swift`
  - `func upsertProfile(...)`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func saveProfile(username:displayName:) async`

## 2.4 Binder

### Cosa fa

- mostra i binder dei set ufficiali
- mostra anche il binder speciale `Preferiti`
- permette anche di creare binder/liste personalizzate di carte
- consente vista binder 3x3 e vista lista
- consente ricerca, wishlist e copie possedute
- consente filtri per:
  - tipo di carta
  - parola chiave della carta
  - set della carta
  - domini della carta con simboli
- prepara una cache locale dei filtri all'apertura del binder per rendere la schermata piu reattiva
- mantiene anche in memoria la lista filtrata e le pagine 3x3 del binder, cosi non vengono ricostruite a ogni render della schermata
- zoom della carta con prezzo
- nella schermata carta ingrandita mostra anche:
  - costo
  - nome
  - effetto
  - colore
  - nel costo mostra `energy` e anche `power` se il dato e' presente

### Dove nel codice

- `RuneShelf/Views/BinderDetailView.swift`
  - `struct BinderFeatureView`
  - `private struct BinderSetDetailView`
  - `private struct BinderCardFocusView`
  - `private struct CardCustomListsMenuButton`
  - `private struct BinderListFiltersSheet`
  - `private struct BinderDomainFilterGrid`
  - `private struct BinderDomainSymbol`

- `RuneShelf/Views/BinderView.swift`
  - componenti visuali condivisi
  - `struct BinderAlbumCard`
  - `struct BinderOpenSpread`
- `RuneShelf/Views/CardEffectRichTextView.swift`
  - renderer inline dei token effetto con badge energia/dominio compatti
  - `struct CardArtView`
  - `struct MarketPricePill`
  - le card binder usano le illustrazioni asset come sfondo decorativo a destra con sfumatura da destra verso sinistra
  - il gradiente della card binder riprende il mood cromatico dell'illustrazione del relativo set
  - `CardArtView` gestisce le `Battlefield` come carte landscape e le ruota correttamente nei contenitori verticali
  - per le `Battlefield` vengono rimossi fondo e bordo standard del contenitore verticale, cosi non compare il rettangolo dietro all'artwork
  - la card binder mostra solo:
    - nome binder
    - badge set sotto il nome
    - numero carte
    - badge set (`OGN`, `PG`, `SFD`, `UNL`, `FAV`)

Asset grafici aggiunti nel catalogo:

- `FavoriteIllustration`
- `OriginsIllustration`
- `ProvingGroundsIllustration`
- `SpiritForgedIllustration`
- `UnleashedIllustration`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `var setProgress: [SetProgress]`
  - `func binderDisplayName(for:) -> String`
  - `func visibleBinderSetName(for:) -> String?`
  - `func cards(for setName:) -> [RiftCard]`
  - `func setOwnedCopies(_:for:)`
  - `func toggleWanted(_:)`
  - `func createCustomCardList(named:initialCardID:) -> Bool`
  - `func toggleCard(_:inCustomListID:)`
  - `func containsCard(_:inCustomListID:) -> Bool`
  - `func customListsContaining(_:) -> [CustomCardList]`
  - `private func favoriteCards() -> [RiftCard]`
  - `private func rebuildCustomListCaches()`
  - usa cache in memoria per:
    - `card` per id
    - `deck` per id
    - `match history` per `deckID`
    - carte binder gia ordinate per `setName`
    - `Preferiti` gia ordinati
    - carte delle liste personalizzate gia ordinate per nome lista
  - queste cache sono locali, leggere e ricostruite solo quando cambiano `catalog`, `collection`, `decks` o `matches`
  - il binder usa anche cache di view per:
    - `filteredVisibleCards`
    - `binderPages`

### Binder speciali

Il binder `Preferiti` e' generato in:

- `RuneShelf/Services/BinderListViewModel.swift`
  - `setProgress`
  - `cards(for setName:)`

Le liste personalizzate:

- vengono salvate nello snapshot locale come `customLists`
- compaiono nella libreria binder subito dopo `Preferiti`
- possono essere create dal menu carta nel binder/lista/focus
- dalla pagina `Binder Library` possono anche essere modificate o eliminate
- la modifica consente di cambiare:
  - nome lista
  - colore di sfondo del binder mostrato in libreria e nella pagina binder
- possono contenere qualsiasi carta senza influire su `Preferiti`

### Set binder visibili

La libreria binder e i filtri set mostrano solo i 4 set principali:

- `Origins`
- `Proving Grounds`
- `SpiritForged`
- `Unleashed`

I set promo come `Judge Promotional`, `Organized Play Promo` e `Promotional Cards` restano nel catalogo dati ma non vengono esposti come binder separati e non compaiono nei filtri set.

### Sync cloud preferiti

I preferiti pubblici mostrati nella pagina profilo utente dipendono dalla sincronizzazione della collection verso Supabase:

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func toggleWanted(_:)`
  - `func setOwnedCopies(_:for:)`
  - `private func scheduleCollectionSync()`
  - `private func syncCollectionToCloudIfPossible()`
- `RuneShelf/Services/SupabaseCollectionService.swift`
  - `func replaceCollection(_:session:configuration:)`

La sincronizzazione scrive su:

- `public.user_collection_entries`

e permette alla pagina profilo pubblico di leggere le carte con `wanted = true`.

## 2.5 Deck Builder

### Cosa fa

- parte senza deck predefiniti su una nuova installazione
- rimuove automaticamente eventuali deck demo legacy come `Foxfire Tempo`, anche se arrivano da snapshot vecchi o dal cloud
- crea deck locali dell'utente
- apre i deck in modifica usando una bozza locale
- salva le modifiche solo quando l'utente preme `Salva modifiche`
- consente di creare versioni del mazzo tramite `Salva snapshot`
- consente scelta:
  - legenda
  - campione designato
  - carte del main
  - rune
  - battlefield
  - sideboard
- supporta filtri, ricerca, zoom carta
- nella schermata di preview carta del deck builder mostra anche:
  - costo
  - nome
  - effetto
  - colore
- valida le regole del mazzo
- ogni deck puo essere:
  - `privato`
  - `pubblico`
- se pubblico, la `cronologia partite` puo essere:
  - `privata`
  - `pubblica`
- la card anteprima del deck mostra:
  - carta legenda a sinistra
  - carta piu grande e piu vicina ai bordi sinistro/superiore della card
  - nome mazzo grande su blocco separato nella parte alta destra
  - subito sotto il titolo: simboli dei domini e chip dei set da cui provengono le carte del mazzo
  - i simboli dominio usano direttamente gli asset `Fury`, `Calm`, `Order`, `Chaos`, `Mind`, `Body`
  - i chip set mostrano abbreviazioni come `OGN`, `OGS`, `SFD`
  - nella fascia bassa: prezzo totale del mazzo a sinistra e badge `PUB` / `PVT` a destra
  - il prezzo del mazzo e la somma delle quote live delle carte contenute nel deck
  - layout interno aderente al template allegato: carta a sinistra, titolo sopra, riga domini+set al centro, riga prezzo+visibilita in basso
  - il layout della preview deck e stato irrigidito per avvicinarsi al mock: carta flush a sinistra/sopra/sotto, nessun padding globale attorno alla legenda, larghezza a tutta la viewport utile della pagina deck
  - l'altezza della card e fissata all'altezza della legenda; gli elementi interni non possono piu espandere il contenitore padre
  - nella lista deck e stato reintrodotto uno spacing verticale leggero tra una card e l'altra
  - le icone dominio nella preview deck usano di nuovo un cerchio colorato del dominio con simbolo bianco
  - le due icone dominio sono racchiuse in un box condiviso grigio scuro trasparente, coerente con gli altri badge della card
  - i cerchi delle icone dominio hanno anche un sottile bordo bianco
  - i chip dei set usano testo bianco e non hanno bordo
  - il badge `Pub` e piu evidenziato visivamente rispetto a `Pvt`
  - il blocco del nome del mazzo ha altezza fissa, quindi se il testo va a capo non sposta piu in basso gli altri elementi della card
  - il blocco titolo ha altezza fissa, quindi il layout non cambia se il nome va a capo o no; in caso di nome lungo si riduce il font
  - la palette dello sfondo enfatizza meglio la differenza tra `Body`, `Fury` e `Chaos`
  - sfondo colorato in base ai domini della legenda

### Community deck card

- nella pagina `Community` la card deck usa lo stesso template visivo della libreria deck
- mantiene la stessa struttura della preview deck: carta legenda a sinistra, titolo in alto, riga `domini + set` al centro e riga bassa con prezzo a sinistra
- la differenza e che il nome del creatore appare subito sotto il nome del deck
- al posto del badge `pub.` / `pvt.` la riga bassa a destra mostra solo `visualizzazioni` e `like`
- il box `views + like` usa lo stesso linguaggio visivo del deck builder, ma contiene le metriche community invece della visibilita'
- usa lo stesso sfondo colorato in base ai domini della legenda
- titolo deck, box domini, chip set e box autore/engagement mantengono la stessa densita' visiva della preview nella pagina `Deck Builder`

### Regole attuali del deck

Le regole sono modellate nel codice e nella UI del deck builder:

- 1 legenda
- 1 campione designato
- 39 carte main
- 12 rune
- 3 battlefield

Note importanti:

- le `12 rune` sono totali, non `6 + 6`
- una singola carta `Rune` puo arrivare fino a `12` copie
- `Battlefield` viene mostrato prima di `Rune` nelle sezioni del mazzo
- le sezioni del mazzo mostrano il totale, ad esempio `Unita - 15`
- se si esce dall'editor senza premere `Salva modifiche`, la bozza viene persa
- lato `Supabase`, il vincolo della tabella `user_deck_entries` deve essere allineato a queste regole
- la lista carte del deck builder supporta filtri per:
  - tipo di carta
  - parola chiave della carta
  - set della carta
  - domini della carta con simboli

### Dove nel codice

- `RuneShelf/Views/BinderSpineView.swift`
  - `struct DeckBuilderView`
  - `private struct DeckDetailView`
  - `private struct DeckEditorView`
  - `private struct DeckFiltersSheet`
  - `private struct DeckDomainFilterGrid`
  - `private struct DeckLibraryCard`
  - `private struct DeckPreviewDomainsRow`
  - `private struct DeckDomainIcon`
  - `private struct DeckPreviewTheme`
  - `private struct DeckBuilderCardFocusView`
  - `private struct DeckMatchHistoryView`
  - `private struct DeckMatchHistoryRow`
  - `private struct DeckVersionDiffView`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func bootstrapIfNeeded() async`
  - `private func mergeOwnDecksFromCloudIfPossible(force:) async`
  - `private func removeLegacySampleDataIfNeeded() -> Bool`
  - `func makeBlankDeckDraft() -> Deck`
  - `func saveDeckDraft(_:replacing:) -> UUID`
  - `func renameDeck(_:to:)`
  - `func deleteDeck(_:)`
  - `func setDeckVisibility(_:for:)`
  - `func setMatchHistoryPublic(_:for:)`
  - `func setLegendCard(_:for:)`
  - `func setChosenChampionCard(_:for:)`
  - `func validateDeck(_:)`
  - `func maxCopiesAllowed(for:) -> Int`
  - `func maxCardsAllowed(in:) -> Int?`
  - `func versionDiffs(for:versionID:) -> [String]`
  - `private func describeVersionChanges(from:to:) -> [String]`
  - ottimizza apertura `Deck detail` e `Deck editor` usando cache locali per lookup di carte, deck e match history
  - `DeckEditorView` mantiene in memoria anche i dati derivati piu costosi:
    - `deckSections`
    - `addableCards`
    - `availableKeywords`
    - `availableDomains`
    - `availableSets`
  - queste cache vengono ricostruite solo quando cambiano i filtri, il draft del mazzo, il catalogo o la collection

- `RuneShelf/Models/Binder.swift`
  - `struct Deck`
  - `struct DeckEntry`
  - `struct DeckVersion`
  - `enum DeckVisibility`

### Versioni del mazzo

Le versioni del mazzo sono salvate dentro il deck stesso, non in una tabella separata.

Implementazione:

- `RuneShelf/Models/Binder.swift`
  - `Deck.versions`
  - `func appendVersion(label:)`
  - `var versionSnapshot`

- `RuneShelf/Services/SupabaseDeckService.swift`
  - salva le versioni serializzandole nel campo `notes` del deck tramite:
    - `decodeDeckNotes(_:)`
    - `encodeDeckNotes(plainText:versions:)`

Questo significa che:

- per la funzione `versioni/snapshot` non serve nessuna nuova tabella Supabase
- i dati vengono memorizzati dentro `user_decks.notes` come JSON

### Migrazione DB richiesta per i limiti deck

Per allineare il database alle regole attuali del deck builder, va eseguita anche questa migration:

- `supabase/deck_entry_count_rules.sql`

Questa SQL aggiorna il vincolo `user_deck_entries_count_check` cosi:

- `battlefield`: esattamente `1` copia per riga
- `rune`: da `1` a `12` copie per riga
- `main` e `sideboard`: da `1` a `3` copie per riga
  - `enum DeckSlot`
  - `enum CardCategory`

## 2.6 Community deck pubblici

### Cosa fa

- mostra i deck pubblici di tutta la community
- ogni deck mostra:
  - immagine legenda
  - nome deck
  - autore
  - domini del mazzo
- si possono filtrare i deck per:
  - legenda
  - domini
- si puo aprire il dettaglio del deck in sola lettura
- si possono mettere like
- si tracciano le visualizzazioni uniche per utente
- il proprietario non puo mettere like al proprio mazzo
- se il deck ha cronologia pubblica, la cronologia viene mostrata in sola lettura

### Dove nel codice

- `RuneShelf/Views/CommunityDecksView.swift`
  - `struct CommunityDecksView`
  - `private struct CommunityDeckFilterBar`
  - `private struct CommunityLegendDropdown`
  - `private struct CommunityDomainsDropdown`
  - `private struct CommunityDeckCard`
  - `private struct CommunityDeckDetailView`
  - `private struct CommunityDeckMatchHistoryRow`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `var publicCommunityDeckFeed`
  - `func refreshCommunityDecksIfNeeded() async`
  - `func toggleLike(for:) async`
  - `func registerViewIfNeeded(for:) async`
  - `func loadPublicMatchHistoryIfNeeded(for:) async`
  - `func publicMatchHistory(for:)`

- `RuneShelf/Services/SupabaseDeckService.swift`
  - `func loadPublicDecks(...)`
  - `func loadDecks(for ownerIDs:...)`
  - `func likeCommunityDeck(...)`
  - `func unlikeCommunityDeck(...)`
  - `func recordCommunityDeckView(...)`

### Regola visualizzazioni

Una view e' unica per coppia:

- `deck_id`
- `user_id`

Questa regola e' gestita nel backend SQL e lato app tramite:

- `recordCommunityDeckView(...)`
- `recordedCommunityDeckViewsThisSession`

## 2.7 Copia deck dalla community

### Cosa fa

- consente di copiare un deck non proprio dalla lista/community
- copia la struttura del deck
- non copia la cronologia partite

### Dove nel codice

La logica lato vista/community e' in:

- `RuneShelf/Views/CommunityDecksView.swift`

La trasformazione del deck remoto in deck locale usa:

- `private extension VaultCommunityDeck`
  - `var asDeck: Deck`

e la logica deck locale dello store in:

- `RuneShelf/Services/BinderListViewModel.swift`

## 2.8 Friends / Amici

### Cosa fa

- cerca utenti per username o display name
- invia richieste di amicizia
- accetta richieste ricevute
- elimina amicizie
- usa i deck degli amici nel companion
- in fondo alla pagina mostra anche un box Patreon con testo di supporto e link diretto alla pagina Patreon del progetto

### Dove nel codice

- `RuneShelf/Views/FriendsView.swift`
  - `struct FriendsView`
  - `private struct FriendSearchRow`
  - `private struct FriendRequestRow`
  - sezione finale `Supporta RuneShelf` con link a `https://www.patreon.com/c/runeshelf`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func searchFriends(query:) async`
  - `func sendFriendRequest(to:) async`
  - `func acceptFriendRequest(_:) async`
  - `func removeFriendship(_:) async`
  - `func refreshFriendsIfNeeded() async`

- `RuneShelf/Services/SupabaseCommunityService.swift`
  - `func searchProfiles(...)`
  - `func loadFriendships(...)`
  - `func sendFriendRequest(...)`
  - `func acceptFriendRequest(...)`
  - `func deleteFriendship(...)`

## 2.9 Companion

### Cosa fa

- divide lo schermo in:
  - player alto
  - match centrale
  - player basso
- tiene punteggio partita
- tiene round BO3
- ha un reset totale partita
- ha reset separati per:
  - punti match
  - timer
- consente pareggio
- il timer condiviso puo essere avviato, messo in pausa e ripreso
- il timer nel Companion parte da `00:00`
- quando il timer e attivo, badge tempo e tasto pausa restano affiancati senza uscire dalla larghezza del pannello player
- l'area timer mantiene la stessa dimensione sia in esecuzione sia in pausa/ripresa
- le tre sezioni del Companion (`player alto`, `match`, `player basso`) mantengono una spaziatura verticale fissa
- salva la partita
- consente lancio `d20`
- consente scelta deck per entrambi i player
- usa colori del pannello in base ai domini del deck selezionato

### Dove nel codice

- `RuneShelf/Views/LibraryView.swift`
  - `struct CompanionView`
  - `private struct CompanionPlayerPane`
  - `private struct CompanionDeckPickerSheet`
  - `private struct CompanionDeckPickerRow`
  - `private struct CompanionD20Overlay`
  - `private struct CompanionD20Crystal`
  - `private struct CompanionD20FacetLines`
  - `private struct CompanionDeckTheme`
  - `private struct CompanionDomainPalette`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func setCompanionDeck(_:forLeftPlayer:)`
  - `func saveMatchRecord(opponentName:notes:)`
  - `func adjustScore(left:)`
  - `func adjustScore(right:)`
  - `func adjustRounds(left:)`
  - `func adjustRounds(right:)`
  - `func toggleForcedDraw()`
  - `func resetScoreboard()`
  - `func toggleMatchTimer()`
  - `func resetMatchTimer()`
  - `func resetMatchScores()`

- `RuneShelf/Models/Binder.swift`
  - `struct MatchRecord`
  - `enum MatchOutcome`
  - `struct DeckReference`
  - `struct ScoreboardState`

## 2.10 Cronologia partite

### Cosa fa

- ogni deck mostra:
  - ultima partita
  - pulsante `Mostra tutta la cronologia`
- la cronologia mostra:
  - `VS`
  - leader avversario
  - risultato match (`2-0`, `1-2`, ecc.)
  - proprietario del deck avversario, se disponibile
  - durata
  - data formato `dd/mm/yyyy`

### Dove nel codice

- `RuneShelf/Views/BinderSpineView.swift`
  - `private struct DeckMatchHistoryView`
  - `private struct DeckMatchHistoryRow`

- `RuneShelf/Views/CommunityDecksView.swift`
  - `private struct CommunityDeckMatchHistoryRow`

- `RuneShelf/Services/BinderListViewModel.swift`
  - `func matchHistory(for:)`
  - `func latestMatch(for:)`
  - `func saveMatchRecord(opponentName:notes:)`

- `RuneShelf/Services/SupabaseMatchService.swift`
  - `func loadOwnMatches(...)`
  - `func loadPublicMatchHistory(...)`
  - `func syncOwnMatches(...)`

## 2.11 Prezzi carte

### Cosa fa

- l'app non chiama provider prezzi direttamente
- legge i prezzi da uno snapshot JSON pubblico
- il catalogo carte e le immagini arrivano da `RiftCodex`
- i prezzi arrivano dal `RuneShelf Price Service`

### Dove nel codice

- `RuneShelf/Services/BinderListViewModel.swift`
  - `actor RiftCodexContentService`
  - `actor MarketQuoteService`
  - `func refreshMarketQuotes(forceFallback:) async`
  - `func refreshMarketQuotesIfNeeded() async`

- `RuneShelf/Views/BinderView.swift`
  - `struct MarketPricePill`

- `RuneShelf/Views/BinderDetailView.swift`
  - usa i prezzi nella vista lista e nello zoom carta
  - lo zoom carta e' scrollabile
  - il testo effetto nello zoom carta sostituisce token come `:rb_energy_1:` e `:rb_rune_fury:` con badge e icone inline

## 2.12 Statistiche e performance deck

### Cosa fa

- non esiste piu una tab `Stats`
- le statistiche sono dentro i deck
- il sistema calcola anche performance aggregate dei deck

### Dove nel codice

- `RuneShelf/Services/BinderListViewModel.swift`
  - `var statsSummary`
  - `var deckPerformance`

- `RuneShelf/Views/BinderSpineView.swift`
  - `private struct DeckManaCurveView`
  - `private struct DeckBuilderCardFocusView`
  - `private struct DeckBuilderCardDetailsPanel`

## 2.13 Zoom carta e renderer effetti

### Cosa fa

- la pagina carta ingrandita in `Binder` e `Deck Builder` e' scrollabile
- nei dettagli carta il campo `Effetto` non mostra piu token grezzi tipo `:rb_energy_1:` o `:rb_rune_fury:`
- i token `:rb_energy_1:` mostrano ora un badge bianco con numero nero
- i token `:rb_might:` e `:rb_tap:` vengono sostituiti con le icone dedicate `Might` e `Tap`
- nei dettagli carta il campo `Costo` mostra il costo energia come numero e il `power cost` come icone dominio ripetute
- nei dettagli carta il layout superiore e stato semplificato: costo in alto senza label, nome subito sotto, e per unita/champion il `Might` compare in alto a destra sulla stessa riga del costo con icona a sinistra e valore a destra, colorato con il dominio principale della carta
- sotto il nome compare una riga di capsule: la tipologia carta (`Unit`, `Spell`, `Gear`, ecc.) usa il colore del dominio principale, mentre gli altri tag/tipi (per esempio `Ionia`, `Demacia`, `Fox`, `Cat`) sono mostrati in capsule grigio scuro
- i token energia numerica vengono resi come badge circolari grigio scuro con numero bianco
- i token dominio vengono resi come icone circolari con sfondo del dominio e simbolo bianco

### Dove nel codice

- `RuneShelf/Views/CardEffectRichTextView.swift`
  - `struct CardEffectRichTextView`
- `RuneShelf/Views/BinderDetailView.swift`
  - `private struct BinderCardFocusView`
  - `private struct BinderCardDetailsPanel`
- `RuneShelf/Views/BinderSpineView.swift`
  - `private struct DeckBuilderCardFocusView`
  - `private struct DeckBuilderCardDetailsPanel`

## 3. Setup esterno completo

## 3.1 Dipendenze esterne del progetto

Il progetto usa questi servizi esterni:

- `RiftCodex`
  - catalogo carte, immagini, metadata
- `CardTrader`
  - sorgente prezzi per il backend snapshot
- `GitHub Actions`
  - esecuzione giornaliera del price sync
- `GitHub Pages`
  - pubblicazione snapshot prezzi/catalogo
- `Supabase`
  - login, profili, deck cloud, amici, community, cronologia
- `Brevo`
  - SMTP custom per invio OTP email di Supabase

## 3.2 Setup Supabase passo passo

### 1. Creare il progetto

1. crea un nuovo progetto su Supabase
2. recupera:
   - `Project URL`
   - `anon public key`
3. inseriscili in:
   - `RuneShelf/Info.plist`

Chiavi da compilare:

- `SupabaseProjectURL`
- `SupabaseAnonKey`

### 2. Eseguire SQL base

Apri `SQL Editor` ed esegui nell'ordine:

1. `supabase/schema.sql`
2. `supabase/friends.sql`
3. `supabase/community_decks.sql`
4. `supabase/community_engagement.sql`
5. `supabase/public_match_history.sql`
6. `supabase/deck_entry_count_rules.sql`

### 3. Abilitare login email

In `Authentication`:

1. apri `Sign In / Providers`
2. abilita il provider `Email`

### 4. Configurare i template email OTP

Se vuoi usare il codice OTP nell'app:

devi cambiare **sia**:

- template `Magic Link`
- template `Confirm signup`

e usare il token come testo, non il link.

Template minimo consigliato:

```html
<h2>Codice di accesso RuneShelf</h2>
<p>Inserisci questo codice nell'app:</p>
<p style="font-size:32px;font-weight:700;letter-spacing:6px;">{{ .Token }}</p>
```

Non usare:

- `{{ .ConfirmationURL }}`

se vuoi OTP puro.

### 5. Rate limits

Se usi il provider email integrato di Supabase, i limiti sono molto bassi.

Per questo il progetto usa `Brevo` come SMTP esterno.

## 3.3 Setup Brevo passo passo

### 1. Creare sender verificato

In Brevo:

1. vai in `Senders`
2. crea un sender
3. verifica l'email mittente

### 2. Recuperare parametri SMTP

In Brevo, sezione `SMTP e API`, usa:

- `Server SMTP`: `smtp-relay.brevo.com`
- `Porta`: `587`
- `Accesso`: valore mostrato in `Accesso`
- `Password`: chiave SMTP completa generata da Brevo

Attenzione:

- la password **non** e' la password del tuo account Brevo
- e' la chiave SMTP completa
- se non l'hai copiata al momento della generazione, devi generarne una nuova

### 3. Configurare Supabase con Brevo

In Supabase, sezione Auth/SMTP:

- `Host`: `smtp-relay.brevo.com`
- `Port`: `587`
- `Username`: login SMTP Brevo
- `Password`: chiave SMTP Brevo
- `Sender name`: `RuneShelf`
- `Sender email`: email mittente verificata in Brevo

Una volta fatto, Supabase inviera' gli OTP usando Brevo.

## 3.4 Setup Price Service passo passo

La documentazione breve e' in:

- `price_service/README.md`

### 1. Configurare CardTrader

Ti serve un token:

- `CARDTRADER_BEARER_TOKEN`

### 2. Esecuzione locale

Da terminale:

```bash
cd /Users/davidebusa/Documents/local/rift_vault/price_service
export CARDTRADER_BEARER_TOKEN="ct_..."
npm run sync
npm run serve
```

Endpoint locali:

- `http://localhost:8787`
- `http://localhost:8787/api/meta.json`
- `http://localhost:8787/api/catalog.json`
- `http://localhost:8787/api/prices.json`

### 3. Workflow GitHub Actions

Il workflow e' in:

- `.github/workflows/daily-price-sync.yml`

Fa:

1. checkout repo
2. setup Node 20
3. esegue `node scripts/sync-prices.mjs`
4. pubblica `price_service/public` su GitHub Pages

Secret richiesto:

- `CARDTRADER_BEARER_TOKEN`

### 4. Scheduling giornaliero

Il workflow e' schedulato con:

```yml
schedule:
  - cron: "0 3 * * *"
```

Quindi gira ogni giorno alle `03:00 UTC`.

### 5. Collegamento app -> snapshot pubblico

In `RuneShelf/Info.plist`:

- `RuneShelfPriceServiceBaseURL`

attualmente punta a:

- `https://sbrakkdev.github.io/rift_vault`

L'app usa questo base URL per leggere i JSON statici.

## 3.5 Setup RiftCodex

`RiftCodex` non richiede chiavi lato app nel flusso attuale.

Configurazione:

- `RiftCodexAPIBaseURL`

default:

- `https://api.riftcodex.com`

Il servizio che lo usa e' in:

- `RuneShelf/Services/BinderListViewModel.swift`
  - `actor RiftCodexContentService`

## 4. Sequenza consigliata per rifare il progetto da zero

Se dovessi reinstallare o rifare il setup completo:

1. apri `RuneShelf.xcodeproj`
2. verifica `Info.plist`
3. crea/configura Supabase
4. esegui tutti i file SQL in `supabase/`
5. configura Brevo SMTP dentro Supabase
6. aggiorna i template email OTP (`Magic Link` e `Confirm signup`)
7. configura `CARDTRADER_BEARER_TOKEN` su GitHub
8. abilita GitHub Pages
9. lancia `Daily Price Sync`
10. verifica:
    - `api/meta.json`
    - `api/catalog.json`
    - `api/prices.json`
11. apri l'app
12. fai login
13. completa il profilo con `username`

## 5. File piu importanti da conoscere

### App e stato

- `RuneShelf/ContentView.swift`
- `RuneShelf/Services/BinderListViewModel.swift`
- `RuneShelf/Models/Binder.swift`

### Auth e cloud

- `RuneShelf/Services/SupabaseAuthService.swift`
- `RuneShelf/Services/SupabaseCommunityService.swift`
- `RuneShelf/Services/SupabaseCollectionService.swift`
- `RuneShelf/Services/SupabaseDeckService.swift`
- `RuneShelf/Services/SupabaseMatchService.swift`

### Community autore

- nel dettaglio di un deck community, il nome autore e' cliccabile
- apre una pagina profilo pubblico che mostra:
  - deck pubblici dell'autore
  - binder `Preferiti` dell'autore
- la stessa pagina profilo pubblico e' raggiungibile anche dalla pagina `Friends` toccando il nome di un amico
- codice coinvolto:
  - `RuneShelf/Views/CommunityDecksView.swift`
  - `RuneShelf/Views/FriendsView.swift`
  - `RuneShelf/Services/BinderListViewModel.swift`
  - `RuneShelf/Services/SupabaseCommunityService.swift`
  - `RuneShelf/Services/SupabaseCollectionService.swift`
- lato Supabase serve anche:
  - `supabase/public_favorites.sql`

### Schermate principali

- `RuneShelf/Views/AuthenticationView.swift`
- `RuneShelf/Views/ProfileCompletionView.swift`
- `RuneShelf/Views/BinderDetailView.swift`
- `RuneShelf/Views/BinderSpineView.swift`
- `RuneShelf/Views/CommunityDecksView.swift`
- `RuneShelf/Views/FriendsView.swift`
- `RuneShelf/Views/LibraryView.swift`
- `RuneShelf/Views/BinderView.swift`

### Tipografia

- `RuneShelf/Design/AppFont.swift`
- `RuneShelf/Resources/Fonts/Sora-wght.ttf`
- `RuneShelf/Info.plist` con `UIAppFonts`

Dettagli:

- il font principale dell'app e' `Sora`
- i titoli e i testi principali delle schermate usano i helper tipografici dedicati
- per usarlo nel codice:
  - `Font.rune(size, weight: ...)`
  - `Font.runeStyle(.title3, weight: ...)`
- il font e' registrato tramite il file variabile `Sora-wght.ttf` e viene richiamato con il nome interno `Sora-Regular`

### Backend/supporto esterno

- `supabase/schema.sql`
- `supabase/friends.sql`
- `supabase/community_decks.sql`
- `supabase/community_engagement.sql`
- `supabase/public_match_history.sql`
- `supabase/deck_entry_count_rules.sql`
- `supabase/public_favorites.sql`
- `price_service/scripts/sync-prices.mjs`
- `.github/workflows/daily-price-sync.yml`

## 6. Nota finale

Questo documento e' pensato come mappa pratica del progetto.  
Se in futuro aggiungi nuove feature, il punto piu importante da aggiornare e':

- sezione `2. Funzioni dell'app e codice relativo`
- sezione `3. Setup esterno completo`
