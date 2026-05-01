import { generateCardOTP } from '../utils/CardOTPUtils';

let cardStorage1x2 = new LocalStorage();

@Entry(cardStorage1x2)
@Component
struct TokenCard_1x2 {
  @LocalStorageProp('hasToken') hasToken: string = 'false';
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('formName') formName: string = 'tokenCard_1x2';
  @LocalStorageProp('token0_issuer') token0Issuer: string = '';
  @LocalStorageProp('token0_name') token0Name: string = '';
  @LocalStorageProp('token0_secret') token0Secret: string = '';
  @LocalStorageProp('token0_algorithm') token0Algorithm: string = '';
  @LocalStorageProp('token0_digits') token0Digits: string = '6';
  @LocalStorageProp('token0_period') token0Period: string = '30';
  @LocalStorageProp('token0_type') token0Type: string = '0';
  @LocalStorageProp('token0_counter') token0Counter: string = '0';
  @LocalStorageProp('token0_uuid') token0UUID: string = '';
  @State isFlipped: boolean = false;
  @State currentCode: string = '';
  @State localCounterOffset: number = 0;

  private isHOTP(): boolean {
    return this.token0Type === '2';
  }

  private computeOTP(): string {
    if (this.token0Secret === '') return '';
    const counter = this.isHOTP() ? parseInt(this.token0Counter) + this.localCounterOffset : -1;
    return generateCardOTP(
      this.token0Secret,
      this.token0Algorithm || 'SHA1',
      parseInt(this.token0Digits) || 6,
      parseInt(this.token0Period) || 30,
      this.token0Type,
      counter,
    );
  }

  build() {
    Column() {
      if (this.hasToken !== 'true') {
        Row() {
          SymbolGlyph($r('sys.symbol.key_fill'))
            .fontSize(16)
            .fontColor(['#E6000000'])
          Text('OTP令牌')
            .fontSize(12)
            .fontColor('#E6000000')
            .fontWeight(FontWeight.Bold)
            .margin({ left: 6 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            bundleName: 'smartcityshenzhen.yylx.totptoken',
            abilityName: 'EntryAbility',
            params: {
              action: 'card_config',
              formId: this.formId,
              formName: this.formName,
            }
          });
        })
      } else {
        Column() {
          if (!this.isFlipped) {
            this.TokenFrontView()
          } else {
            this.TokenBackView()
          }
        }
        .width('100%')
        .height('100%')
        .borderRadius(8)
        .backgroundColor('#0F000000')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          if (!this.isFlipped) {
            this.currentCode = this.computeOTP();
            if (this.isHOTP()) {
              this.localCounterOffset++;
              postCardAction(this, {
                action: 'call',
                bundleName: 'smartcityshenzhen.yylx.totptoken',
                abilityName: 'EntryFormAbility',
                params: {
                  action: 'increment_counter',
                  tokenUUID: this.token0UUID,
                  formId: this.formId,
                }
              });
            }
          }
          this.isFlipped = !this.isFlipped;
        })
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(12)
    .backgroundColor('#FFFFFFFF')
    .padding(8)
  }

  @Builder
  TokenFrontView() {
    Row() {
      SymbolGlyph($r('sys.symbol.key_fill'))
        .fontSize(14)
        .fontColor(['#E6000000'])
      Column() {
        Text(this.token0Issuer)
          .fontSize(11)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.token0Name)
          .fontSize(9)
          .fontColor('#99000000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .margin({ left: 6 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  TokenBackView() {
    Row() {
      Column() {
        Text(this.currentCode)
          .fontSize(18)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
          .fontFamily('monospace')
        Text(this.token0Issuer)
          .fontSize(8)
          .fontColor('#99000000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }
}
