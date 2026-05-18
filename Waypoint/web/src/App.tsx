import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { Box, CircularProgress } from '@mui/material';
import { SnackbarProvider } from 'notistack';
import { ThemeProvider } from './app/contexts/ThemeContext';
import { AuthProvider, useAuth } from './app/contexts/AuthContext';
import { MetricsProvider } from './app/contexts/MetricsContext';
import { WorkspaceProvider, useWorkspace } from './app/contexts/WorkspaceContext';
import { CabinetModeProvider } from './app/contexts/CabinetModeContext';
import { ModernLayout } from './components/layout/ModernLayout';
import { ErrorBoundary } from './components/common/ErrorBoundary';

import { EnhancedDashboard } from './pages/dashboard/EnhancedDashboard';
import { Users } from './pages/users/Users';
import { Projects } from './pages/projects/Projects';
import { Assets } from './pages/assets/Assets';
import { AIAnalysis } from './pages/ai/AIAnalysis';
import { Settings } from './pages/settings/Settings';
import { ConnectedDevicesPage } from './pages/settings/ConnectedDevicesPage';
import Login from './pages/Login';
import Register from './pages/Register';
import VerifyEmail from './pages/VerifyEmail';
import NexusAuth from './pages/NexusAuth';
import { PublicLanding } from './marketing/PublicLanding';
import { TspuProductPage } from './marketing/TspuProductPage';
import { ClubDocsPage } from './marketing/ClubDocsPage';
import { DesktopLandingPage } from './marketing/DesktopLandingPage';
import { DesktopDocsPage } from './marketing/DesktopDocsPage';
import { DesktopReleasesPage } from './marketing/DesktopReleasesPage';
import { MetricDocsPage } from './marketing/MetricDocsPage';
import { ClubSeriesPage } from './marketing/ClubSeriesPage';
import { EcosystemStatusPage } from './marketing/EcosystemStatusPage';
import PlatformPage from './pages/platform/PlatformPage';
import { PrivateRoute } from './components/PrivateRoute';
import { DatabaseHubLayout } from './pages/database/DatabaseHubLayout';
import { DatabaseOverviewPage } from './pages/database/DatabaseOverviewPage';
import { DatabaseSchemaPage } from './pages/database/DatabaseSchemaPage';
import { DatabaseTablesPage } from './pages/database/DatabaseTablesPage';
import { DatabaseSqlPage } from './pages/database/DatabaseSqlPage';
import { DatabaseApiPage } from './pages/database/DatabaseApiPage';
import { DatabaseStoragePage } from './pages/database/DatabaseStoragePage';
import { Instances } from './pages/instances/Instances';
import { Logs } from './pages/logs/Logs';
import { Jobs } from './pages/jobs/Jobs';
import { Versions } from './pages/versions/Versions';
import { RegistrationLog } from './pages/registration/RegistrationLog';
import { IngestLabLayout } from './pages/ingest/IngestLabLayout';
import { IngestLabMetricsPage } from './pages/ingest/IngestLabMetricsPage';
import { IngestLabSummaryPage } from './pages/ingest/IngestLabSummaryPage';
import { IngestLabSimulatePage } from './pages/ingest/IngestLabSimulatePage';
import { IngestLabSendPage } from './pages/ingest/IngestLabSendPage';
import { IngestLabLogsPage } from './pages/ingest/IngestLabLogsPage';
import { IngestLabKeysUsagePage } from './pages/ingest/IngestLabKeysUsagePage';
import { IngestLabDeveloperPlatformPage } from './pages/ingest/IngestLabDeveloperPlatformPage';
import { IngestLabBusinessPage } from './pages/ingest/IngestLabBusinessPage';
import { WaypointLayout } from './pages/waypoint/WaypointLayout';
import {
  WaypointBusinessCatalogPage,
  WaypointDevelopersCatalogPage,
} from './pages/waypoint/WaypointCatalogPage';
import { WaypointAssistantPage } from './pages/waypoint/WaypointAssistantPage';
import { WorkspaceHubPage } from './pages/workspace/WorkspaceHubPage';
import { BusinessHomePage } from './pages/cabinet/BusinessHomePage';
import { BusinessDocumentsPage } from './pages/cabinet/BusinessDocumentsPage';
import { BusinessVouchersPage } from './pages/cabinet/BusinessVouchersPage';
import { BusinessLedgerPage } from './pages/cabinet/BusinessLedgerPage';
import { BusinessLogisticsPage } from './pages/cabinet/BusinessLogisticsPage';
import { BusinessTaxPage } from './pages/cabinet/BusinessTaxPage';
import { BusinessAiPage } from './pages/cabinet/BusinessAiPage';
import { DeveloperHomePage } from './pages/cabinet/DeveloperHomePage';
import { DeveloperAiPage } from './pages/cabinet/DeveloperAiPage';
import { AdminKeys } from './pages/admin/AdminKeys';
import { Onboarding } from './pages/onboarding/Onboarding';
import Docs from './pages/docs/Docs';
import { VkBotModule } from './pages/integrations/VkBotModule';
import { ModuleTesting } from './pages/testing/ModuleTesting';
import { AlgorithmCompare } from './pages/testing/AlgorithmCompare';
import { Billing } from './pages/billing/Billing';
import { GitWorkspace } from './pages/workspace/GitWorkspace';
import { ApiHub } from './pages/workspace/ApiHub';
import { GraphicsLab } from './pages/workspace/GraphicsLab';
import { RealtimeOps } from './pages/workspace/RealtimeOps';
import { DeveloperHub } from './pages/dev/DeveloperHub';
import { NexusCloudLayout } from './pages/nexus-cloud/NexusCloudLayout';
import { CloudHub } from './pages/nexus-cloud/CloudHub';
import { CloudProjectDetailPage } from './pages/nexus-cloud/CloudProjectDetailPage';
import { CloudBuildsPage } from './pages/nexus-cloud/CloudBuildsPage';
import { CloudCommercialPage } from './pages/nexus-cloud/CloudCommercialPage';
import { LynxCloudEnginePage } from './pages/nexus-cloud/LynxCloudEnginePage';


function NexusCloudLegacyRedirect() {
  const { pathname, search } = useLocation();
  const suffix = pathname.replace(/^\/dashboard\/nexus-cloud\/?/, '') || '';
  const target = suffix
    ? `/dashboard/lynx-cloud/${suffix}${search}`
    : `/dashboard/lynx-cloud${search}`;
  return <Navigate to={target} replace />;
}

function HomeGate() {
  const { isAuthenticated, isLoading } = useAuth();
  const { workspace, isLoading: workspaceLoading } = useWorkspace();
  if (isLoading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }
  if (isAuthenticated) {
    if (workspaceLoading) {
      return (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}>
          <CircularProgress />
        </Box>
      );
    }
    return <Navigate to={workspace.setupCompleted ? '/dashboard' : '/workspace/setup'} replace />;
  }
  return <PublicLanding />;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomeGate />} />
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route path="/verify-email" element={<VerifyEmail />} />
      <Route path="/auth/nexus" element={<NexusAuth />} />
      <Route path="/docs" element={<Docs />} />
      <Route path="/platform" element={<PlatformPage />} />
      <Route path="/tspu" element={<TspuProductPage />} />
      <Route path="/club/docs/:product" element={<ClubDocsPage />} />
      <Route path="/desktop" element={<DesktopLandingPage />} />
      <Route path="/desktop/docs" element={<DesktopDocsPage />} />
      <Route path="/desktop/docs/:topic" element={<DesktopDocsPage />} />
      <Route path="/desktop/releases" element={<DesktopReleasesPage />} />
      <Route path="/metric/docs" element={<MetricDocsPage />} />
      <Route path="/metric/docs/:topic" element={<MetricDocsPage />} />
      <Route path="/club/series" element={<ClubSeriesPage />} />
      <Route path="/status" element={<EcosystemStatusPage />} />

      <Route
        path="/dashboard"
        element={
          <PrivateRoute>
            <ModernLayout>
              <WorkspaceHubPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/workspace/setup"
        element={
          <PrivateRoute allowWithoutSetup>
            <ModernLayout>
              <Onboarding />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/business"
        element={
          <PrivateRoute>
            <ModernLayout>
              <BusinessHomePage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/business/documents"
        element={
          <PrivateRoute>
            <ModernLayout>
              <BusinessDocumentsPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/business/vouchers"
        element={
          <PrivateRoute>
            <ModernLayout>
              <BusinessVouchersPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/business/ledger"
        element={
          <PrivateRoute>
            <ModernLayout>
              <BusinessLedgerPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/business/logistics"
        element={
          <PrivateRoute>
            <ModernLayout>
              <BusinessLogisticsPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/business/tax"
        element={
          <PrivateRoute>
            <ModernLayout>
              <BusinessTaxPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/business/ai"
        element={
          <PrivateRoute>
            <ModernLayout>
              <BusinessAiPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/developer"
        element={
          <PrivateRoute>
            <ModernLayout>
              <DeveloperHomePage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/developer/ai"
        element={
          <PrivateRoute>
            <ModernLayout>
              <DeveloperAiPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/overview"
        element={
          <PrivateRoute>
            <ModernLayout>
              <EnhancedDashboard />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/users"
        element={
          <PrivateRoute requiredPermission="users:manage">
            <ModernLayout>
              <Users />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/onboarding"
        element={
          <PrivateRoute allowWithoutSetup>
            <ModernLayout>
              <Onboarding />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/git"
        element={
          <PrivateRoute>
            <ModernLayout>
              <GitWorkspace />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/projects"
        element={
          <PrivateRoute>
            <ModernLayout>
              <Projects />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/vk-bot"
        element={
          <PrivateRoute>
            <ModernLayout>
              <VkBotModule />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/module-testing"
        element={
          <PrivateRoute requireServerConnection>
            <ModernLayout>
              <ModuleTesting />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/module-testing/compare"
        element={
          <PrivateRoute requireServerConnection>
            <ModernLayout>
              <AlgorithmCompare />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/assets"
        element={
          <PrivateRoute>
            <ModernLayout>
              <Assets />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/graphics"
        element={
          <PrivateRoute>
            <ModernLayout>
              <GraphicsLab />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/api"
        element={
          <PrivateRoute requireServerConnection>
            <ModernLayout>
              <ApiHub />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/connect"
        element={
          <PrivateRoute>
            <ModernLayout>
              <DeveloperHub />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/registration-log"
        element={
          <PrivateRoute requiredPermission="registration-log:view">
            <ModernLayout>
              <RegistrationLog />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/waypoint"
        element={
          <PrivateRoute>
            <ModernLayout>
              <WaypointLayout />
            </ModernLayout>
          </PrivateRoute>
        }
      >
        <Route index element={<Navigate to="/dashboard/overview" replace />} />
        <Route path="business" element={<WaypointBusinessCatalogPage />} />
        <Route path="developers" element={<WaypointDevelopersCatalogPage />} />
        <Route path="assistant" element={<WaypointAssistantPage />} />
      </Route>
      <Route
        path="/dashboard/ingest-lab"
        element={
          <PrivateRoute>
            <ModernLayout>
              <IngestLabLayout />
            </ModernLayout>
          </PrivateRoute>
        }
      >
        <Route index element={<Navigate to="summary" replace />} />
        <Route path="send" element={<IngestLabSendPage />} />
        <Route path="business" element={<IngestLabBusinessPage />} />
        <Route path="metrics" element={<IngestLabMetricsPage />} />
        <Route path="logs" element={<IngestLabLogsPage />} />
        <Route path="summary" element={<IngestLabSummaryPage />} />
        <Route path="simulate" element={<IngestLabSimulatePage />} />
        <Route path="keys-usage" element={<IngestLabKeysUsagePage />} />
        <Route path="developer-platform" element={<IngestLabDeveloperPlatformPage />} />
      </Route>
      <Route
        path="/dashboard/database"
        element={
          <PrivateRoute>
            <ModernLayout>
              <DatabaseHubLayout />
            </ModernLayout>
          </PrivateRoute>
        }
      >
        <Route index element={<DatabaseOverviewPage />} />
        <Route path="schema" element={<DatabaseSchemaPage />} />
        <Route path="tables" element={<DatabaseTablesPage />} />
        <Route path="sql" element={<DatabaseSqlPage />} />
        <Route path="api" element={<DatabaseApiPage />} />
        <Route path="storage" element={<DatabaseStoragePage />} />
      </Route>
      <Route path="/dashboard/baas" element={<Navigate to="/dashboard/database" replace />} />
      <Route path="/dashboard/baas/*" element={<Navigate to="/dashboard/database" replace />} />
      <Route
        path="/dashboard/lynx-cloud"
        element={
          <PrivateRoute requireServerConnection>
            <ModernLayout>
              <NexusCloudLayout />
            </ModernLayout>
          </PrivateRoute>
        }
      >
        <Route index element={<Navigate to="projects" replace />} />
        <Route path="projects" element={<CloudHub />} />
        <Route path="projects/:projectId" element={<CloudProjectDetailPage />} />
        <Route path="engine" element={<LynxCloudEnginePage />} />
        <Route path="builds" element={<CloudBuildsPage />} />
        <Route path="commercial" element={<CloudCommercialPage />} />
      </Route>
      <Route
        path="/dashboard/nexus-cloud/*"
        element={
          <PrivateRoute requireServerConnection>
            <ModernLayout>
              <NexusCloudLegacyRedirect />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/nexus-cloud"
        element={
          <PrivateRoute requireServerConnection>
            <ModernLayout>
              <NexusCloudLegacyRedirect />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/billing"
        element={
          <PrivateRoute>
            <ModernLayout>
              <Billing />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/logs"
        element={
          <PrivateRoute requiredPermission="logs:view">
            <ModernLayout>
              <Logs />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/instances"
        element={
          <PrivateRoute requiredPermission="instances:manage">
            <ModernLayout>
              <Instances />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/realtime"
        element={
          <PrivateRoute requiredPermission="realtime:manage">
            <ModernLayout>
              <RealtimeOps />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/jobs"
        element={
          <PrivateRoute requiredPermission="jobs:manage">
            <ModernLayout>
              <Jobs />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/versions"
        element={
          <PrivateRoute>
            <ModernLayout>
              <Versions />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/ai"
        element={
          <PrivateRoute requiredPermission="ai:analyze">
            <ModernLayout>
              <AIAnalysis />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/admin-keys"
        element={
          <PrivateRoute requiredPermission="admin-keys:manage">
            <ModernLayout>
              <AdminKeys />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/settings"
        element={
          <PrivateRoute>
            <ModernLayout>
              <Settings />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route
        path="/dashboard/settings/devices"
        element={
          <PrivateRoute>
            <ModernLayout>
              <ConnectedDevicesPage />
            </ModernLayout>
          </PrivateRoute>
        }
      />
      <Route path="/dashboard/desktop-hosts" element={<Navigate to="/dashboard/settings/devices" replace />} />

      <Route path="/profile" element={<Navigate to="/dashboard/settings" replace />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function App() {
  return (
    <ErrorBoundary>
      <ThemeProvider>
        <SnackbarProvider maxSnack={4} anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}>
          <AuthProvider>
            <WorkspaceProvider>
              <MetricsProvider>
                <Router>
                  <CabinetModeProvider>
                    <AppRoutes />
                  </CabinetModeProvider>
                </Router>
              </MetricsProvider>
            </WorkspaceProvider>
          </AuthProvider>
        </SnackbarProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
}

export default App;
