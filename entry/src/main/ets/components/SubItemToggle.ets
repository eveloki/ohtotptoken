/**
 * Copyright (c) 2021-2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@ComponentV2
export struct SubItemToggle {
  @Require @Param onChange: (isOn: boolean) => void = () => {};
  @Require @Param title: string | Resource = '';
  @Require @Param isOn: boolean = false;
  @Param icon: Resource | undefined = undefined;
  @Param description: string  | Resource = '';

  build() {
    Column() {
      Row({ space: 10 }) {
        if (this.icon != undefined) {
          SymbolGlyph(this.icon)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor([$r('app.color.str_main')])
        }
        Text(this.title)
          .fontSize($r('sys.float.ohos_id_text_size_body1'))
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontWeight(FontWeight.Regular)
          .textAlign(TextAlign.Start)

        Blank()

        Toggle({ type: ToggleType.Switch, isOn: this.isOn })
          .id('ToggleSwitch')
          .width(36)
          .height(20)
          .onChange((isOn: boolean) => {
            this.onChange(isOn);
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
      }
      .width('100%')
      if (this.description != '') {
        Text(this.description)
          .fontSize($r('sys.float.ohos_id_text_size_body2'))
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .fontWeight(FontWeight.Regular)
          .fontFamily('HarmonyHeiTi')
          .lineHeight(19)
          .width('100%')
      }
    }
    .padding(10)
  }
}