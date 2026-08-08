const fs = require('fs');
let code = fs.readFileSync('build/web/main.dart.js', 'utf8');
const searchString = 'a.stack=b.k(0)\nthrow a},';
const replaceString = 'a.stack=b.k(0)\nconsole.error("REAL CRASH ERROR:", a)\nthrow a},';
if(code.includes(searchString)) {
    code = code.replace(searchString, replaceString);
    fs.writeFileSync('build/web/main.dart.js', code);
    console.log("Patched successfully!");
} else {
    console.log("Search string not found!");
}
