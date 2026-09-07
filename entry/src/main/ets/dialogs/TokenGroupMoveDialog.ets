import { AdvancedDialogV2Button, CustomContentDialogV2 } from '@kit.ArkUI';
import { TokenGroupSelect } from '../components/TokenGroupSelect';

@ComponentV2
export struct TokenGroupMoveDialog {
  @Event onConfirm: (id: string) => void = () => {};
  @Event onClose: () => void = () => {};
  @Local groupId: string = '';

  @Builder
  ContentBuilder() {
    TokenGroupSelect({
      groupId: this.groupId,
      onChange: (id: string) => { this.groupId = id; }
    })
  }

  build() {
    CustomContentDialogV2({
      primaryTitle: $r('app.string.token_group_move'),
      contentBuilder: () => this.ContentBuilder(),
      buttons: [
        new AdvancedDialogV2Button({
          content: $r('app.string.dialog_btn_cancel'),
          action: () => this.onClose()
        }),
        new AdvancedDialogV2Button({
          content: $r('app.string.dialog_btn_confirm'),
          action: () => this.onConfirm(this.groupId)
        })
      ]
    })
  }
}
