const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();

  page.on('console', msg => console.log('CONSOLE LOG:', msg.text()));
  page.on('pageerror', err => {
    console.log('PAGE ERROR STR:', err.toString());
    console.log('PAGE ERROR STACK:', err.stack);
  });
  page.on('requestfailed', request => {
    console.log('REQUEST FAILED:', request.url(), request.failure().errorText);
  });

  // To catch unhandled rejections
  await page.evaluateOnNewDocument(() => {
    window.addEventListener('unhandledrejection', event => {
      console.log('UNHANDLED REJECTION:', event.reason?.message || event.reason);
      console.log('UNHANDLED REJECTION STACK:', event.reason?.stack);
    });
    window.addEventListener('error', event => {
      console.log('WINDOW ERROR:', event.error?.message || event.message);
      console.log('WINDOW ERROR STACK:', event.error?.stack);
    });
  });

  try {
    console.log("Navigating to http://localhost:3000/#/");
    await page.goto('http://localhost:3000/#/', { waitUntil: 'networkidle2', timeout: 30000 });
    console.log("Waiting 3s for any delayed errors...");
    await new Promise(r => setTimeout(r, 3000));
  } catch (e) {
    console.error('Navigation error:', e);
  } finally {
    await browser.close();
  }
})();
