import { deckPreviews } from "../data/mock";
import { DeckCard } from "../components/DeckCard";
import { SectionHeader } from "../components/SectionHeader";

export function CommunityPage() {
  return (
    <section className="page">
      <SectionHeader
        eyebrow="Community"
        title="Deck pubblici della community"
        subtitle="Sfoglia i mazzi condivisi, vedi i domini, il prezzo stimato e l'engagement."
      />

      <div className="filter-row">
        <button className="filter-pill active">Tutti</button>
        <button className="filter-pill">Legends</button>
        <button className="filter-pill">Domini</button>
        <button className="filter-pill">Set</button>
      </div>

      <div className="stack">
        {deckPreviews
          .filter((deck) => deck.isPublic)
          .map((deck) => (
            <DeckCard key={deck.id} deck={deck} showCommunityMeta />
          ))}
      </div>
    </section>
  );
}
