import LandingPage from '../pages/LandingPage';
import { useDocumentTitle } from '../hooks/useDocumentTitle';

/** Облачная витрина Metric — зелёный MUI-лендинг (metrika-waypoint.ru). */
export function MetricCloudLandingPage() {
  useDocumentTitle('Waypoint Metric — облачная консоль');
  return <LandingPage />;
}
