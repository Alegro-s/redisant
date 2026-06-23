@Entry
@Component
struct MicroDotsForm {
  @LocalStorageProp('wearMicroDone') microDone: number = 0;
  @LocalStorageProp('wearMicroTarget') microTarget: number = 4;

  build() {
    Column() {
      Text(this.dots())
        .fontSize(14)
        .fontColor('#00D9A5')
        .letterSpacing(3)
      Text(`${this.microDone}/${this.microTarget}`)
        .fontSize(10)
        .fontColor('#9AA0A6')
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#0B0F14')
  }

  private dots(): string {
    let s = '';
    const target = Math.min(this.microTarget, 8);
    for (let i = 0; i < target; i++) {
      s += i < this.microDone ? '●' : '○';
    }
    return s;
  }
}
