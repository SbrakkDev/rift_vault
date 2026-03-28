import { binderPreviews } from "../data/mock";
import { BinderCard } from "../components/BinderCard";
import { SectionHeader } from "../components/SectionHeader";

export function BinderPage() {
  return (
    <section className="page">
      <SectionHeader
        eyebrow="Binder"
        title="La tua raccolta"
        subtitle="Set principali, preferiti e progressi in un layout vicino all'app iOS."
      />

      <div className="stack">
        {binderPreviews.map((binder) => (
          <BinderCard key={binder.id} binder={binder} />
        ))}
      </div>
    </section>
  );
}
