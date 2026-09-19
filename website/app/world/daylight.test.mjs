import { test } from "node:test";
import assert from "node:assert/strict";

// The module under test is TypeScript; Node strips the types itself.
const { daylightAt, mixColour, phaseForHour, phaseFromScroll, STOPS } = await import("./daylight.ts");

test("the day always ends at night, whatever hour the visitor arrives", () => {
  for (let hour = 0; hour < 24; hour++) {
    const end = phaseFromScroll(phaseForHour(hour), 1);
    assert.equal(end, 1, `arriving at ${hour}:00 should end the page at night, got ${end}`);
  }
});

test("scrolling never runs the day backwards", () => {
  for (let hour = 0; hour < 24; hour += 3) {
    const start = phaseForHour(hour);
    let previous = -1;
    for (let s = 0; s <= 1.0001; s += 0.05) {
      const p = phaseFromScroll(start, s);
      assert.ok(p >= previous, `hour ${hour} went backwards at scroll ${s}`);
      previous = p;
    }
  }
});

test("an evening arrival does not land back in the morning", () => {
  // The bug this guards: wrapping past 1.0 put a 9pm visitor under bright
  // morning light at the foot of a page whose closing line is about night.
  const nineThirtyPm = phaseForHour(21);
  const atFoot = phaseFromScroll(nineThirtyPm, 1);
  assert.ok(atFoot >= nineThirtyPm, "the day must not travel backwards overnight");
  assert.equal(daylightAt(atFoot).key, "night");
});

test("every hour maps somewhere on the day, in order through waking hours", () => {
  for (let hour = 0; hour < 24; hour++) {
    const p = phaseForHour(hour);
    assert.ok(p >= 0 && p <= 1, `hour ${hour} produced ${p}`);
  }
  // 6am is earlier in the day than noon, which is earlier than 6pm.
  assert.ok(phaseForHour(6) < phaseForHour(12));
  assert.ok(phaseForHour(12) < phaseForHour(18));
});

test("nobody arrives in the darkest frame the site has", () => {
  // Landing at pitch night leaves no journey and no first impression. Even the
  // small hours open a little short of the end.
  for (let hour = 0; hour < 24; hour++) {
    assert.ok(phaseForHour(hour) < 1, `hour ${hour} opens at the very end of the day`);
  }
});

test("night stays readable rather than going black", () => {
  const night = STOPS[STOPS.length - 1];
  const brightness = (hex) =>
    (parseInt(hex.slice(1, 3), 16) + parseInt(hex.slice(3, 5), 16) + parseInt(hex.slice(5, 7), 16)) / 3;
  assert.ok(brightness(night.skyTop) > 24, "night sky must not be effectively black");
  assert.ok(night.fillIntensity > 0.5, "night needs enough fill to read the foreground");
});

test("colour mixing hits both ends exactly", () => {
  assert.equal(mixColour("#000000", "#ffffff", 0), "#000000");
  assert.equal(mixColour("#000000", "#ffffff", 1), "#ffffff");
  assert.equal(mixColour("#000000", "#ffffff", 0.5), "#808080");
});

test("daylight is continuous across every stop boundary", () => {
  // A visible jump in the sky as you scroll past a stop would look like a bug.
  for (const stop of STOPS.slice(1, -1)) {
    const before = daylightAt(stop.at - 0.001);
    const after = daylightAt(stop.at + 0.001);
    const gap = (a, b) =>
      Math.abs(parseInt(a.slice(1, 3), 16) - parseInt(b.slice(1, 3), 16));
    assert.ok(gap(before.skyTop, after.skyTop) < 6, `sky jumps at ${stop.key}`);
    assert.ok(Math.abs(before.sunIntensity - after.sunIntensity) < 0.05, `sun jumps at ${stop.key}`);
  }
});

test("phase is clamped, so a rubber-band scroll cannot break the sky", () => {
  assert.equal(daylightAt(-3).at, 0);
  assert.equal(daylightAt(9).at, 1);
  assert.equal(phaseFromScroll(0.5, -2), 0.5);
  assert.equal(phaseFromScroll(0.5, 9), 1);
});
