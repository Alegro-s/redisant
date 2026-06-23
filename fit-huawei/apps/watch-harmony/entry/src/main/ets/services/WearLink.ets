import wearEngine from '@ohos.wearEngine';

const PHONE_PKG = 'com.chairup.android';

export interface WearState {
  microDone: number;
  microTarget: number;
  dailyScore: number;
  chairMode: boolean;
}

export class WearLink {
  private static state: WearState = { microDone: 0, microTarget: 4, dailyScore: 0, chairMode: true };
  private static p2pClient: wearEngine.p2p.P2pClient | null = null;

  static getState(): WearState {
    return WearLink.state;
  }

  static async init(): Promise<void> {
    try {
      WearLink.p2pClient = wearEngine.getP2pClient(globalThis.context);
      WearLink.p2pClient.registerReceiver({
        onReceiveMessage: (peerPkg: string, message: ArrayBuffer) => {
          const raw = WearLink.bufferToString(message);
          WearLink.handleIncoming(raw);
        }
      });
    } catch (e) {
      console.warn('WearLink init failed: ' + JSON.stringify(e));
    }
  }

  static async sendMicroDone(slotIndex: number, durationSec: number): Promise<void> {
    const payload = JSON.stringify({
      v: 1,
      type: 'MICRO_DONE',
      ts: Date.now(),
      slotIndex,
      durationSec
    });
    await WearLink.send(payload);
  }

  private static async send(payload: string): Promise<void> {
    if (!WearLink.p2pClient) return;
    try {
      const buf = WearLink.stringToBuffer(payload);
      await WearLink.p2pClient.send(PHONE_PKG, buf);
    } catch (e) {
      console.warn('WearLink send failed: ' + JSON.stringify(e));
    }
  }

  private static handleIncoming(raw: string): void {
    try {
      const json = JSON.parse(raw) as Record<string, Object>;
      if (json['type'] !== 'STATE_PUSH') return;
      WearLink.state = {
        microDone: Number(json['microDone'] ?? 0),
        microTarget: Number(json['microTarget'] ?? 4),
        dailyScore: Number(json['dailyScore'] ?? 0),
        chairMode: Boolean(json['chairMode'] ?? true)
      };
      AppStorage.setOrCreate('wearMicroDone', WearLink.state.microDone);
      AppStorage.setOrCreate('wearMicroTarget', WearLink.state.microTarget);
    } catch (e) {
      console.warn('WearLink parse failed');
    }
  }

  private static bufferToString(buf: ArrayBuffer): string {
    const arr = new Uint8Array(buf);
    let s = '';
    for (let i = 0; i < arr.length; i++) {
      s += String.fromCharCode(arr[i]);
    }
    return s;
  }

  private static stringToBuffer(s: string): ArrayBuffer {
    const arr = new Uint8Array(s.length);
    for (let i = 0; i < s.length; i++) {
      arr[i] = s.charCodeAt(i);
    }
    return arr.buffer;
  }
}
