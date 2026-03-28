import { NavLink, Outlet } from "react-router-dom";

const navItems = [
  { to: "/", label: "Community", icon: "🌍" },
  { to: "/binder", label: "Binder", icon: "📚" },
  { to: "/deck", label: "Deck", icon: "🧊" },
  { to: "/companion", label: "Companion", icon: "✨" },
  { to: "/friends", label: "Friends", icon: "👥" }
];

export function AppShell() {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand-lockup">
          <div className="brand-mark">RS</div>
          <div>
            <strong>RuneShelf</strong>
            <p>Companion Web</p>
          </div>
        </div>

        <nav className="sidebar-nav">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === "/"}
              className={({ isActive }) =>
                isActive ? "sidebar-link active" : "sidebar-link"
              }
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-card">
          <h3>Stack consigliato</h3>
          <p>Supabase per auth e sync cloud, Vite per la webapp, deploy statico su Vercel.</p>
        </div>
      </aside>

      <div className="mobile-topbar">
        <div className="brand-lockup compact">
          <div className="brand-mark">RS</div>
          <div>
            <strong>RuneShelf</strong>
            <p>Web</p>
          </div>
        </div>
      </div>

      <main className="main-content">
        <Outlet />
      </main>

      <nav className="mobile-nav">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === "/"}
            className={({ isActive }) => (isActive ? "mobile-link active" : "mobile-link")}
          >
            <span>{item.icon}</span>
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
