#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
tmp_dir="$repo_root/tmp/pdfs/sightline_mathematical_specification"
output_dir="$repo_root/output/pdf"

mkdir -p "$tmp_dir" "$output_dir"
cd "$script_dir"
latexmk -pdf -interaction=nonstopmode -halt-on-error \
    -outdir="$tmp_dir" \
    "$script_dir/sightline_mathematical_specification.tex"
cp "$tmp_dir/sightline_mathematical_specification.pdf" \
    "$output_dir/sightline_mathematical_specification.pdf"
pdfinfo "$output_dir/sightline_mathematical_specification.pdf"
