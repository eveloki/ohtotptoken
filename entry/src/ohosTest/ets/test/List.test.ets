import GoogleAuthUtilsTest from './GoogleAuthUtils.test'
import abilityTest from './Ability.test';
import tokenBatchTest from './TokenBatch.test';
import assetConcurrencyTest from './AssetConcurrency.test';
import tokenProgressDialogTest from './TokenProgressDialog.test';

export default function testsuite() {
  abilityTest();
  GoogleAuthUtilsTest()
  tokenBatchTest();
  assetConcurrencyTest();
  tokenProgressDialogTest();
}