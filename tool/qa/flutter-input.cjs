// Use the actual browser editor after Flutter's deferred semantics focus update.
// A DOM focus alone does not mean Flutter has attached its input listeners yet.
async function fillFlutterText(page, box, text) {
  await box.scrollIntoViewIfNeeded();
  await box.focus();
  const frame = () => box.evaluate(() => new Promise(resolve =>
    requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await frame();
  await box.fill(text);
  await frame();
  await page.waitForFunction(expected =>
    [...document.querySelectorAll('input,textarea')].some(e => e.value === expected), text);
}

module.exports = { fillFlutterText };
