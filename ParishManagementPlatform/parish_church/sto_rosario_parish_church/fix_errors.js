const fs = require('fs');

function fixFile(filePath, isLand) {
    let content = fs.readFileSync(filePath, 'utf8');

    // 1. Fix broken string literals with literal newlines
    content = content.replace(/'Sto\. Rosario\r?\nParish Church'/g, "'Sto. Rosario\\nParish Church'");

    // 2. Remove invalid 'const' modifiers before Text widgets using variables
    content = content.replace(/const Text\(\s*widget\.isTagalog/g, "Text(widget.isTagalog");
    content = content.replace(/const Text\(\s*_isTagalog/g, "Text(_isTagalog");
    content = content.replace(/const Text\(\s*_isLanguageTagalog/g, "Text(_isLanguageTagalog");

    // Remove const array wrapping InputDecorations if needed, but Flutter allows const InputDecoration? No, because widget.isTagalog makes it non-const
    content = content.replace(/(prefixIcon:\s*)const (Icon\([^)]+\))/g, "$1$2");
    content = content.replace(/const InputDecoration\(([\s\S]*?)widget\.isTagalog/g, "InputDecoration($1widget.isTagalog");
    content = content.replace(/const InputDecoration/g, "InputDecoration");

    // 3. Fix widget.isTagalog being used in main class instead of _isTagalog
    // In LandingPage, we accidentally used widget.isTagalog inside _LandingPageState
    if (isLand) {
        // Find widget.isTagalog before class LoginModal
        let parts = content.split('class LoginModal');
        parts[0] = parts[0].replace(/widget\.isTagalog/g, '_isTagalog');
        content = parts.join('class LoginModal');
    } else {
        let parts = content.split('class LoginModal');
        parts[0] = parts[0].replace(/widget\.isTagalog/g, '_isLanguageTagalog');
        content = parts.join('class LoginModal');
    }

    // Fix double ternary
    content = content.replace(/_isLanguageTagalog \? _isLanguageTagalog \?/g, "_isLanguageTagalog ?");
    content = content.replace(/_isTagalog \? _isTagalog \?/g, "_isTagalog ?");

    // 4. Fix any lingering `Text(\n`
    content = content.replace(/Text\(\r?\n\s*_isTagalog/g, "Text(_isTagalog");
    content = content.replace(/Text\(\r?\n\s*_isLanguageTagalog/g, "Text(_isLanguageTagalog");

    fs.writeFileSync(filePath, content, 'utf8');
}

fixFile('c:/src/parish_church/sto_rosario_parish_church/lib/features/auth/landing_page.dart', true);
fixFile('c:/src/parish_church/sto_rosario_parish_church/lib/parishioner_dashboard.dart', false);
