'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const templatePath = path.join(__dirname, '..', 'templates', 'profile.js');

function loadMain(tailscaleEnabled) {
  assert.ok(fs.existsSync(templatePath), 'templates/profile.js must exist');
  const template = fs.readFileSync(templatePath, 'utf8');
  const source = template.replace('__TAILSCALE_ENABLED__', String(tailscaleEnabled));
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
  assert.equal(output.rules[1], 'IP-CIDR6,2001:db8::8/128,DIRECT,no-resolve');
  assert.equal(output.rules.at(-1), 'MATCH,节点选择');
  assert.ok(output.rules.indexOf('GEOSITE,cn,DIRECT') < output.rules.indexOf('GEOSITE,geolocation-!cn,节点选择'));
  assert.ok(output.rules.indexOf('GEOSITE,geolocation-!cn,节点选择') < output.rules.indexOf('GEOIP,CN,DIRECT'));
  assert.ok(output.rules.includes('DOMAIN-SUFFIX,deepseek.com,DIRECT'));
  assert.ok(output.rules.includes('DOMAIN-SUFFIX,gitee.com,DIRECT'));
  assert.equal(output.dns['enhanced-mode'], 'fake-ip');
  assert.deepEqual(output.dns['nameserver-policy']['geosite:cn'], ['223.5.5.5', '119.29.29.29']);
});

test('base layer omits every Tailscale rule and DNS override', () => {
  const output = plain(loadMain(false)(subscription(), 'test'));
  const tailscaleRules = output.rules.filter((rule) => /tailscale|100\.64\.0\.0|100\.100\.100\.100|fd7a:115c|41641/i.test(rule));

  assert.deepEqual(tailscaleRules, []);
  assert.equal(output.dns['nameserver-policy']['+.ts.net'], undefined);
  assert.equal(output.dns['fake-ip-filter'].includes('+.ts.net'), false);
  assert.equal(output.dns['fake-ip-filter'].includes('+.tailscale.com'), false);
  assert.equal(output.dns['fake-ip-filter'].includes('+.tailscale.io'), false);
  assert.equal(output.rules.includes('DOMAIN-SUFFIX,tailscale.com,DIRECT'), false);
});

test('Tailscale layer adds transport bypass and MagicDNS without route exclusions', () => {
  const output = plain(loadMain(true)(subscription(), 'test'));
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

  assert.deepEqual(output.rules.slice(2, expectedHead.length + 2), expectedHead);
  assert.equal(output.dns['nameserver-policy']['+.ts.net'], '100.100.100.100');
  assert.ok(output.dns['fake-ip-filter'].includes('+.ts.net'));
  assert.ok(output.dns['fake-ip-filter'].includes('+.tailscale.com'));
  assert.ok(output.dns['fake-ip-filter'].includes('+.tailscale.io'));
  assert.equal(output.rules.includes('DOMAIN-SUFFIX,tailscale.com,DIRECT'), false);
  assert.equal('route-exclude-address' in output.tun, false);
});

test('profile enhancement is idempotent', () => {
  const main = loadMain(true);
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
