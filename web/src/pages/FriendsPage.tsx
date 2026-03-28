import { communityProfiles } from "../data/mock";

export function FriendsPage() {
  return (
    <section className="page">
      <div className="friends-layout">
        <section className="panel">
          <h2>Amici</h2>
          <div className="friend-list">
            {communityProfiles.map((profile) => (
              <div key={profile.username} className="friend-row">
                <div>
                  <strong>{profile.username}</strong>
                  <p>{profile.decks.length} deck pubblici</p>
                </div>
                <button className="ghost-button">Apri profilo</button>
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <h2>Sostieni RuneShelf</h2>
          <p>
            RuneShelf e&apos; gratuita, ma mantenerla online ha un costo reale tra sviluppo,
            backend e aggiornamenti. Se vuoi supportare il progetto, il tuo aiuto su Patreon
            fa davvero la differenza.
          </p>
          <a className="patreon-button" href="https://www.patreon.com/c/runeshelf" target="_blank" rel="noreferrer">
            Vai su Patreon
          </a>
        </section>
      </div>
    </section>
  );
}
