#!/usr/bin/env bash
# Build the English course chapters into PDFs under pdf/.
#
# Requirements: a TeX Live install with pdflatex, the Cyrillic packages
# (texlive-lang-cyrillic) and Ghostscript/pdfcrop.
#
# Notes:
#  * Each en/*.tex chapter is a standalone document that \input{listki.tex}
#    (the shared macro preamble).
#  * A few English sources contain stray untranslated Russian words stored in
#    KOI8-R; we transcode every source to UTF-8 (ASCII passes through unchanged)
#    and inject fontenc[T1,T2A] so those remnants typeset instead of breaking
#    the build.
#  * geom8 pulls in five picture-environment fragments via \includegraphics;
#    we render each to a cropped standalone PDF first.
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/en"
OUT="$ROOT/pdf"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

mkdir -p "$OUT"
for f in "$SRC"/*.tex; do iconv -f KOI8-R -t UTF-8 "$f" > "$BUILD/$(basename "$f")"; done
cp "$SRC"/*.sty "$BUILD"/ 2>/dev/null || true
cd "$BUILD"
printf '\\usepackage[T1,T2A]{fontenc}\n%s' "$(cat listki.tex)" > listki.tex.new && mv listki.tex.new listki.tex

# geom8 picture fragments -> cropped standalone PDFs
for p in geom8pic0 geom8pic1 geom8pic2 geom8pic3 geom8pic4; do
  { printf '\\documentclass[12pt]{article}\\usepackage{amsmath}\\pagestyle{empty}\\begin{document}\n'
    cat "$p.tex"
    printf '\n\\end{document}\n'
  } > "wrap_$p.tex"
  pdflatex -interaction=nonstopmode -halt-on-error "wrap_$p.tex" >/dev/null 2>&1
  [ -f "wrap_$p.pdf" ] && { pdfcrop "wrap_$p.pdf" "$p.pdf" >/dev/null 2>&1 || cp "wrap_$p.pdf" "$p.pdf"; }
done

ok=(); fail=()
for f in alg1 alg2 alg3 alg4 alg5 alg6 alg7 alg8 alg9 alg10 alg11 alg12 \
         geom1 geom2 geom3 geom4 geom5 geom6 geom7 geom8 geom9 geom10 geom11 geom12; do
  [ -f "$f.tex" ] || { fail+=("$f(missing)"); continue; }
  pdflatex -interaction=nonstopmode "$f.tex" >/dev/null 2>&1
  pdflatex -interaction=nonstopmode "$f.tex" >/dev/null 2>&1
  if [ -f "$f.pdf" ]; then cp "$f.pdf" "$OUT/"; ok+=("$f"); else fail+=("$f"); fi
done
echo "BUILT (${#ok[@]}): ${ok[*]}"
echo "FAILED (${#fail[@]}): ${fail[*]}"

# Merge every chapter into a single PDF in the repo root, in course order.
merged=(); for n in $(seq 1 12); do merged+=("$OUT/alg$n.pdf"); done
for n in $(seq 1 12); do merged+=("$OUT/geom$n.pdf"); done
if printf '%s\n' "${merged[@]}" | xargs -I{} test -f {}; then
  pdfunite "${merged[@]}" "$ROOT/trivium-en.pdf" 2>/dev/null \
    || gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile="$ROOT/trivium-en.pdf" "${merged[@]}"
  echo "MERGED: trivium-en.pdf"
fi
