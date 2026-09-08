/**
 * Checks the pure helpers inside the reset worker.
 *
 * The endpoints themselves need Cloudflare's runtime, Firebase and EmailJS, so
 * they are exercised against the deployed worker rather than here. What can be
 * tested without any of that is the part most likely to be wrong quietly: the
 * password rules, the address check, and the comparison that decides whether a
 * typed code is right.
 *
 * Run with:  node test/helpers.test.js
 */
const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Lift the helpers out of the module without importing it: the worker exports
// a Cloudflare fetch handler, which Node cannot load on its own.
const source = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'worker.js'),
  'utf8',
);
const helpers = new Function(
  source.slice(source.indexOf('function passwordProblem')) +
    '; return { passwordProblem, normaliseEmail, timingSafeEqual };',
)();

const { passwordProblem, normaliseEmail, timingSafeEqual } = helpers;

let run = 0;
function check(name, fn) {
  fn();
  run++;
  console.log('  ok  ' + name);
}

console.log('password rules');
check('too short is rejected on length first', () =>
  assert.match(passwordProblem('Ab1!'), /at least 8/),
);
check('missing uppercase is named', () =>
  assert.match(passwordProblem('learn1a!'), /uppercase/),
);
check('missing number is named', () =>
  assert.match(passwordProblem('Learnova!'), /number/),
);
check('missing symbol is named', () =>
  assert.match(passwordProblem('Learnova1'), /special symbol/),
);
check('eight valid characters pass', () =>
  assert.strictEqual(passwordProblem('Learn1a!'), null),
);
check('the rules match the Register screen', () =>
  assert.strictEqual(passwordProblem('Learnova#2026'), null),
);

console.log('email');
check('trimmed and lowercased', () =>
  assert.strictEqual(normaliseEmail('  Test@Mail.COM '), 'test@mail.com'),
);
check('rubbish is rejected', () => {
  assert.strictEqual(normaliseEmail('not-an-email'), null);
  assert.strictEqual(normaliseEmail('a@b'), null);
  assert.strictEqual(normaliseEmail(''), null);
  assert.strictEqual(normaliseEmail(undefined), null);
});

console.log('code comparison');
check('equal codes match', () =>
  assert.strictEqual(timingSafeEqual('123456', '123456'), true),
);
check('one wrong digit does not', () =>
  assert.strictEqual(timingSafeEqual('123456', '123457'), false),
);
check('a shorter guess does not', () =>
  assert.strictEqual(timingSafeEqual('12345', '123456'), false),
);
check('numbers and strings compare alike', () =>
  assert.strictEqual(timingSafeEqual(123456, '123456'), true),
);

console.log('\n' + run + ' checks passed.');
