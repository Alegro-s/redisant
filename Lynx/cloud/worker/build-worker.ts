
import { Queue, Worker } from 'bullmq';
import IORedis from 'ioredis';

const connection = new IORedis(process.env.REDIS_URL ?? 'redis://127.0.0.1:6379', {
  maxRetriesPerRequest: null,
});

const q = new Queue('nexus-builds', { connection });

new Worker(
  'nexus-builds',
  async (job) => {
    console.log('[build-worker/bullmq] job', job.id, job.data);
    return { ok: true, note: 'BullMQ — для ручных job; основной поток — nexus-cloud-simple-build-queue.' };
  },
  { connection }
);

const API = (
  process.env.LYNX_API_BASE ?? process.env.NEXUS_API_BASE ?? 'http://127.0.0.1:8080'
).replace(/\/$/, '');
const WORKER_SECRET =
  process.env.LYNX_BUILD_WORKER_SECRET ?? process.env.NEXUS_BUILD_WORKER_SECRET ?? '';

async function reportToApi(body: {
  build_job_id: string;
  status: string;
  log_excerpt?: string;
  error_message?: string;
}) {
  if (!WORKER_SECRET) {
    console.warn('[build-worker] LYNX_BUILD_WORKER_SECRET пуст — статус в API не обновится');
    return;
  }
  const r = await fetch(`${API}/integrations/lynx-cloud/build-report`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Lynx-Build-Worker-Secret': WORKER_SECRET,
    },
    body: JSON.stringify(body),
  });
  if (!r.ok) {
    console.error('[build-worker] build-report HTTP', r.status, await r.text());
  }
}

const blocking = connection.duplicate();

void (async function simpleQueueLoop() {
  console.log('lynx-cloud worker: BRPOP nexus-cloud-simple-build-queue →', API);
  for (;;) {
    try {
      const popped = await blocking.brpop('nexus-cloud-simple-build-queue', 0);
      if (!popped) continue;
      const raw = popped[1];
      let payload: { build_job_id?: string };
      try {
        payload = JSON.parse(raw) as { build_job_id?: string };
      } catch {
        console.error('[build-worker] bad json', raw);
        continue;
      }
      const id = payload.build_job_id;
      if (!id) {
        console.error('[build-worker] missing build_job_id', payload);
        continue;
      }
      await reportToApi({ build_job_id: id, status: 'running' });
      await new Promise((res) => setTimeout(res, 1200));
      await reportToApi({
        build_job_id: id,
        status: 'succeeded',
        log_excerpt: 'stub: worker finished (замените на реальный CI)',
      });
    } catch (e) {
      console.error('[build-worker] loop', e);
      await new Promise((res) => setTimeout(res, 3000));
    }
  }
})();

void q;
console.log('lynx-cloud build worker listening on', process.env.REDIS_URL ?? 'redis://127.0.0.1:6379');
