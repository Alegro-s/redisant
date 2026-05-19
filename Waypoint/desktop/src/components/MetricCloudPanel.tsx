import { useState } from 'react';
import type { CloudConfig } from '../services/config';
import { resolveCloudUrls } from '../services/config';
import { claimPairing } from '../services/cloud';

type Props = {
  cfg: CloudConfig;
  setCfg: (c: CloudConfig) => void;
  persist: (c: CloudConfig) => Promise<void>;
  pairCode: string;
  setPairCode: (v: string) => void;
  status: string;
  setStatus: (v: string) => void;
  onOpenMetric: () => void;
  onOpenDevices: () => void;
};

export function MetricCloudPanel({
  cfg,
  setCfg,
  persist,
  pairCode,
  setPairCode,
  status,
  setStatus,
  onOpenMetric,
  onOpenDevices,
}: Props) {
  const [showAdvanced, setShowAdvanced] = useState(false);
  const paired = Boolean(cfg.apiKey);

  const doPair = async () => {
    setStatus('Привязка…');
    try {
      const withUrls = { ...cfg, ...resolveCloudUrls(cfg.cloudUrl) };
      const res = await claimPairing(withUrls, pairCode, withUrls.deviceId, withUrls.deviceName);
      await persist({
        ...withUrls,
        apiKey: res.api_key,
        accessToken: res.access_token || withUrls.accessToken,
        refreshToken: res.refresh_token,
        cloudUrl: res.cloud_url || withUrls.cloudUrl,
      });
      setPairCode('');
      setStatus('ПК привязан к workspace Metric');
    } catch (e) {
      setStatus(`Ошибка: ${e}`);
    }
  };

  return (
    <div className="panel metric-panel">
      <h2 className="panel-title">Waypoint Metric</h2>
      <p className="panel-lead">Синхронизация с облаком: привязка устройства и настройки — на сайте Metric.</p>

      <div className="metric-status-row">
        <span className={`metric-pill ${paired ? 'ok' : ''}`}>{paired ? 'ПК привязан' : 'Не привязан'}</span>
        {cfg.syncTelemetry && <span className="metric-pill">Метрики</span>}
        {cfg.syncTasks && <span className="metric-pill">Задачи</span>}
        {cfg.syncProjects && <span className="metric-pill">Проекты</span>}
      </div>

      <div className="row" style={{ marginTop: '0.75rem' }}>
        <button type="button" className="btn" onClick={onOpenMetric}>
          Открыть Metric
        </button>
        <button type="button" className="btn ghost" onClick={onOpenDevices}>
          Подключённые устройства
        </button>
      </div>

      <p className="status" style={{ marginTop: '1rem' }}>
        В Metric: «Создать код привязки» → «Открыть в Desktop». Или введите код WD-… ниже.
      </p>

      <label>Код привязки</label>
      <div className="row">
        <input
          type="text"
          value={pairCode}
          onChange={(e) => setPairCode(e.target.value)}
          placeholder="WD-XXXXXXXX"
          style={{ flex: 1, marginBottom: 0 }}
        />
        <button type="button" className="btn" onClick={doPair} disabled={!pairCode.trim()}>
          Привязать
        </button>
      </div>

      <label>Имя устройства</label>
      <input
        type="text"
        value={cfg.deviceName}
        onChange={(e) => setCfg({ ...cfg, deviceName: e.target.value })}
        onBlur={() => persist(cfg)}
      />

      <button type="button" className="btn ghost" style={{ marginTop: '0.5rem' }} onClick={() => setShowAdvanced((v) => !v)}>
        {showAdvanced ? 'Скрыть настройки сервера' : 'Настройки сервера'}
      </button>

      {showAdvanced && (
        <>
          <label>Сайт Metric</label>
          <input
            type="url"
            value={cfg.cloudUrl}
            onChange={(e) => setCfg({ ...cfg, cloudUrl: e.target.value })}
            onBlur={() => persist({ ...cfg, ...resolveCloudUrls(cfg.cloudUrl) })}
          />
        </>
      )}

      {status && <p className={`status ${status.includes('Ошибка') ? 'err' : 'ok'}`}>{status}</p>}
    </div>
  );
}
