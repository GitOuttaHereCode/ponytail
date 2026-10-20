const test = require('node:test');
const assert = require('node:assert/strict');
const { summarize, alerts, weeklyTip } = require('./calc.js');

const today = new Date('2026-10-20T12:00:00');
const data = {
  properties: [{ id: 'p1', name: 'Duplex', units: '2', marketValue: '300000', loanBalance: '200000', valueHistory: [{ date: '2026-10-01', value: 300000 }] }],
  tenants: [{ id: 't1', propertyId: 'p1', name: 'Ann', rent: '1500', leaseEnd: '2026-11-30' }],
  transactions: [
    { propertyId: 'p1', date: '2026-10-01', category: 'Rent', amount: '24000', tenantId: 't1' },
    { propertyId: 'p1', date: '2026-05-01', category: 'Property tax', amount: '4000' },
    { propertyId: 'p1', date: '2026-06-01', category: 'Utilities: Water / sewer', amount: '1000' },
    { propertyId: 'p1', date: '2026-07-01', category: 'Mortgage interest', amount: '9000' },
    { propertyId: 'p1', date: '2026-08-01', category: 'Capital improvement (roof, HVAC, appliances)', amount: '3000' },
    { propertyId: 'p1', date: '2025-01-01', category: 'Repairs', amount: '99999' }, // older than 12 months
  ],
  maintenance: [{ propertyId: 'p1', date: '2026-10-01', issue: 'Leaky faucet', status: 'open' }],
  contractors: [{ name: 'Bob Plumbing', insuranceExpires: '2026-09-01' }],
};

test('T12 summary splits opex, debt and capex', () => {
  const s = summarize(data, 'p1', today);
  assert.equal(s.income, 24000);
  assert.equal(s.opex, 5000);
  assert.equal(s.noi, 19000);
  assert.equal(s.cashFlow, 19000 - 9000 - 3000);
  assert.equal(s.capRate, 19000 / 300000);
  assert.equal(s.equity, 100000);
});

test('alerts catch vacancy, lease ending, stale ticket, expired insurance', () => {
  const a = alerts(data, today).join('\n');
  assert.match(a, /1 vacant unit/);
  assert.match(a, /lease ends in 41 days/);
  assert.match(a, /Open 19 days: Leaky faucet/);
  assert.match(a, /Bob Plumbing: insurance EXPIRED/);
  assert.doesNotMatch(a, /no rent logged/);
  assert.doesNotMatch(a, /market value not updated/);
});

test('tip changes week to week', () => {
  assert.notEqual(weeklyTip(new Date('2026-10-20')), weeklyTip(new Date('2026-10-27')));
  assert.equal(weeklyTip(new Date('2026-10-19')), weeklyTip(new Date('2026-10-25')));
});
