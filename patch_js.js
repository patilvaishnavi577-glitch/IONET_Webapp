const fs = require('fs');
let code = fs.readFileSync('build/web/main.dart.js', 'utf8');
code = code.replace('throw A.i(A.c5("Invalid double",a,null))}', 'console.error("CRASH VALUE:", a); throw A.i(A.c5("Invalid double",a,null))}');
fs.writeFileSync('build/web/main.dart.js', code);
