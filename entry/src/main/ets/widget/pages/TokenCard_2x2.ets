import { generateCardOTP } from '../utils/CardOTPUtils';

let cardStorage2x2 = new LocalStorage();

@Entry(cardStorage2x2)
@Component
struct TokenCard_2x2 {
  @LocalStorageProp('hasToken') hasToken: string = 'false';
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('formName') formName: string = 'tokenCard_2x2';
  @LocalStorageProp('token0_issuer') token0Issuer: string = '';
  @LocalStorageProp('token0_name') token0Name: string = '';
  @LocalStorageProp('token0_secret') token0Secret: string = '';
  @LocalStorageProp('token0_algorithm') token0Algorithm: string = '';
  @LocalStorageProp('token0_digits') token0Digits: string = '6';
  @LocalStorageProp('token0_period') token0Period: string = '30';
  @LocalStorageProp('token0_type') token0Type: string = '0';
  @LocalStorageProp('token0_counter') token0Counter: string = '0';
  @LocalStorageProp('token0_uuid') token0UUID: string = '';
  @LocalStorageProp('token1_issuer') token1Issuer: string = '';
  @LocalStorageProp('token1_name') token1Name: string = '';
  @LocalStorageProp('token1_secret') token1Secret: string = '';
  @LocalStorageProp('token1_algorithm') token1Algorithm: string = '';
  @LocalStorageProp('token1_digits') token1Digits: string = '6';
  @LocalStorageProp('token1_period') token1Period: string = '30';
  @LocalStorageProp('token1_type') token1Type: string = '0';
  @LocalStorageProp('token1_counter') token1Counter: string = '0';
  @LocalStorageProp('token1_uuid') token1UUID: string = '';
  @State flippedIndex: number = -1;
  @State currentCode0: string = '';
  @State currentCode1: string = '';
  @State localCounterOffset0: number = 0;
  @State localCounterOffset1: number = 0;

  private isHOTP(index: number): boolean {
    return index === 0 ? this.token0Type === '2' : this.token1Type === '2';
  }

  private computeOTP(index: number): string {
    const secret = index === 0 ? this.token0Secret : this.token1Secret;
    if (secret === '') return '';
    const algorithm = (index === 0 ? this.token0Algorithm : this.token1Algorithm) || 'SHA1';
    const digits = parseInt(index === 0 ? this.token0Digits : this.token1Digits) || 6;
    const period = parseInt(index === 0 ? this.token0Period : this.token1Period) || 30;
    const tokenType = index === 0 ? this.token0Type : this.token1Type;
    const baseCounter = parseInt(index === 0 ? this.token0Counter : this.token1Counter);
    const offset = index === 0 ? this.localCounterOffset0 : this.localCounterOffset1;
    const counter = this.isHOTP(index) ? baseCounter + offset : -1;
    return generateCardOTP(secret, algorithm, digits, period, tokenType, counter);
  }

  build() {
    Column() {
      if (this.hasToken !== 'true') {
        Column() {
          SymbolGlyph($r('sys.symbol.key_fill'))
            .fontSize(32)
            .fontColor(['#E6000000'])
          Text('OTP令牌')
            .fontSize(16)
            .fontColor('#E6000000')
            .fontWeight(FontWeight.Bold)
            .margin({ top: 8 })
          Text('点击配置令牌')
            .fontSize(12)
            .fontColor('#99000000')
            .margin({ top: 4 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
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
        Column({ space: 8 }) {
          if (this.token0Issuer !== '') {
            Column() {
              if (this.flippedIndex !== 0) {
                this.TokenFrontView(this.token0Issuer, this.token0Name)
              } else {
                this.TokenBackView(this.currentCode0, this.token0Issuer)
              }
            }
            .width('100%')
            .layoutWeight(1)
            .borderRadius(12)
            .backgroundColor('#0F000000')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => {
              if (this.flippedIndex !== 0) {
                this.currentCode0 = this.computeOTP(0);
                this.flippedIndex = 0;
                if (this.isHOTP(0)) {
                  this.localCounterOffset0++;
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
              } else {
                this.flippedIndex = -1;
              }
            })
          }

          if (this.token1Issuer !== '') {
            Column() {
              if (this.flippedIndex !== 1) {
                this.TokenFrontView(this.token1Issuer, this.token1Name)
              } else {
                this.TokenBackView(this.currentCode1, this.token1Issuer)
              }
            }
            .width('100%')
            .layoutWeight(1)
            .borderRadius(12)
            .backgroundColor('#0F000000')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => {
              if (this.flippedIndex !== 1) {
                this.currentCode1 = this.computeOTP(1);
                this.flippedIndex = 1;
                if (this.isHOTP(1)) {
                  this.localCounterOffset1++;
                  postCardAction(this, {
                    action: 'call',
                    bundleName: 'smartcityshenzhen.yylx.totptoken',
                    abilityName: 'EntryFormAbility',
                    params: {
                      action: 'increment_counter',
                      tokenUUID: this.token1UUID,
                      formId: this.formId,
                    }
                  });
                }
              } else {
                this.flippedIndex = -1;
              }
            })
          } else {
            Column() {
              Text('+')
                .fontSize(20)
                .fontColor('#99000000')
            }
            .width('100%')
            .layoutWeight(1)
            .borderRadius(12)
            .backgroundColor('#0F000000')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
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
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .backgroundColor('#FFFFFFFF')
    .padding(12)
  }

  @Builder
  TokenFrontView(issuer: string, name: string) {
    Row() {
      SymbolGlyph($r('sys.symbol.key_fill'))
        .fontSize(18)
        .fontColor(['#E6000000'])
      Column() {
        Text(issuer)
          .fontSize(13)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(name)
          .fontSize(11)
          .fontColor('#99000000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .margin({ left: 8 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  TokenBackView(code: string, issuer: string) {
    Row() {
      Column() {
        Text(code)
          .fontSize(24)
          .fontColor('#E6000000')
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
          .fontFamily('monospace')
        Text(issuer)
          .fontSize(10)
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
