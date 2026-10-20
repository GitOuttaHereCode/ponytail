// Pure math for the landlord app. Loaded by index.html and by calc.test.js.
// kind: income | opex (counts against NOI) | debt (debt service) | capex (depreciated, not NOI)
const CATEGORIES = [
  ['Rent', 'income', ''], ['Late fees', 'income', ''], ['Laundry / parking / other income', 'income', ''],
  ['Advertising', 'opex', 'Sch E line 5'], ['Auto & travel', 'opex', 'Sch E line 6'],
  ['Cleaning & maintenance (lawn, snow, turnover)', 'opex', 'Sch E line 7'], ['Commissions / leasing fees', 'opex', 'Sch E line 8'],
  ['Insurance', 'opex', 'Sch E line 9'], ['Legal & professional', 'opex', 'Sch E line 10'],
  ['Property management', 'opex', 'Sch E line 11'], ['Repairs', 'opex', 'Sch E line 14'],
  ['Supplies', 'opex', 'Sch E line 15'], ['Property tax', 'opex', 'Sch E line 16'],
  ['Utilities: Water / sewer', 'opex', 'Sch E line 17'], ['Utilities: Electric', 'opex', 'Sch E line 17'],
  ['Utilities: Gas / heating oil', 'opex', 'Sch E line 17'], ['Utilities: Trash', 'opex', 'Sch E line 17'],
  ['Utilities: Internet / cable', 'opex', 'Sch E line 17'], ['HOA / condo fees', 'opex', 'Sch E line 19'],
  ['Pest control', 'opex', 'Sch E line 19'], ['Other expense', 'opex', 'Sch E line 19'],
  ['Mortgage interest', 'debt', 'Sch E line 12'], ['Mortgage principal', 'debt', 'not deductible'],
  ['Capital improvement (roof, HVAC, appliances)', 'capex', 'depreciate (Form 4562)'],
];
const KIND = Object.fromEntries(CATEGORIES.map(([c, k]) => [c, k]));

const iso = (d) => d.toISOString().slice(0, 10);
const daysBetween = (a, b) => Math.round((new Date(b) - new Date(a)) / 864e5);

// Trailing-12-month numbers for one property (or all when propertyId is falsy).
function summarize(data, propertyId, today = new Date()) {
  const from = new Date(today); from.setFullYear(from.getFullYear() - 1);
  const s = { income: 0, opex: 0, debt: 0, capex: 0, byCategory: {} };
  for (const t of data.transactions) {
    if (propertyId && t.propertyId !== propertyId) continue;
    if (t.date <= iso(from) || t.date > iso(today)) continue;
    const kind = KIND[t.category] || 'opex', amt = Number(t.amount) || 0;
    s[kind] += amt;
    s.byCategory[t.category] = (s.byCategory[t.category] || 0) + amt;
  }
  const props = data.properties.filter((p) => !propertyId || p.id === propertyId);
  const value = props.reduce((a, p) => a + (Number(p.marketValue) || 0), 0);
  const loans = props.reduce((a, p) => a + (Number(p.loanBalance) || 0), 0);
  s.noi = s.income - s.opex;
  s.cashFlow = s.noi - s.debt - s.capex;
  s.capRate = value ? s.noi / value : null;
  s.expenseRatio = s.income ? s.opex / s.income : null;
  s.equity = value - loans;
  s.value = value;
  return s;
}

const isActive = (t, today) => !t.leaseEnd || t.leaseEnd >= iso(today) || t.monthToMonth === 'yes';

// Things that need attention, most urgent first-ish.
function alerts(data, today = new Date()) {
  const out = [], now = iso(today), month = now.slice(0, 7);
  const name = (id) => (data.properties.find((p) => p.id === id) || {}).name || 'Unknown property';
  for (const p of data.properties) {
    const occupied = data.tenants.filter((t) => t.propertyId === p.id && isActive(t, today)).length;
    if (occupied < Number(p.units)) out.push(`${p.name}: ${p.units - occupied} vacant unit(s). Every vacant month costs you a full month's rent.`);
    const last = (p.valueHistory || []).at(-1);
    if (!last || daysBetween(last.date, now) > 90) out.push(`${p.name}: market value not updated in 90+ days.`);
  }
  for (const t of data.tenants) {
    if (!isActive(t, today)) continue;
    const left = t.leaseEnd ? daysBetween(now, t.leaseEnd) : null;
    if (left !== null && left <= 60 && left >= 0) out.push(`${t.name} (${name(t.propertyId)} ${t.unit || ''}): lease ends in ${left} days. Send a renewal offer.`);
    if (left !== null && left < 0) out.push(`${t.name}: lease expired, now month-to-month. Get a new lease signed.`);
    const paid = data.transactions.some((x) => x.tenantId === t.id && x.category === 'Rent' && x.date.startsWith(month));
    if (!paid && Number(now.slice(8)) > 5) out.push(`${t.name}: no rent logged for ${month} yet.`);
  }
  for (const m of data.maintenance) {
    if (m.status !== 'done' && daysBetween(m.date, now) > 7) out.push(`Open ${daysBetween(m.date, now)} days: ${m.issue} (${name(m.propertyId)}).`);
  }
  for (const c of data.contractors) {
    if (c.insuranceExpires && daysBetween(now, c.insuranceExpires) < 30) out.push(`${c.name}: insurance ${c.insuranceExpires < now ? 'EXPIRED' : 'expires soon'} (${c.insuranceExpires}). Get a new certificate before hiring.`);
  }
  for (const p of data.properties) {
    const s = summarize(data, p.id, today);
    if (s.expenseRatio > 0.5) out.push(`${p.name}: expenses are ${Math.round(s.expenseRatio * 100)}% of income (healthy is under 50%). Check the breakdown.`);
  }
  return out;
}

const TIPS = [
  'Raise rent a little every renewal (2-4%) instead of a big jump every few years. Tenants accept small steady bumps and you avoid turnover, which often costs 1-2 months of rent.',
  'Collect rent online (Zelle, Venmo business, or a free portal like Baselane or TurboTenant). Late payments drop when paying is one tap.',
  'Shop your landlord insurance policy once a year. Quotes for the same coverage can differ by hundreds of dollars.',
  'Check your property tax assessment. If it is above what the place would actually sell for, appeal it. Most counties have a free process and a deadline.',
  'Change HVAC filters every 1-3 months. A $10 filter can prevent a $5,000 furnace replacement.',
  'Bill back utilities with a RUBS formula or submeters if tenants do not pay their own water. Water is often the biggest hidden cost in 2-4 unit buildings.',
  'Keep a separate bank account for each property (or at least for rentals). It makes Schedule E a 20-minute job.',
  'Do a walkthrough every 6 months with a checklist and photos. Small leaks found early are cheap; found late they are mold.',
  'Get every contractor\'s certificate of insurance before they start. If an uninsured worker gets hurt on your property, it can land on you.',
  'Build a capital reserve: set aside 5-10% of rent each month for roofs, water heaters and appliances so a big repair does not wreck a year.',
  'Screen tenants on the same written criteria every time (income 3x rent, credit, rental history). Consistency keeps you fair-housing compliant.',
  'Install LED bulbs and low-flow showerheads in common areas and units where you pay utilities. Cheap and pays back within a year.',
  'Send renewal offers 60-90 days before leases end. A renewed tenant costs nothing; a vacancy costs rent, cleaning and advertising.',
  'Track your mileage to properties. The IRS standard mileage rate is deductible on Schedule E line 6.',
  'Separate repairs (deduct now) from improvements (depreciate over 27.5 years). Ask your CPA about the de minimis safe harbor for items under $2,500.',
  'Flush the water heater once a year to clear sediment. It extends its life by years.',
  'Clean gutters every fall and spring. Overflowing gutters cause foundation and basement water problems.',
  'Test smoke and CO detectors twice a year and write down the date. It protects tenants and protects you legally.',
  'Have a go-to backup for each trade (plumber, electrician, HVAC). When your main person is booked, an emergency becomes expensive fast.',
  'Look at your rent vs. the neighborhood on Zillow, Rentometer or Craigslist. Being 10% under market on 4 units is real money every month.',
  'Require renters insurance in the lease. It is cheap for the tenant and keeps their belongings claims off your policy.',
  'Refinance check: if rates have dropped about 1% below your mortgage rate, run the numbers on a refi.',
  'Winterize before the first freeze: disconnect hoses, insulate exposed pipes, and tell tenants to keep heat at least 55F.',
  'Keep digital copies of leases, receipts and invoices for at least 7 years. Snap a photo of every receipt the day you get it.',
  'Add a small amenity that tenants pay for: storage, a parking spot, coin laundry. $25/month across 4 units is $1,200/year.',
  'Review your expense breakdown for the biggest category and ask how to cut it 10%. That is usually where the easy money is.',
  'Know your local landlord-tenant rules on security deposits (limits, interest, return deadlines). Missing a deadline can cost you double the deposit in some states.',
  'Cap rate check: if your cap rate is way below what similar buildings sell at, your rent is low or your expenses are high. Find which.',
  'Consider a property manager quote even if you self-manage. Knowing what your time is worth (usually 8-10% of rent) helps you decide.',
  'Schedule boiler/furnace service every fall. Tune-ups are cheaper than no-heat emergency calls in January.',
];

// ISO-ish week number so the tip changes every Monday.
function weekNumber(d = new Date()) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 864e5 + 1) / 7);
}
const weeklyTip = (d = new Date()) => TIPS[(d.getFullYear() * 53 + weekNumber(d)) % TIPS.length];

if (typeof module !== 'undefined') module.exports = { CATEGORIES, summarize, alerts, weeklyTip, weekNumber, isActive };
