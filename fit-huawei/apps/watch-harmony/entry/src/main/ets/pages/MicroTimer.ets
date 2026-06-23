import router from '@ohos.router';
import vibrator from '@ohos.vibrator';
import { WearLink } from '../services/WearLink';

@Entry
@Component
struct MicroTimer {
  @State secondsLeft: number = 120;
  @StorageLink('wearMicroTarget') microTarget: number = 4;
  private timerId: number = -1;
  private slotIndex: number = 0;
  private startedAt: number = Date.now();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    this.slotIndex = Number(params?.['slotIndex'] ?? 0);
    const targetSec = Number(params?.['targetSec'] ?? 120);
    this.secondsLeft = targetSec;
    this.startedAt = Date.now();
    this.startTimer();
    try {
      vibrator.startVibration({ type: 'time', duration: 80 }, { id: 0, usage: 'alarm' });
    } catch (e) {
      // device may not support
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
    }
  }

  build() {
    Column({ space: 16 }) {
      Text($r('app.string.micro_title'))
        .fontSize(18)
        .fontColor($r('app.color.chair_muted'))

      Text(this.formatTime(this.secondsLeft))
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.chair_accent'))

      Text('пройдись / вода')
        .fontSize(14)
        .fontColor($r('app.color.chair_text'))

      Button($r('app.string.done_micro'))
        .width('90%')
        .height(44)
        .backgroundColor($r('app.color.chair_accent'))
        .fontColor($r('app.color.chair_background'))
        .onClick(async () => {
          const durationSec = Math.max(60, Math.floor((Date.now() - this.startedAt) / 1000));
          await WearLink.sendMicroDone(this.slotIndex, durationSec);
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.chair_background'))
  }

  private startTimer(): void {
    this.timerId = setInterval(() => {
      if (this.secondsLeft > 0) {
        this.secondsLeft -= 1;
      } else {
        try {
          vibrator.startVibration({ type: 'time', duration: 200 }, { id: 0, usage: 'alarm' });
        } catch (e) {
          // ignore
        }
      }
    }, 1000);
  }

  private formatTime(totalSec: number): string {
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    const sec = s < 10 ? `0${s}` : `${s}`;
    return `${m}:${sec}`;
  }
}
