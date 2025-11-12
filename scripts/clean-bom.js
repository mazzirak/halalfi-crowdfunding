const fs = require('fs');
const path = require('path');

function removeBOM(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    if (content.charCodeAt(0) === 0xFEFF) {
        fs.writeFileSync(filePath, content.slice(1), 'utf8');
        console.log(`Removed BOM from: ${filePath}`);
    }
}

function cleanDirectory(dir) {
    const files = fs.readdirSync(dir);
    files.forEach(file => {
        const filePath = path.join(dir, file);
        if (fs.statSync(filePath).isDirectory()) {
            cleanDirectory(filePath);
        } else if (file.endsWith('.sol')) {
            removeBOM(filePath);
        }
    });
}

cleanDirectory('./contracts');
console.log('Done cleaning BOM characters!');