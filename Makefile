.PHONY: install lint test audit manifest build download controlled summarize grouped-cv paired-stats

install:
	python -m pip install -e ".[dev]"

lint:
	ruff check .

test:
	pytest

audit:
	python scripts/reproduce_tables.py
	python scripts/verify_reproduction.py

manifest:
	python scripts/generate_manifest.py

build:
	python -m build


download:
	python scripts/download_cmapss.py --output data/raw/CMaps

controlled:
	python scripts/run_controlled_matrix.py --data-root data/raw/CMaps --output-root runs/controlled

summarize:
	python scripts/summarize_controlled_runs.py --runs-root runs/controlled --metric-scope window


grouped-cv:
	python scripts/run_grouped_cv.py --data-root data/raw/CMaps --output-root runs/grouped_cv --protocol grouped-kfold --folds 5 --fold-seed 42 --training-seeds 42 123 456

paired-stats:
	python scripts/paired_statistics.py --index runs/grouped_cv/cv_index.json --output-dir artifacts/generated/grouped_cv_statistics
