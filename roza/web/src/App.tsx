import { Route, Routes } from 'react-router-dom';
import { RozaLayout } from './layouts/RozaLayout';
import { RozaHubPage } from './pages/RozaHubPage';
import { RozaAiPage } from './pages/RozaAiPage';
import { RozaOsPage } from './pages/RozaOsPage';
import { RozaOsDocsPage } from './pages/RozaOsDocsPage';
import { RozaSecurityPage } from './pages/RozaSecurityPage';
import { RozaAccountPage } from './pages/RozaAccountPage';
import { RozaVerifyEmailPage } from './pages/RozaVerifyEmailPage';

export function App() {
  return (
    <Routes>
      <Route path="/" element={<RozaLayout />}>
        <Route index element={<RozaHubPage />} />
        <Route path="ai" element={<RozaAiPage />} />
        <Route path="os" element={<RozaOsPage />} />
        <Route path="os/docs" element={<RozaOsDocsPage />} />
        <Route path="security" element={<RozaSecurityPage />} />
        <Route path="account" element={<RozaAccountPage />} />
        <Route path="verify-email" element={<RozaVerifyEmailPage />} />
      </Route>
    </Routes>
  );
}
