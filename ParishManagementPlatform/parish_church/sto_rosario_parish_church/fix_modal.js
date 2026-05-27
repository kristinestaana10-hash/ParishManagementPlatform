const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

let count = 0;
walkDir('c:/src/parish_church/sto_rosario_parish_church/lib', function(filePath) {
  if (filePath.endsWith('.dart')) {
    let content = fs.readFileSync(filePath, 'utf8');
    let originalEndsWithCRLF = content.includes('\r\n');
    let newContent = content.replace(/\r\n/g, '\n');

    // 1. Global modal, missing constraints and using min
    newContent = newContent.replace(
`      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [`,
`      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [`
    );

    // 2. Local modal, using hard width 320 and max
    newContent = newContent.replace(
`        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [`,
`        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [`
    );
    
    // 3. Local modal, using mainAxisSize.max but no width? (just in case)
    newContent = newContent.replace(
`        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [`,
`        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [`
    );

    // 4. Global modal in parishioner_dashboard.dart
    newContent = newContent.replace(
`        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [`,
`        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [`
    );

    // 5. Expand to Flexible
    newContent = newContent.replace(
`            Expanded(
              child: Text(
                message,`,
`            Flexible(
              child: Text(
                message,`
    );
    // Also global one has same indent
    newContent = newContent.replace(
`            Expanded(
              child: Text(
                message,`,
`            Flexible(
              child: Text(
                message,`
    );

    // also for 'const TextStyle' variations
    newContent = newContent.replace(
/Expanded\(\s*child:\s*Text\(\s*message,/g,
'Flexible(\n              child: Text(\n                message,'
    );

    if (originalEndsWithCRLF) {
       newContent = newContent.replace(/\n/g, '\r\n');
    }

    if (newContent !== content) {
      fs.writeFileSync(filePath, newContent, 'utf8');
      count++;
      console.log('Fixed:', filePath);
    }
  }
});

console.log('Total files updated:', count);
