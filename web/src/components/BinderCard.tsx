import type { BinderPreview } from "../types";

type BinderCardProps = {
  binder: BinderPreview;
};

export function BinderCard({ binder }: BinderCardProps) {
  const [start, end] = binder.colors;

  return (
    <article
      className="binder-card"
      style={{ background: `linear-gradient(135deg, ${start} 0%, ${end} 100%)` }}
    >
      <div className="binder-card__content">
        <span className="binder-code">{binder.code}</span>
        <h3>{binder.title}</h3>
        <p>{binder.cardCountLabel}</p>
      </div>

      <div className="binder-card__art-wrap">
        <img src={binder.illustration} alt={binder.title} />
        <div className="binder-card__fade" />
      </div>
    </article>
  );
}
