const puppeteer = require('puppeteer');
const fs = require('fs');
const sourceMap = require('source-map');

(async () => {
  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();
  
  let rawStack = null;
  
  await page.evaluateOnNewDocument(() => {
    const origError = console.error;
    console.error = function(...args) {
      origError.apply(console, ["CAUGHT_IN_BROWSER", ...args]);
    };
    window.addEventListener('unhandledrejection', event => {
      console.error("UNHANDLED", event.reason?.stack || event.reason);
    });
    window.addEventListener('error', event => {
      console.error("ERROR", event.error?.stack || event.message || event.error);
    });
  });

  page.on('console', msg => {
    console.log('[BROWSER CONSOLE]', msg.type(), msg.text());
    if (msg.text().includes('CAUGHT_IN_BROWSER')) {
      rawStack = msg.text().replace('CAUGHT_IN_BROWSER ', '');
    }
  });

  try {
    console.log("Navigating to http://localhost:3000/ ...");
    await page.goto('http://localhost:3000/', { waitUntil: 'networkidle0', timeout: 5000 });
    
    // Inject fake token and reload
    await page.evaluate(() => {
      localStorage.setItem('flutter.auth_token', '"fake_token"');
    });
    console.log("Injected fake token, reloading...");
    await page.reload({ waitUntil: 'networkidle0', timeout: 5000 });

    await new Promise(r => setTimeout(r, 2000));
    
    if (rawStack) {
      console.log("Found Raw Stack Trace!");
      console.log(rawStack);
      try {
        const rawSourceMap = fs.readFileSync('build/web/main.dart.js.map', 'utf8');
        const consumer = await new sourceMap.SourceMapConsumer(rawSourceMap);
        
        const lines = rawStack.split('\n');
        console.log("\n--- MAPPED STACK TRACE ---");
        for (const line of lines) {
          const match = line.match(/main\.dart\.js:(\d+):(\d+)/);
          if (match) {
            const l = parseInt(match[1]);
            const c = parseInt(match[2]);
            const pos = consumer.originalPositionFor({ line: l, column: c });
            if (pos.source && !pos.source.includes('core_patch')) {
               console.log(`[Dart] ${pos.source}:${pos.line}:${pos.column} (${pos.name || ''})`);
            }
          }
        }
        console.log("--------------------------\n");
      } catch (e) {
        console.log("Could not map stack trace (no source map).", e.message);
      }
    } else {
      console.log("No unhandled rejection caught by script.");
    }
    
  } catch (e) {
    console.error('Error in script:', e);
  } finally {
    await browser.close();
  }
})();
