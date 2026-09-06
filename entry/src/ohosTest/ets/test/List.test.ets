import GoogleAuthUtilsTest from './GoogleAuthUtils.test'
import abilityTest from './Ability.test';
import tokenBatchTest from './TokenBatch.test';

export default function testsuite() {
  abilityTest();
  GoogleAuthUtilsTest()
  tokenBatchTest();
}