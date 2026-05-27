const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

function processContent(content) {
  let newContent = content.replace(/\r\n/g, '\n');

  // Fix 1: _showModalNotificationGlobal
  let globalRegex = /void _showModalNotificationGlobal\([\s\S]*?showDialog\([\s\S]*?\n  \);\n\n  \/\/ Auto-dismiss after 2 seconds\n  Future\.delayed\(const Duration\(seconds: 2\), \(\) \{\n    if \(Navigator\.canPop\(context\)\) \{\n      Navigator\.of\(context\)\.pop\(\);\n    \}\n  \}\);\n\}/g;
  
  newContent = newContent.replace(globalRegex, (match) => {
    let m1 = match.replace('showDialog(', 'bool isDialogOpen = true;\n  showDialog(');
    let m2 = m1.replace('\n  );\n\n  // Auto-dismiss', '\n  ).then((_) => isDialogOpen = false);\n\n  // Auto-dismiss');
    let m3 = m2.replace('if (Navigator.canPop(context)) {', 'if (isDialogOpen && Navigator.canPop(context)) {');
    return m3;
  });

  // Fix 2: _showModalNotification (in parishioner_dashboard.dart)
  let localRegex = /void _showModalNotification\(String message, \{Color bgColor = Colors\.blue\}\) \{\n    showDialog\([\s\S]*?\n    \);\n\n    \/\/ Auto-dismiss after 2 seconds\n    Future\.delayed\(const Duration\(seconds: 2\), \(\) \{\n      if \(mounted\) \{\n        Navigator\.of\(context\)\.pop\(\);\n      \}\n    \}\);\n  \}/g;

  newContent = newContent.replace(localRegex, (match) => {
    let m1 = match.replace('showDialog(', 'bool isDialogOpen = true;\n    showDialog(');
    let m2 = m1.replace('\n    );\n\n    // Auto-dismiss', '\n    ).then((_) => isDialogOpen = false);\n\n    // Auto-dismiss');
    let m3 = m2.replace('if (mounted) {', 'if (mounted && isDialogOpen) {');
    return m3;
  });

  return newContent;
}

let count = 0;
walkDir('c:/src/parish_church/sto_rosario_parish_church/lib', function(filePath) {
  if (filePath.endsWith('.dart')) {
    let content = fs.readFileSync(filePath, 'utf8');
    let originalEndsWithCRLF = content.includes('\r\n');
    
    let newContent = processContent(content);

    if (originalEndsWithCRLF) {
       newContent = newContent.replace(/\n/g, '\r\n');
    }

    if (newContent !== content) {
      fs.writeFileSync(filePath, newContent, 'utf8');
      count++;
      console.log('Fixed dialog pop in:', filePath);
    }
  }
});

console.log('Total files updated:', count);
