import router from '@ohos.router';
import { WearLink } from '../services/WearLink';

@Entry
@Component
struct Index {
  @StorageLink('wearMicroDone') microDone: number = 0;
  @StorageLink('wearMicroTarget') microTarget: number = 4;

  aboutToAppear(): void {
    WearLink.init();
  }

  build() {
    Column({ space: 12 }) {
      Text('ChairUp')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.chair_accent'))

      Text($r('app.string.wave_label'))
        .fontSize(12)
        .fontColor($r('app.color.chair_muted'))

      Text(this.slotProgressText())
        .fontSize(16)
        .fontColor($r('app.color.chair_accent'))
        .letterSpacing(4)

      Text(`${this.microDone}/${this.microTarget}`)
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.chair_text'))

      Button($r('app.string.start_micro'))
        .width('90%')
        .height(44)
        .backgroundColor($r('app.color.chair_accent'))
        .fontColor($r('app.color.chair_background'))
        .onClick(() => {
          router.pushUrl({ url: 'pages/MicroTimer', params: { slotIndex: this.microDone, targetSec: 120 } });
        })

      Button($r('app.string.start_strength'))
        .width('90%')
        .height(44)
        .backgroundColor($r('app.color.chair_muted'))
        .fontColor($r('app.color.chair_accent'))
        .onClick(() => {
          router.pushUrl({ url: 'pages/StrengthRest' });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.chair_background'))
  }

  private slotProgressText(): string {
    let s = '';
    for (let i = 0; i < this.microTarget; i++) {
      s += i < this.microDone ? '●' : '○';
    }
    return s;
  }
}
