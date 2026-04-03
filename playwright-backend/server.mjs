/**
 * Sophos Central Playwright Backend
 * 
 * REST API that uses a saved browser session to perform actions
 * on Sophos Central that the API doesn't support.
 * 
 * Port: 18870
 * Auth: X-Playwright-Secret header
 */

import express from 'express';
import { chromium } from 'playwright';
import { existsSync, readFileSync } from 'fs';

const PORT = process.env.PORT || 18870;
const STATE_PATH = './state/sophos-session.json';
const SECRET = process.env.PLAYWRIGHT_SECRET || 'sophos-pw-2026';
const CENTRAL_URL = 'https://cloud.sophos.com';

const app = express();
app.use(express.json());

// ── Auth middleware ──────────────────────────────────────────────────────
function auth(req, res, next) {
  if (req.path === '/health') return next();
  const provided = req.headers['x-playwright-secret'];
  if (provided !== SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}
app.use(auth);

// ── Browser management ──────────────────────────────────────────────────
let browser = null;
let context = null;

async function getContext() {
  if (context) return context;
  
  if (!existsSync(STATE_PATH)) {
    throw new Error('No saved session. Run: node login.mjs');
  }

  browser = await chromium.launch({  
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  
  context = await browser.newContext({
    storageState: STATE_PATH,
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    viewport: { width: 1440, height: 900 },
  });

  console.log('🌐 Browser context created with saved session');
  return context;
}

async function getPage(url) {
  const ctx = await getContext();
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  
  // Check if we got redirected to login (session expired)
  if (page.url().includes('login') || page.url().includes('auth')) {
    await page.close();
    throw new Error('Session expired. Run: node login.mjs to re-authenticate.');
  }
  
  // Sophos Central is a heavy SPA — wait for the main content to render
  try {
    await page.waitForSelector('.main-content, .dashboard, [class*="content"], [data-testid], nav, .sidebar, table, .card', { timeout: 20000 });
  } catch {
    // Fallback: just wait a fixed time for the SPA to hydrate
  }
  await page.waitForTimeout(5000);
  
  return page;
}

// ── Health ───────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  const hasSession = existsSync(STATE_PATH);
  res.json({ 
    ok: true, 
    service: 'sophos-playwright',
    port: PORT,
    session: hasSession ? 'saved' : 'missing',
    browser: browser ? 'running' : 'stopped',
  });
});

// ── Session status ───────────────────────────────────────────────────────
app.get('/api/session/status', async (req, res) => {
  try {
    if (!existsSync(STATE_PATH)) {
      return res.json({ ok: false, status: 'no_session', message: 'Run node login.mjs' });
    }
    const page = await getPage(CENTRAL_URL);
    const url = page.url();
    const title = await page.title();
    await page.close();
    
    const loggedIn = !url.includes('login') && !url.includes('auth');
    res.json({ ok: loggedIn, status: loggedIn ? 'active' : 'expired', url, title });
  } catch (err) {
    res.json({ ok: false, status: 'error', message: err.message });
  }
});

// ── Screenshot (debug) ───────────────────────────────────────────────────
app.post('/api/screenshot', async (req, res) => {
  try {
    const url = req.body.url || CENTRAL_URL;
    const page = await getPage(url);
    const buffer = await page.screenshot({ fullPage: req.body.fullPage || false });
    await page.close();
    res.set('Content-Type', 'image/png');
    res.send(buffer);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Live Discover ────────────────────────────────────────────────────────
app.post('/api/live-discover', async (req, res) => {
  try {
    const { query, description } = req.body;
    if (!query) return res.status(400).json({ error: 'query required' });
    
    const page = await getPage(`${CENTRAL_URL}/#/threat-analysis/live-discover/create`);
    
    // Wait for the query editor to load
    await page.waitForSelector('[data-testid="query-editor"], .ace_editor, textarea', { timeout: 15000 });
    
    // Try to input the query
    const editor = await page.$('[data-testid="query-editor"] textarea, .ace_editor textarea, textarea.query-input');
    if (editor) {
      await editor.fill(query);
    } else {
      // Try clicking the editor area and typing
      const editorArea = await page.$('.ace_editor, [data-testid="query-editor"]');
      if (editorArea) {
        await editorArea.click();
        await page.keyboard.type(query);
      }
    }
    
    // Click run
    const runButton = await page.$('button:has-text("Run"), button:has-text("Execute"), [data-testid="run-query"]');
    if (runButton) {
      await runButton.click();
      
      // Wait for results
      await page.waitForSelector('[data-testid="query-results"], .results-table, table', { timeout: 60000 });
      await page.waitForTimeout(2000); // Let results fully render
      
      // Extract results
      const results = await page.evaluate(() => {
        const table = document.querySelector('[data-testid="query-results"] table, .results-table table, table');
        if (!table) return { rows: [], columns: [] };
        
        const headers = Array.from(table.querySelectorAll('th')).map(th => th.textContent.trim());
        const rows = Array.from(table.querySelectorAll('tbody tr')).map(tr => {
          const cells = Array.from(tr.querySelectorAll('td')).map(td => td.textContent.trim());
          return Object.fromEntries(headers.map((h, i) => [h, cells[i] || '']));
        });
        
        return { columns: headers, rows, count: rows.length };
      });
      
      await page.close();
      res.json({ ok: true, query, results });
    } else {
      await page.close();
      res.status(500).json({ error: 'Could not find run button' });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Threat Graph / Attack Chain ──────────────────────────────────────────
app.post('/api/threat-graph', async (req, res) => {
  try {
    const { caseId, alertId } = req.body;
    if (!caseId && !alertId) return res.status(400).json({ error: 'caseId or alertId required' });
    
    const path = caseId 
      ? `/#/cases/${caseId}` 
      : `/#/threat-analysis/alerts/${alertId}`;
    
    const page = await getPage(`${CENTRAL_URL}${path}`);
    await page.waitForTimeout(3000); // Let the page fully render
    
    // Take a screenshot of the threat graph area
    const screenshot = await page.screenshot({ fullPage: true });
    
    // Try to extract text content from the page
    const content = await page.evaluate(() => {
      const body = document.body.innerText;
      return body.substring(0, 5000);
    });
    
    await page.close();
    
    res.json({ 
      ok: true, 
      content,
      screenshotBase64: screenshot.toString('base64'),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Policy List ──────────────────────────────────────────────────────────
app.get('/api/policies', async (req, res) => {
  try {
    const page = await getPage(`${CENTRAL_URL}/manage/endpoint-protection/policies`);
    await page.waitForTimeout(5000);
    
    const policies = await page.evaluate(() => {
      const rows = document.querySelectorAll('table tbody tr, [data-testid="policy-row"]');
      return Array.from(rows).map(row => {
        const cells = Array.from(row.querySelectorAll('td'));
        return {
          name: cells[0]?.textContent?.trim() || '',
          type: cells[1]?.textContent?.trim() || '',
          status: cells[2]?.textContent?.trim() || '',
        };
      }).filter(p => p.name);
    });
    
    await page.close();
    res.json({ ok: true, policies, count: policies.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── Graceful shutdown ────────────────────────────────────────────────────
async function shutdown() {
  console.log('Shutting down...');
  if (browser) await browser.close();
  process.exit(0);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

// ── Start ────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  const hasSession = existsSync(STATE_PATH);
  console.log(`🎭 Sophos Central Playwright Backend`);
  console.log(`   Port: ${PORT}`);
  console.log(`   Session: ${hasSession ? '✅ saved' : '❌ missing — run: node login.mjs'}`);
  console.log(`   Endpoints:`);
  console.log(`     GET  /health`);
  console.log(`     GET  /api/session/status`);
  console.log(`     POST /api/screenshot`);
  console.log(`     POST /api/live-discover`);
  console.log(`     POST /api/threat-graph`);
  console.log(`     GET  /api/policies`);
});
