import { Route, Routes } from 'react-router-dom';
import { GamingLayout } from './layouts/GamingLayout';
import { RozaRedirect } from './components/RozaRedirect';
import { HomePage } from './pages/HomePage';
import { DownloadPage } from './pages/DownloadPage';
import { BlogPage } from './pages/BlogPage';
import { DocsPage } from './pages/DocsPage';
import { PricingPage } from './pages/PricingPage';
import { BusinessPage } from './pages/BusinessPage';
import { ProjectsPage } from './pages/ProjectsPage';
import { SignInPage } from './pages/SignInPage';
import { LegalPage } from './pages/LegalPage';
import { AdminPage } from './pages/AdminPage';
import { AdminGate } from './components/AdminGate';
import { AccountPage } from './pages/AccountPage';
function GamingRoute({ children }: { children: React.ReactNode }) {
  return <GamingLayout>{children}</GamingLayout>;
}

export function App() {
  return (
    <Routes>
      <Route
        path="/"
        element={
          <GamingRoute>
            <HomePage />
          </GamingRoute>
        }
      />
      <Route
        path="/download"
        element={
          <GamingRoute>
            <DownloadPage />
          </GamingRoute>
        }
      />
      <Route
        path="/blog"
        element={
          <GamingRoute>
            <BlogPage />
          </GamingRoute>
        }
      />
      <Route
        path="/docs"
        element={
          <GamingRoute>
            <DocsPage />
          </GamingRoute>
        }
      />
      <Route
        path="/pricing"
        element={
          <GamingRoute>
            <PricingPage />
          </GamingRoute>
        }
      />
      <Route
        path="/business"
        element={
          <GamingRoute>
            <BusinessPage />
          </GamingRoute>
        }
      />
      <Route
        path="/projects"
        element={
          <GamingRoute>
            <ProjectsPage />
          </GamingRoute>
        }
      />
      <Route
        path="/privacy"
        element={
          <GamingRoute>
            <LegalPage />
          </GamingRoute>
        }
      />
      <Route
        path="/terms"
        element={
          <GamingRoute>
            <LegalPage />
          </GamingRoute>
        }
      />
      <Route
        path="/sign-in"
        element={
          <GamingRoute>
            <SignInPage />
          </GamingRoute>
        }
      />
      <Route
        path="/register"
        element={
          <GamingRoute>
            <SignInPage />
          </GamingRoute>
        }
      />
      <Route
        path="/account"
        element={
          <GamingRoute>
            <AccountPage />
          </GamingRoute>
        }
      />
      <Route
        path="/admin"
        element={
          <GamingRoute>
            <AdminGate>
              <AdminPage />
            </AdminGate>
          </GamingRoute>
        }
      />
      <Route path="/roza/*" element={<RozaRedirect />} />
    </Routes>
  );
}
