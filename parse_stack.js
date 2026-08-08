const fs = require('fs');
const { SourceMapConsumer } = require('source-map');

const rawSourceMap = fs.readFileSync('build/web/main.dart.js.map', 'utf8');

SourceMapConsumer.with(rawSourceMap, null, consumer => {
  console.log("6574:", consumer.originalPositionFor({line: 6574, column: 3}));
  console.log("42988:", consumer.originalPositionFor({line: 42988, column: 8}));
  console.log("5461:", consumer.originalPositionFor({line: 5461, column: 5}));
  console.log("5463:", consumer.originalPositionFor({line: 5463, column: 7}));
  console.log("41868:", consumer.originalPositionFor({line: 41868, column: 3}));
});
