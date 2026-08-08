const fs = require('fs');
const sourceMap = require('source-map');
(async () => {
    const rawSourceMap = fs.readFileSync('build/web/main.dart.js.map', 'utf8');
    const consumer = await new sourceMap.SourceMapConsumer(rawSourceMap);
    for (let c = 1; c <= 200; c += 1) {
        const pos = consumer.originalPositionFor({ line: 6437, column: c });
        if (pos.source && !pos.source.includes('core_patch')) {
            console.log(`Column ${c}: ${pos.source}:${pos.line}:${pos.column}`);
        }
    }
    console.log("Done checking 6437");
    
    // Check surrounding lines just in case
    for(let l = 6430; l <= 6450; l++) {
      for(let c = 1; c <= 200; c += 10) {
          const pos = consumer.originalPositionFor({ line: l, column: c });
          if (pos.source && pos.source.includes('lib/')) {
              console.log(`Line ${l} Column ${c}: ${pos.source}:${pos.line}:${pos.column}`);
          }
      }
    }
})();
