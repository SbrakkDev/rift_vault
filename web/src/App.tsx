import { Navigate, Route, Routes } from "react-router-dom";
import { AppShell } from "./components/AppShell";
import { CommunityPage } from "./pages/CommunityPage";
import { BinderPage } from "./pages/BinderPage";
import { DeckPage } from "./pages/DeckPage";
import { CompanionPage } from "./pages/CompanionPage";
import { FriendsPage } from "./pages/FriendsPage";

export default function App() {
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<CommunityPage />} />
        <Route path="/binder" element={<BinderPage />} />
        <Route path="/deck" element={<DeckPage />} />
        <Route path="/companion" element={<CompanionPage />} />
        <Route path="/friends" element={<FriendsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
