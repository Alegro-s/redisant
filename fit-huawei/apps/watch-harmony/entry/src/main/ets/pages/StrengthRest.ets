import router from '@ohos.router';
import vibrator from '@ohos.vibrator';

@Entry
@Component
struct StrengthRest {
  @State secondsLeft: number = 60;
  private timerId: number = -1;

  aboutToAppear(): void {
    this.startTimer();
    try {
      vibrator.startVibration({ type: 'time', duration: 120 }, { id: 0, usage: 'alarm' });
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
      Text($r('app.string.strength_rest_title'))
        .fontSize(18)
        .fontColor($r('app.color.chair_muted'))

      Text(this.formatTime(this.secondsLeft))
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.chair_accent'))

      Text($r('app.string.strength_rest_hint'))
        .fontSize(14)
        .fontColor($r('app.color.chair_text'))

      Button($r('app.string.skip_rest'))
        .width('90%')
        .height(44)
        .backgroundColor($r('app.color.chair_accent'))
        .fontColor($r('app.color.chair_background'))
        .onClick(() => {
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
