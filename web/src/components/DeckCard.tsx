import { DomainIcon, domainGradient } from "./DomainIcon";
import type { DeckPreview } from "../types";

type DeckCardProps = {
  deck: DeckPreview;
  showCommunityMeta?: boolean;
};

export function DeckCard({ deck, showCommunityMeta = false }: DeckCardProps) {
  const [start, end] = domainGradient(deck.domains);

  return (
    <article
      className="deck-card"
      style={{
        background: `linear-gradient(120deg, ${start} 0%, ${end} 100%)`
      }}
    >
      <img className="deck-card__image" src={deck.legendImage} alt={deck.name} />

      <div className="deck-card__content">
        <div className="deck-card__title-block">
          <h3>{deck.name}</h3>
          {showCommunityMeta ? <p className="deck-owner">{deck.owner}</p> : null}
        </div>

        <div className="deck-card__info-row">
          <div className="domains-pill">
            {deck.domains.map((domain) => (
              <DomainIcon key={domain} domain={domain} size={34} />
            ))}
          </div>

          <div className="set-chip-row">
            {deck.setCodes.map((setCode) => (
              <span key={setCode} className="set-chip">
                {setCode}
              </span>
            ))}
          </div>
        </div>

        <div className="deck-card__footer">
          <div className="price-pill">
            <span className="price-pill__icon">€</span>
            <span>{deck.priceLabel}</span>
          </div>

          {showCommunityMeta ? (
            <div className="community-meta-pill">
              <span>👁 {deck.views}</span>
              <span>♥ {deck.likes}</span>
            </div>
          ) : (
            <span className={deck.isPublic ? "visibility-pill public" : "visibility-pill private"}>
              {deck.isPublic ? "Pub" : "Pvt"}
            </span>
          )}
        </div>
      </div>
    </article>
  );
}
