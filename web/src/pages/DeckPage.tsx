import { deckPreviews } from "../data/mock";
import { DeckCard } from "../components/DeckCard";
import { SectionHeader } from "../components/SectionHeader";

export function DeckPage() {
  return (
    <section className="page">
      <SectionHeader
        eyebrow="Deck Builder"
        title="I tuoi deck"
        subtitle="Preview deck con domini, set di provenienza e costo stimato."
        actionLabel="Nuovo deck"
      />

      <div className="stack">
        {deckPreviews.map((deck) => (
          <DeckCard key={deck.id} deck={deck} />
        ))}
      </div>
    </section>
  );
}
