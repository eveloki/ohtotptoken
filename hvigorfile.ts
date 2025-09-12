import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { hvigor,getNode } from '@ohos/hvigor'

// https://blog.csdn.net/huangyuan_xuan/article/details/145759939
// 获取根节点
const rootNode = getNode(__filename);
// 为根节点添加一个afterNodeEvaluate hook 在hook中修改根目录下的build-profile.json5的内容并使能
rootNode.afterNodeEvaluate(node => {

    //获取命令行参数
    let ignoreSignHap = false
    let propertyIgnoreSignHap = hvigor.getParameter().getProperty('ignoreSignHap');
    if (propertyIgnoreSignHap != undefined) {
        ignoreSignHap = propertyIgnoreSignHap
    }
    console.log("ignoreSignHap-> " + propertyIgnoreSignHap);

    // 获取app插件的上下文对象
    const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
    // 通过上下文对象获取从根目录build-profile.json5文件中读出来的obj对象
    const buildProfileOpt = appContext.getBuildProfileOpt();
    //将 BuildProfile 文件中的ignoreSignHap值改为传入的值
    buildProfileOpt['app']['products'][0]['buildOption']['arkOptions']['buildProfileFields']['ignoreSignHap'] = ignoreSignHap
    if (ignoreSignHap) {
      //清除签名文件信息
        buildProfileOpt['app']['signingConfigs'] = []
    }
    
    // 将obj对象设置回上下文对象以使能到构建的过程与结果中
    appContext.setBuildProfileOpt(buildProfileOpt);
})

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[]         /* Custom plugin to extend the functionality of Hvigor. */
}
