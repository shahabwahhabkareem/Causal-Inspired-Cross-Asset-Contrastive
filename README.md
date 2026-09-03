# C3M-Farm

Auditable, GitHub-ready **reference implementation** of the architecture described in
*Causal-Inspired Cross-Asset Contrastive Multimodal Maintenance Network: A Proxy-Benchmark
Study for Renewable-Energy Maintenance*.

## Reproducibility status

This repository intentionally separates three things:

1. **Paper-reported facts** — settings and summary numbers explicitly present in the manuscript.
2. **Reference implementation choices** — explicit, leakage-safe choices needed to make the
   architecture executable where the manuscript does not fully specify historical code.
3. **Unavailable historical artifacts** — raw predictions, exact historical synthetic-text rules,
   and exact historical proxy-graph construction are not fabricated.

The manuscript reports a controlled C-MAPSS protocol with engine-disjoint 70/15/15 splits,
RUL cap `min(125, actual_RUL)`, train-only min-max scaling, window length 128, stride 64,
and seeds 42, 123, and 456. Those settings are encoded in
`configs/reference_cmapss.yaml`.

The runnable reference implementation uses explicit proxy-view choices:
STFT `win_length=64`, `hop_length=32`, `n_fft=128`; a time-causal synthetic text generator
using only the current sensor window; and a deterministic operating-context k-NN proxy graph.
These choices are documented as **reference choices**, not recovered historical details.

## Repository layout

```text
c3m-farm/
├── configs/
│   ├── paper_reported.yaml
│   └── reference_cmapss.yaml
├── artifacts/
│   ├── preserved/preliminary_results.json
│   ├── controlled/controlled_summary.json
│   └── provenance.json
├── schemas/
├── scripts/
├── src/c3m_farm/
│   ├── data/
│   ├── models/
│   ├── audit.py
│   ├── cli.py
│   ├── config.py
│   ├── losses.py
│   ├── metrics.py
│   └── training.py
├── tests/
├── .github/workflows/ci.yml
├── CITATION.cff
├── LICENSE
└── pyproject.toml
```

## Install

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
```

## Prepare NASA C-MAPSS

Download the original C-MAPSS text files from the official NASA source and place them under:

```text
data/raw/CMaps/
  train_FD001.txt
  train_FD002.txt
  train_FD003.txt
  train_FD004.txt
  test_FD001.txt
  ...
  RUL_FD001.txt
  ...
```

The package does not redistribute C-MAPSS.

## Run one reference experiment

```bash
c3m-train \
  --config configs/reference_cmapss.yaml \
  --subset FD001 \
  --seed 42 \
  --data-root data/raw/CMaps \
  --output-root runs
```

Run the remaining manuscript seeds similarly:

```bash
for seed in 42 123 456; do
  c3m-train \
    --config configs/reference_cmapss.yaml \
    --subset FD001 \
    --seed "$seed" \
    --data-root data/raw/CMaps \
    --output-root runs
done
```

## Numerical audit

The repository contains only summary records that are supported by the supplied manuscript.
It does **not** invent missing raw predictions.

```bash
python scripts/reproduce_tables.py
python scripts/verify_reproduction.py
python scripts/generate_manifest.py --check
pytest
```

`verify_reproduction.py` checks the preserved 2,000-sample headline vector, recomputes the
five-fold mean/sample standard deviation, and verifies the controlled summary table. Statistical
p-values cannot be recomputed without the underlying paired per-engine/fold predictions.

## Architecture mapping

The implementation follows the manuscript equations:

- modality encoding: Eq. (2)
- health/context/residual projections: Eq. (4)
- orthogonality: Eq. (5)
- reconstruction: Eq. (6)
- cosine similarity + InfoNCE: Eq. (7)-(9)
- graph propagation: Eq. (10)-(12)
- attention fusion: Eq. (13)-(15)
- classification/RUL/risk heads: Eq. (16)-(21)
- urgency score: Eq. (22)
- trajectory consistency: Eq. (23)
- reported total objective with inactive risk loss: Eq. (24)

See `docs/method_mapping.md`.

## Before publishing on GitHub

1. Replace placeholder repository/DOI fields in `CITATION.cff`.
2. Confirm the code license with all authors.
3. Add the real raw per-seed/per-fold predictions from the controlled experiments, if available.
4. Regenerate `MANIFEST.sha256`.
5. Run CI locally.
6. Create a tagged release and archive it with Zenodo or another DOI service if required by the journal.

## Scientific-use warning

Do not describe the generated proxy graph as physical renewable-farm topology. C-MAPSS has no
geographic/electrical farm relations. Do not describe the synthetic text or STFT view as an
independently acquired modality. They are derived from the same underlying C-MAPSS records.


## Controlled baselines

Version 0.2 adds runnable controlled-comparison variants for:

- Decision Transformer
- MACPTD
- Transformer-GRU

The repository **does not silently merge conflicting source configurations**. The C3M-Farm
manuscript's controlled Decision-Transformer and Transformer-GRU settings differ from the
settings in the cited papers, so both variants are stored separately under `configs/baselines/`.
MACPTD is explicitly labeled a best-supported reconstruction because no public official code/full
architecture was recoverable from the available sources.

See `docs/baseline_sources.md`.

## Download C-MAPSS and run all four subsets

```bash
python scripts/download_cmapss.py --output data/raw/CMaps

python scripts/run_controlled_matrix.py \
  --data-root data/raw/CMaps \
  --output-root runs/controlled

python scripts/summarize_controlled_runs.py \
  --runs-root runs/controlled \
  --metric-scope window
```

This runs FD001-FD004 using seeds 42, 123, and 456 for C3M-Farm plus the three controlled
baselines. Raw predictions and metrics are retained per run.


## v0.3: grouped five-fold statistics + local dataset import

The statistical pipeline now supports immutable engine-grouped five-fold splits shared by
C3M-Farm and every controlled baseline.

```bash
# If you already have CMAPSSData.zip:
python scripts/import_cmapss_archive.py \
  --archive /path/to/CMAPSSData.zip \
  --output data/raw/CMaps

# Five grouped folds, same folds for all models, all three manuscript seeds:
python scripts/run_grouped_cv.py \
  --data-root data/raw/CMaps \
  --output-root runs/grouped_cv \
  --protocol grouped-kfold \
  --folds 5 \
  --fold-seed 42 \
  --training-seeds 42 123 456

# Regenerate paired fold tests and secondary per-engine error tests:
python scripts/paired_statistics.py \
  --index runs/grouped_cv/cv_index.json \
  --output-dir artifacts/generated/grouped_cv_statistics
```

See `docs/grouped_cv_statistics.md` for the important distinction between classical five-fold
testing (20% test engines per fold) and the manuscript's separate 70/15/15 holdout protocol.
