'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const templatePath = path.join(__dirname, '..', 'templates', 'profile.js');
const settingsPath = path.join(__dirname, '..', 'templates', 'settings.json');

function loadSettings() {
  assert.ok(fs.existsSync(settingsPath), 'templates/settings.json must exist');
  return JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
}

function loadMain(tailscaleEnabled, settings = loadSettings()) {
  assert.ok(fs.existsSync(templatePath), 'templates/profile.js must exist');
  const template = fs.readFileSync(templatePath, 'utf8');
  const source = template
    .replace('__TAILSCALE_ENABLED__', String(tailscaleEnabled))
    .replace('__SETTINGS__', JSON.stringify(settings));
  const context = {};
  vm.createContext(context);
  vm.runInContext(source, context, { filename: 'profile.js' });
  return context.main;
}

function subscription() {
  return {
    proxies: [
      { name: 'Alpha', type: 'ss', server: '198.51.100.8', port: 443 },
      { name: 'Beta', type: 'trojan', server: 'proxy.example.com', port: 443 },
      { name: 'Gamma', type: 'ss', server: '2001:db8::8', port: 443 }
    ],
    'proxy-groups': [{ name: 'Old Group', type: 'select', proxies: ['Alpha'] }],
    rules: ['MATCH,Old Group'],
    dns: { enable: false },
    tun: { 'route-exclude-address': ['100.64.0.0/10'] }
  };
}

function plain(value) {
  return JSON.parse(JSON.stringify(value));
}

test('base layer rebuilds arbitrary subscriptions and preserves current routing', () => {
  const output = plain(loadMain(false)(subscription(), 'test'));

  assert.equal(output.mode, 'rule');
  assert.equal(output['mixed-port'], 7897);
  assert.equal(output.tun.stack, 'mips');
  assert.equal(output.tun.enable, true);
  assert.equal(output.tun['strict-route'], false);
  assert.equal('route-exclude-address' in output.tun, false);
  assert.deepEqual(output['proxy-groups'], [
    {
      name: '节点选择',
      type: 'select',
      proxies: ['自动选择', 'Alpha', 'Beta', 'Gamma', 'DIRECT']
    },
    {
      name: '自动选择',
      type: 'url-test',
      url: 'https://www.gstatic.com/generate_204',
      interval: 300,
      tolerance: 50,
      proxies: ['Alpha', 'Beta', 'Gamma']
    }
  ]);
  assert.equal(output.rules[0], 'IP-CIDR,198.51.100.8/32,DIRECT,no-resolve');
  assert.equal(output.rules[1], 'DOMAIN,proxy.example.com,DIRECT');
  assert.equal(output.rules[2], 'IP-CIDR6,2001:db8::8/128,DIRECT,no-resolve');
  assert.equal(output.rules.at(-1), 'MATCH,节点选择');
  assert.ok(output.rules.indexOf('GEOSITE,cn,DIRECT') < output.rules.indexOf('GEOSITE,geolocation-!cn,节点选择'));
  assert.ok(output.rules.indexOf('GEOSITE,geolocation-!cn,节点选择') < output.rules.indexOf('GEOIP,CN,DIRECT'));
  assert.ok(output.rules.includes('DOMAIN-SUFFIX,deepseek.com,DIRECT'));
  assert.ok(output.rules.includes('DOMAIN-SUFFIX,gitee.com,DIRECT'));
  assert.equal(output.dns['enhanced-mode'], 'fake-ip');
  assert.deepEqual(output.dns['nameserver-policy']['geosite:cn'], ['223.5.5.5', '119.29.29.29']);
});

test('detected Tailscale stays omitted unless the settings layer is enabled', () => {
  const output = plain(loadMain(true)(subscription(), 'test'));
  const tailscaleRules = output.rules.filter((rule) => /tailscale|100\.64\.0\.0|100\.100\.100\.100|fd7a:115c|41641/i.test(rule));

  assert.deepEqual(tailscaleRules, []);
  assert.equal(output.dns['nameserver-policy']['+.ts.net'], undefined);
  assert.equal(output.dns['fake-ip-filter'].includes('+.ts.net'), false);
  assert.equal(output.dns['fake-ip-filter'].includes('+.tailscale.com'), false);
  assert.equal(output.dns['fake-ip-filter'].includes('+.tailscale.io'), false);
  assert.equal(output.rules.includes('DOMAIN-SUFFIX,tailscale.com,DIRECT'), false);
});

test('Tailscale layer adds transport bypass and MagicDNS without route exclusions', () => {
  const settings = loadSettings();
  settings.tailscale.enabled = true;
  const output = plain(loadMain(true, settings)(subscription(), 'test'));
  const expectedHead = [
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

  assert.deepEqual(output.rules.slice(3, expectedHead.length + 3), expectedHead);
  assert.equal(output.dns['nameserver-policy']['+.ts.net'], '100.100.100.100');
  assert.ok(output.dns['fake-ip-filter'].includes('+.ts.net'));
  assert.ok(output.dns['fake-ip-filter'].includes('+.tailscale.com'));
  assert.ok(output.dns['fake-ip-filter'].includes('+.tailscale.io'));
  assert.equal(output.rules.includes('DOMAIN-SUFFIX,tailscale.com,DIRECT'), false);
  assert.equal('route-exclude-address' in output.tun, false);
});

test('settings can replace defaults and disable the baseline split rules', () => {
  const settings = loadSettings();
  settings.mixedPort = 17897;
  settings.mode = 'global';
  settings.tun.enabled = false;
  settings.tun.stack = 'mixed';
  settings.proxyGroups.selectName = 'Proxy';
  settings.proxyGroups.autoName = 'Auto';
  settings.routing.directProxyServers = false;
  settings.routing.useDefaultSplitRules = false;
  settings.routing.directDomains = ['internal.example.com'];
  settings.routing.proxyDomains = ['external.example.com'];
  settings.routing.prependRules = ['DOMAIN,first.example.com,DIRECT'];
  settings.routing.appendRules = ['DOMAIN,last.example.com,DIRECT'];

  const output = plain(loadMain(false, settings)(subscription(), 'custom'));
  assert.equal(output['mixed-port'], 17897);
  assert.equal(output.mode, 'global');
  assert.equal(output.tun.enable, false);
  assert.equal(output.tun.stack, 'mixed');
  assert.equal(output['proxy-groups'][0].name, 'Proxy');
  assert.equal(output['proxy-groups'][1].name, 'Auto');
  assert.equal(output.rules.includes('IP-CIDR,198.51.100.8/32,DIRECT,no-resolve'), false);
  assert.equal(output.rules.includes('GEOSITE,cn,DIRECT'), false);
  assert.equal(output.rules.includes('DOMAIN-SUFFIX,cn,DIRECT'), false);
  assert.deepEqual(output.rules, [
    'DOMAIN,first.example.com,DIRECT',
    'DOMAIN,internal.example.com,DIRECT',
    'DOMAIN,external.example.com,Proxy',
    'DOMAIN,last.example.com,DIRECT',
    'MATCH,Proxy'
  ]);
  assert.equal(output.dns['nameserver-policy']['geosite:cn'], undefined);
  assert.equal(output.dns['fake-ip-filter'].includes('+.alidns.com'), false);
  assert.equal(output.dns['fake-ip-filter'].includes('+.doh.pub'), false);
});

test('profile enhancement is idempotent', () => {
  const settings = loadSettings();
  settings.tailscale.enabled = true;
  const main = loadMain(true, settings);
  const once = main(subscription(), 'test');
  const snapshot = plain(once);
  const twice = main(once, 'test');

  assert.deepEqual(plain(twice), snapshot);
});

test('provider-only or empty subscriptions fail before producing unusable groups', () => {
  assert.throws(() => loadMain(false)({}, 'test'), /no inline proxies/);
  assert.throws(() => loadMain(false)({ proxies: [] }, 'test'), /no inline proxies/);
});

test('reserved proxy names fail instead of creating ambiguous groups', () => {
  const main = loadMain(false);
  for (const name of ['节点选择', '自动选择', 'DIRECT']) {
    assert.throws(
      () => main({ proxies: [{ name, type: 'ss', server: '198.51.100.40', port: 443 }] }, 'test'),
      /reserved proxy name/
    );
  }
});
