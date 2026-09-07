import { LoadingDialogV2 } from '@kit.ArkUI';
import { TokenBatchProgress } from 'common';

@ObservedV2
export class TokenProgressDialogParams {
  @Trace title: ResourceStr;
  @Trace progress: TokenBatchProgress;

  constructor(title: ResourceStr, progress: TokenBatchProgress) {
    this.title = title;
    this.progress = progress;
  }
}

@ComponentV2
export struct TokenProgressDialog {
  @Require @Param params: TokenProgressDialogParams;

  build() {
    LoadingDialogV2({ content: $r('app.string.token_batch_loading') })
      .id('token_batch_progress_dialog')
  }
}
