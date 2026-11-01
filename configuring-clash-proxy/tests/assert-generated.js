'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const [file, expected] = process.argv.slice(2);
assert.ok(file, 'generated script path is required');
assert.ok(expected === 'true' || expected === 'false', 'expected Tailscale state must be true or false');

const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(file, 'utf8'), context, { filename: file });
const output = context.main({
  proxies: [{ name: 'Node', type: 'ss', server: '198.51.100.9', port: 443 }]
}, 'installer-test');
const actual = output.rules.includes('IP-CIDR,100.64.0.0/10,DIRECT,no-resolve');
assert.equal(actual, expected === 'true', 'installer must render the detected Tailscale layer');
assert.equal(output['proxy-groups'][0].proxies.includes('Node'), true);
console.log(`generated profile executed with Tailscale=${actual}`);
