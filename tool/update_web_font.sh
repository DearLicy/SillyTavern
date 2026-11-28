#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

source_font="${1:-}"
if [[ -z "$source_font" || ! -f "$source_font" ]]; then
  printf 'Usage: %s /path/to/NotoSansSC-VF.ttf\n' "$0" >&2
  exit 2
fi

export TMPDIR="$PWD/.tmp" TMP="$PWD/.tmp" TEMP="$PWD/.tmp"
mkdir -p .tmp web/fonts

python3 - <<'PY'
from pathlib import Path

texts = [path.read_text() for path in Path('lib').rglob('*.dart')]
texts.extend(
    path.read_text()
    for path in [Path('README.md'), *sorted(Path('docs').glob('*.md'))]
    if path.exists()
)
text = ''.join(texts)
seen: set[str] = set()
ordered = ''.join(char for char in text if not (char in seen or seen.add(char)))
Path('.tmp/web-font-chars.txt').write_text(ordered)
print(f'Web font text source: {len(ordered)} unique characters')
PY

python3 -m fontTools.subset "$source_font" \
  --text-file=.tmp/web-font-chars.txt \
  --unicodes='U+0000-00FF,U+0100-024F,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2600-26FF,U+3000-303F,U+FE10-FE1F,U+FF00-FFEF' \
  --layout-features='*' \
  --glyph-names \
  --symbol-cmap \
  --legacy-cmap \
  --notdef-glyph \
  --notdef-outline \
  --recommended-glyphs \
  --flavor=woff2 \
  --output-file=web/fonts/SillyTavernUI.woff2

printf 'Updated web/fonts/SillyTavernUI.woff2\n'
