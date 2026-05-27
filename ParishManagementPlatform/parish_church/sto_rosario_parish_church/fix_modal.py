import os
import glob

base_dir = r"c:\src\parish_church\sto_rosario_parish_church\lib"

count = 0
for filepath in glob.glob(os.path.join(base_dir, "**", "*.dart"), recursive=True):
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        new_content = content
        
        # 1. Global modal, missing constraints and using min
        new_content = new_content.replace(
'''      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [''',
'''      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ['''
        )

        # 2. Local modal, using hard width 320 and max
        new_content = new_content.replace(
'''        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [''',
'''        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['''
        )
        
        # 3. Expanded to Flexible
        new_content = new_content.replace(
'''            Expanded(
              child: Text(
                message,''',
'''            Flexible(
              child: Text(
                message,'''
        )

        if new_content != content:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(new_content)
            count += 1
            print(f"Fixed layout constraints in {filepath}")
    except Exception as e:
        print(f"Error processing {filepath}: {e}")

print(f"Total files updated: {count}")
