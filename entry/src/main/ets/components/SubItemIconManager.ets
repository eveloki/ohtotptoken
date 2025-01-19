import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { readFileContent, showSelectFilePicker } from '../utils/FileUtils';
import { AegisIconPack } from '../utils/TokenUtils';
import { BusinessError, zlib } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { SubItemDivider } from './SubItemDivider';

@Preview
@ComponentV2
export struct SubItemIconManager {
  @Require @Param onChange: (selected: number) => void = () => {};
  @Local collapsed: boolean = true;
  @Local installed_icon_pack: AegisIconPack[] = [];

  private appCtx = AppStorage.get<common.UIAbilityContext>('appContext') as common.UIAbilityContext;
  private icon_pack_dir = this.appCtx.cacheDir + "/icon_packs";

  aboutToAppear(): void {
    this.refreshIconPack();
  }

  refreshIconPack(): void {
    this.installed_icon_pack = [];
    fs.listFile(this.icon_pack_dir).then((paths) => {
      paths.forEach((path) => {
        const icon_path_json = this.icon_pack_dir + "/" + path + "/pack.json";
        readFileContent(icon_path_json).then((val) => {
          let pack = JSON.parse(val) as AegisIconPack;
          pack.on_device_path = this.icon_pack_dir + "/" + path;
          this.installed_icon_pack.push(pack);
        })
      })
    });
  }

  build() {
    Column() {
      Row() {
        Column() {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.plus_square_on_square'))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor([$r('app.color.str_main')])

            Text($r('app.string.setting_icon_pack'))
              .fontSize($r('sys.float.ohos_id_text_size_body1'))
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .fontWeight(FontWeight.Regular)
              .textAlign(TextAlign.Start)
          }

          Text($r('app.string.setting_icon_pack_desc'))
            .fontSize($r('sys.float.ohos_id_text_size_body2'))
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .fontWeight(FontWeight.Regular)
            .fontFamily('HarmonyHeiTi')
            .lineHeight(19)
        }
        .layoutWeight(2)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          Blank()
          Text($r('app.string.setting_icon_pack_preview', this.installed_icon_pack.length))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontColor([$r('sys.color.font_tertiary')])
            .fontSize(24)
            .height(48)
            .align(Alignment.Center)
            .rotate(this.collapsed ? { angle: 0 } : { angle: 90 })
            .translate(this.collapsed ? {} : { x: -3 })
        }
        .layoutWeight(1)
        .onClick(() => {
          animateTo({ duration: 200, curve: Curve.Sharp }, () => {
            this.collapsed = !this.collapsed;
          })
        })

      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')

      if (!this.collapsed) {
        Column() {
          SubItemDivider()
            .margin({ bottom: 5 })
          if (this.installed_icon_pack.length === 0) {
            Row() {
              Text($r('app.string.setting_icon_pack_info'))
                .fontSize($r('sys.float.ohos_id_text_size_body1'))
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .fontWeight(FontWeight.Regular)
                .textAlign(TextAlign.Start)
              Column({ space: 10 }) {
                Hyperlink('https://github.com/aegis-icons/aegis-icons/releases/latest/download/aegis-icons.zip', 'aegis-icons')
                Hyperlink('https://github.com/Delta-Icons/aegis/releases/latest/download/delta-aegis-icons.zip', 'delta-icons')
              }
              .alignItems(HorizontalAlign.Center)
              .layoutWeight(1)
            }
            .padding(10)
            .borderRadius(10)
            .backgroundColor($r('app.color.icon_pack_bg'))
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          List({ space: 5 }) {
            ForEach(this.installed_icon_pack, (icon_pack: AegisIconPack) => {
              ListItem(){
                Row() {
                  Column() {
                    Text($r('app.string.setting_icon_pack_title', icon_pack.name, icon_pack.version.toString()))
                      .fontSize($r('sys.float.ohos_id_text_size_body1'))
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                      .fontWeight(FontWeight.Regular)
                      .textAlign(TextAlign.Start)
                    Text($r('app.string.setting_icon_pack_count', icon_pack.icons.length))
                      .fontSize($r('sys.float.ohos_id_text_size_body3'))
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .fontWeight(FontWeight.Regular)
                      .textAlign(TextAlign.Start)
                  }
                  .alignItems(HorizontalAlign.Start)
                  Row() {
                    SymbolGlyph($r('sys.symbol.trash'))
                      .fontSize(20)
                      .fontWeight(FontWeight.Medium)
                      .fontColor([$r('app.color.str_main')])
                  }
                  .width('10%')
                  .onClick(() => {
                    AlertDialog.show({
                      message: $r('app.string.alert_icon_pack_remove_confirm_msg', icon_pack.name),
                      autoCancel: true,
                      alignment: DialogAlignment.Center,
                      primaryButton: {
                        defaultFocus: false,
                        value: $r('app.string.dialog_btn_cancel'),
                        action: () => {
                          return
                        } },
                      secondaryButton: {
                        value: $r('app.string.dialog_btn_confirm'),
                        fontColor: Color.Red,
                        action: async () => {
                          fs.rmdir(icon_pack.on_device_path).then(() => {
                            this.refreshIconPack();
                          });
                        }
                      }
                    })
                  })
                }
                .padding(10)
                .borderRadius(10)
                .backgroundColor($r('app.color.icon_pack_bg'))
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }
              .width('100%')
            }, (icon_pack: AegisIconPack) => {
              return icon_pack.name + icon_pack.on_device_path + icon_pack.version;
            })
          }
          .width('100%')

          Button($r('app.string.setting_add_icon_pack'))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .width('60%')
            .margin({ top: 10 })
            .onClick(() => {
              showSelectFilePicker(1, ["ZIP File|.zip"]).then((paths) => {
                fs.open(paths[0]).then((fd) => {
                  const path_arr = fd.path.split('/');
                  const file_name = path_arr[path_arr.length-1];
                  const out_path = this.icon_pack_dir + "/" + file_name;
                  fs.mkdir(out_path).finally(() => {
                    zlib.decompressFile(fd.path, out_path).then(() => {
                      this.refreshIconPack();
                      fs.close(fd.fd);
                    }).catch((reason: BusinessError) => {
                      promptAction.showToast(reason)
                      fs.close(fd.fd);
                    });
                  });
                });
              });
            })
        }
          .width('100%')
      }
    }
    .width('100%')
    .padding(10)
  }
}