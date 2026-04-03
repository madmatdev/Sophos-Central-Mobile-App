/**
 * Manual Login Script (Docker version)
 * 
 * Opens a visible Chrome browser (via Xvfb + VNC).
 * User logs in with 2FA via noVNC in their browser.
 * Session state saved to /app/state/sophos-session.json.
 */

import { chromium } from 'playwright';
import { createInterface } from 'readline';

const STATE_PATH = process.env.STATE_PATH || './state/sophos-session.json';
const CENTRAL_URL = 'https://cloud.sophos.com';

async function main() {
  console.log('🔐 Opening Sophos Central login in Chrome...');
  console.log('   Use the noVNC window (http://localhost:6080) to interact.');
  console.log('   Press Enter here when you see the Sophos Central dashboard.\n');

  const browser = await chromium.launch({
    headless: false,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
    ],
  });

  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    viewport: { width: 1440, height: 900 },
  });

  const page = await context.newPage();
  await page.goto(CENTRAL_URL, { waitUntil: 'domcontentloaded' });

  // Wait for user to complete login
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  await new Promise(resolve => rl.question('Press Enter after login is complete... ', resolve));
  rl.close();

  // Save session state
  await context.storageState({ path: STATE_PATH });
  console.log(`\n✅ Session saved to ${STATE_PATH}`);
  console.log(`   Current URL: ${page.url()}`);

  await browser.close();
}

main().catch(err => {
  console.error('❌', err.message);
  process.exit(1);
});
