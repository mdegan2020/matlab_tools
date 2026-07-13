# Mathematical and Procedural Reference

This directory contains the C0 notation freeze and the source for the C1/C3
code-independent mathematical specification. The compiled, visually verified
artifact is `output/pdf/sightline_mathematical_specification.pdf`.

Build from the repository root:

```sh
docs/mathematical_reference/build_pdf.sh
```

The script uses `latexmk`, writes intermediate files under
`tmp/pdfs/sightline_mathematical_specification`, and copies the stable PDF to
`output/pdf`. The manuscript uses `IEEEtran` journal format, inline TikZ vector
figures, and the adjacent BibTeX database.

The executable C2 companion is `proceduralTwoImageAnaglyph.m`. It is a direct
double-precision matrix path, not a wrapper around the viewer or backend.
`ProjectionProceduralAnaglyphTest` compares its grid, inverse coordinates,
values, masks, eye assignment, presentation offsets, and stereo composition
against the production MATLAB components.
