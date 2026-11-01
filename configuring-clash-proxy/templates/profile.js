// Portable Clash Verge profile enhancement. ES5 only; rendered by Install-ClashProxy.ps1.
var tailscaleEnabled = __TAILSCALE_ENABLED__;

function main(config, profileName) {
    if (!config.proxies || !config.proxies.length) {
        throw new Error('Subscription has no inline proxies; proxy-provider-only profiles are not supported.');
    }

    var names = [];
    var seenNames = {};
    var serverRules = [];
    var seenServers = {};
    var i;
    for (i = 0; i < config.proxies.length; i++) {
        var proxy = config.proxies[i];
        if (!proxy || !proxy.name || seenNames[proxy.name]) continue;
        if (proxy.name === '节点选择' || proxy.name === '自动选择' || proxy.name === 'DIRECT') {
            throw new Error('Subscription contains reserved proxy name: ' + proxy.name);
        }
        seenNames[proxy.name] = true;
        names.push(proxy.name);
        var server = String(proxy.server || '').replace(/^\[|\]$/g, '');
        if (seenServers[server]) continue;
        if (/^(\d{1,3}\.){3}\d{1,3}$/.test(server)) {
            seenServers[server] = true;
            serverRules.push('IP-CIDR,' + server + '/32,DIRECT,no-resolve');
        } else if (server.indexOf(':') !== -1) {
            seenServers[server] = true;
            serverRules.push('IP-CIDR6,' + server + '/128,DIRECT,no-resolve');
        }
    }
    if (!names.length) throw new Error('Subscription has no inline proxies with usable names.');

    config.mode = 'rule';
    config['mixed-port'] = 7897;
    config['allow-lan'] = false;
    config['log-level'] = 'info';
    config.ipv6 = true;
    config['unified-delay'] = true;
    config['tcp-concurrent'] = true;
    config['find-process-mode'] = 'always';
    config['geodata-mode'] = true;
    config['geo-auto-update'] = false;
    config.profile = { 'store-selected': true };
    config['geox-url'] = {
        geoip: 'https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat',
        geosite: 'https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat',
        mmdb: 'https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country-lite.mmdb'
    };
    config.tun = {
        enable: true,
        stack: 'mips',
        'auto-route': true,
        'strict-route': false,
        'auto-detect-interface': true,
        'dns-hijack': ['any:53']
    };
    config['proxy-groups'] = [
        {
            name: '节点选择',
            type: 'select',
            proxies: ['自动选择'].concat(names, ['DIRECT'])
        },
        {
            name: '自动选择',
            type: 'url-test',
            url: 'https://www.gstatic.com/generate_204',
            interval: 300,
            tolerance: 50,
            proxies: names
        }
    ];

    var tailscaleRules = [];
    if (tailscaleEnabled) {
        tailscaleRules = [
            'PROCESS-NAME,tailscaled.exe,DIRECT',
            'PROCESS-NAME,Tailscale.exe,DIRECT',
            'PROCESS-NAME,tailscale-ipn.exe,DIRECT',
            'AND,((NETWORK,UDP),(SRC-PORT,41641)),DIRECT',
            'IP-CIDR,100.64.0.0/10,DIRECT,no-resolve',
            'IP-CIDR,100.100.100.100/32,DIRECT,no-resolve',
            'IP-CIDR6,fd7a:115c:a1e0::/48,DIRECT,no-resolve',
            'DOMAIN-SUFFIX,ts.net,DIRECT',
            'DOMAIN-SUFFIX,tailscale.io,DIRECT'
        ];
    }

    var splitRules = [
        'GEOSITE,private,DIRECT',
        'GEOIP,private,DIRECT,no-resolve',
        'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
        'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
        'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
        'IP-CIDR,169.254.0.0/16,DIRECT,no-resolve',
        'DOMAIN-SUFFIX,msftconnecttest.com,DIRECT',
        'DOMAIN-SUFFIX,msftncsi.com,DIRECT',
        'DOMAIN-SUFFIX,cn,DIRECT',
        'DOMAIN-SUFFIX,bilibili.com,DIRECT',
        'DOMAIN-SUFFIX,bilivideo.com,DIRECT',
        'DOMAIN-SUFFIX,hdslb.com,DIRECT',
        'DOMAIN-SUFFIX,biliapi.net,DIRECT',
        'DOMAIN-SUFFIX,youku.com,DIRECT',
        'DOMAIN-SUFFIX,ykimg.com,DIRECT',
        'DOMAIN-SUFFIX,soku.com,DIRECT',
        'DOMAIN-SUFFIX,iqiyi.com,DIRECT',
        'DOMAIN-SUFFIX,mgtv.com,DIRECT',
        'DOMAIN-SUFFIX,baidu.com,DIRECT',
        'DOMAIN-SUFFIX,bdstatic.com,DIRECT',
        'DOMAIN-SUFFIX,bdimg.com,DIRECT',
        'DOMAIN-SUFFIX,baidubce.com,DIRECT',
        'DOMAIN-SUFFIX,bcebos.com,DIRECT',
        'DOMAIN-SUFFIX,deepseek.com,DIRECT',
        'DOMAIN-SUFFIX,moonshot.cn,DIRECT',
        'DOMAIN-SUFFIX,kimi.com,DIRECT',
        'DOMAIN-SUFFIX,bigmodel.cn,DIRECT',
        'DOMAIN-SUFFIX,zhipuai.cn,DIRECT',
        'DOMAIN-SUFFIX,chatglm.cn,DIRECT',
        'DOMAIN-SUFFIX,aliyuncs.com,DIRECT',
        'DOMAIN-SUFFIX,aliyun.com,DIRECT',
        'DOMAIN-SUFFIX,volces.com,DIRECT',
        'DOMAIN-SUFFIX,volcengine.com,DIRECT',
        'DOMAIN-SUFFIX,doubao.com,DIRECT',
        'DOMAIN-SUFFIX,minimax.chat,DIRECT',
        'DOMAIN-SUFFIX,minimaxi.com,DIRECT',
        'DOMAIN-SUFFIX,stepfun.com,DIRECT',
        'DOMAIN-SUFFIX,siliconflow.cn,DIRECT',
        'DOMAIN-SUFFIX,baichuan-ai.com,DIRECT',
        'DOMAIN-SUFFIX,modelscope.cn,DIRECT',
        'DOMAIN-SUFFIX,xf-yun.com,DIRECT',
        'DOMAIN-SUFFIX,iflytek.com,DIRECT',
        'DOMAIN-SUFFIX,sensetime.com,DIRECT',
        'DOMAIN-SUFFIX,sensenova.cn,DIRECT',
        'DOMAIN-SUFFIX,lingyiwanwu.com,DIRECT',
        'DOMAIN-SUFFIX,qianwen.com,DIRECT',
        'DOMAIN-SUFFIX,tencent.com,DIRECT',
        'DOMAIN-SUFFIX,myqcloud.com,DIRECT',
        'DOMAIN-SUFFIX,qq.com,DIRECT',
        'DOMAIN-SUFFIX,gtimg.com,DIRECT',
        'DOMAIN-SUFFIX,weixin.com,DIRECT',
        'DOMAIN-SUFFIX,wechat.com,DIRECT',
        'DOMAIN-SUFFIX,taobao.com,DIRECT',
        'DOMAIN-SUFFIX,tmall.com,DIRECT',
        'DOMAIN-SUFFIX,alipay.com,DIRECT',
        'DOMAIN-SUFFIX,alicdn.com,DIRECT',
        'DOMAIN-SUFFIX,alibaba.com,DIRECT',
        'DOMAIN-SUFFIX,1688.com,DIRECT',
        'DOMAIN-SUFFIX,jd.com,DIRECT',
        'DOMAIN-SUFFIX,360buyimg.com,DIRECT',
        'DOMAIN-SUFFIX,163.com,DIRECT',
        'DOMAIN-SUFFIX,126.com,DIRECT',
        'DOMAIN-SUFFIX,netease.com,DIRECT',
        'DOMAIN-SUFFIX,sina.com.cn,DIRECT',
        'DOMAIN-SUFFIX,weibo.com,DIRECT',
        'DOMAIN-SUFFIX,zhihu.com,DIRECT',
        'DOMAIN-SUFFIX,douyin.com,DIRECT',
        'DOMAIN-SUFFIX,douyinpic.com,DIRECT',
        'DOMAIN-SUFFIX,douyinvod.com,DIRECT',
        'DOMAIN-SUFFIX,iesdouyin.com,DIRECT',
        'DOMAIN-SUFFIX,kuaishou.com,DIRECT',
        'DOMAIN-SUFFIX,meituan.com,DIRECT',
        'DOMAIN-SUFFIX,dianping.com,DIRECT',
        'DOMAIN-SUFFIX,ctrip.com,DIRECT',
        'DOMAIN-SUFFIX,feishu.cn,DIRECT',
        'DOMAIN-SUFFIX,dingtalk.com,DIRECT',
        'DOMAIN-SUFFIX,gitee.com,DIRECT',
        'DOMAIN-SUFFIX,csdn.net,DIRECT',
        'DOMAIN-SUFFIX,cnblogs.com,DIRECT',
        'DOMAIN-SUFFIX,mi.com,DIRECT',
        'DOMAIN-SUFFIX,xiaomi.com,DIRECT',
        'DOMAIN-SUFFIX,huawei.com,DIRECT',
        'DOMAIN-SUFFIX,bytedance.com,DIRECT',
        'DOMAIN-SUFFIX,toutiao.com,DIRECT',
        'DOMAIN-SUFFIX,pinduoduo.com,DIRECT',
        'DOMAIN-SUFFIX,eastmoney.com,DIRECT',
        'GEOSITE,cn,DIRECT',
        'GEOSITE,geolocation-!cn,节点选择',
        'GEOIP,CN,DIRECT',
        'MATCH,节点选择'
    ];
    config.rules = serverRules.concat(tailscaleRules, splitRules);

    var filters = ['*.lan', '+.local', '+.msftconnecttest.com', '+.msftncsi.com'];
    if (tailscaleEnabled) filters = filters.concat(['+.ts.net', '+.tailscale.com', '+.tailscale.io']);
    filters = filters.concat(['+.alidns.com', '+.doh.pub', 'dns.google']);
    var policy = { 'geosite:cn': ['223.5.5.5', '119.29.29.29'] };
    if (tailscaleEnabled) policy['+.ts.net'] = '100.100.100.100';
    config.dns = {
        enable: true,
        ipv6: true,
        'enhanced-mode': 'fake-ip',
        'fake-ip-range': '198.18.0.1/16',
        'fake-ip-filter': filters,
        'default-nameserver': ['223.5.5.5', '119.29.29.29'],
        'proxy-server-nameserver': ['223.5.5.5', '119.29.29.29'],
        nameserver: ['https://1.1.1.1/dns-query', 'https://8.8.8.8/dns-query'],
        'nameserver-policy': policy,
        'fake-ip-range6': '2001:2::0/64'
    };
    return config;
}
