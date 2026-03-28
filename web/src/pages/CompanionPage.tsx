export function CompanionPage() {
  return (
    <section className="page">
      <div className="companion-hero">
        <div className="companion-player blue">
          <div className="companion-player__header">
            <span className="player-tag">Player A</span>
            <span className="timer-pill">06:12</span>
          </div>
          <div className="score">0</div>
          <div className="round-track">BO3 • 0-0</div>
        </div>

        <div className="match-panel">
          <h2>Companion</h2>
          <div className="match-actions">
            <button className="ghost-button">Lancia d20</button>
            <button className="ghost-button">Salva match</button>
            <button className="ghost-button">Reset timer</button>
          </div>
        </div>

        <div className="companion-player orange">
          <div className="companion-player__header">
            <span className="player-tag">Player B</span>
            <span className="timer-pill">06:12</span>
          </div>
          <div className="score">0</div>
          <div className="round-track">BO3 • 0-0</div>
        </div>
      </div>
    </section>
  );
}
