# Overleaf Project Setup

## Upload to Overleaf

1. Go to https://www.overleaf.com/project → **New Project → Upload Project**
2. Zip this entire directory:
   ```bash
   cd /Users/florinolariu/Downloads
   zip -r ieee-software-paper.zip ieee-software-paper/
   ```
3. Upload `ieee-software-paper.zip`
4. Set the **main document** to `main.tex`
5. Set **compiler** to `pdfLaTeX`

## Before you compile

### Required: add author photos
Place two JPEG/PNG files in the `figures/` directory:
- `figures/florin-photo.jpg`   (1×1.25 inch, 300 dpi recommended)
- `figures/lenuta-photo.jpg`   (same size)

If you don't have photos yet, comment out the optional argument in the
`IEEEbiography` environments in `main.tex`:
```latex
% Before (with photo):
\begin{IEEEbiography}[{\includegraphics[...]{figures/florin-photo}}]{Florin Olariu}

% After (without photo, for draft):
\begin{IEEEbiography}{Florin Olariu}
```

### Required: verify affiliation details
In `main.tex`, the `\IEEEcompsocitemizethanks` block contains the
author affiliations. Update department name and mailing address if
needed.

### Optional: IEEEtran class
Overleaf includes IEEEtran v1.8b by default — no manual upload needed.

## Word count (IEEE Software limit: 4,200 words incl. 250/figure/table)

| Item                | Words |
|---------------------|-------|
| Text (approximate)  | ~3,200 |
| Figure 1 (pipeline) | 250   |
| Figure 2 (architecture) | 250 |
| Figure 3 (gate)     | 250   |
| Table I (skills)    | 250   |
| **Total**           | **~4,200** |

To get an exact count in Overleaf: Menu → Word Count.

## Submission

Portal: https://ieee.atyponrex.com/journal/sw-cs

Pre-screen option (recommended before full submission):
Email the abstract to the Editor-in-Chief:
  sigrid.eldh@ieee.org
Subject line: "Pre-screen request: AI-Assisted Decomposition of .NET
Monoliths into Microservices"

## Files in this project

| File | Purpose |
|------|---------|
| `main.tex` | Full paper (IEEEtran compsoc journal) |
| `references.bib` | 13 BibTeX entries |
| `cover-letter.tex` | Separate cover letter (compile independently) |
| `figures/pipeline.tikz` | Fig. 1 — 10-skill pipeline diagram |
| `figures/architecture.tikz` | Fig. 2 — monolith vs microservices |
| `figures/gate.tikz` | Fig. 3 — quality-gate cycle |
| `figures/florin-photo.jpg` | **ADD THIS** — author photo |
| `figures/lenuta-photo.jpg` | **ADD THIS** — author photo |
