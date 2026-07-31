const fs = require('fs');
const content = fs.readFileSync('functions/src/index.ts', 'utf8');

const lines = content.split('\n');
let newLines = [];
let addedHelper = false;
let inMultilineExport = false;
let multilineBuffer = '';

for (let line of lines) {
  if (!addedHelper && (line.startsWith('export {') || line.trim() === 'export {')) {
    newLines.push('const functionName = process.env.FUNCTION_TARGET || process.env.K_SERVICE;');
    newLines.push('function lazyExport(modulePath: string, exportsList: string[]) {');
    newLines.push('  exportsList.forEach((name) => {');
    newLines.push('    if (!functionName || functionName === name) {');
    newLines.push('      exports[name] = require(modulePath)[name];');
    newLines.push('    }');
    newLines.push('  });');
    newLines.push('}');
    newLines.push('');
    addedHelper = true;
  }

  if (inMultilineExport) {
    multilineBuffer += ' ' + line.trim();
    if (line.includes('} from')) {
      inMultilineExport = false;
      const match = multilineBuffer.match(/export\s*\{\s*([^}]+)\s*\}\s*from\s*["']([^"']+)["']/);
      if (match) {
        const exportsStr = match[1];
        const modulePath = match[2];
        const exportsList = exportsStr.split(',').map(s => s.trim()).filter(s => s.length > 0);
        newLines.push(`lazyExport('${modulePath}', [${exportsList.map(e => `'${e}'`).join(', ')}]);`);
      }
      multilineBuffer = '';
    }
  } else if (line.trim() === 'export {') {
    inMultilineExport = true;
    multilineBuffer = line.trim();
  } else if (line.startsWith('export {')) {
    if (line.includes('} from')) {
      const match = line.match(/export\s*\{\s*([^}]+)\s*\}\s*from\s*["']([^"']+)["']/);
      if (match) {
        const exportsStr = match[1];
        const modulePath = match[2];
        const exportsList = exportsStr.split(',').map(s => s.trim()).filter(s => s.length > 0);
        newLines.push(`lazyExport('${modulePath}', [${exportsList.map(e => `'${e}'`).join(', ')}]);`);
      }
    } else {
      inMultilineExport = true;
      multilineBuffer = line.trim();
    }
  } else {
    newLines.push(line);
  }
}
newLines.push('export {};'); // Ensure it is still treated as a module

fs.writeFileSync('functions/src/index.ts', newLines.join('\n'));
console.log('Done');
