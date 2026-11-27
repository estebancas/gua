#!/bin/sh
# Gate test (#49): this PR must be refused by gua-merge and closed.
# Runs the busted specs with coverage and enforces the coverage minimum.
# LuaCov adds to luacov.stats.out instead of replacing it, so old results are
# deleted first; otherwise a deleted test would still count as coverage.
# Usage (repo root): sh scripts/test.sh [busted args...]   MIN=90 by default.
set -eu

rm -f luacov.stats.out luacov.report.out
busted --coverage "$@"
luacov
sh scripts/check-coverage.sh "${MIN:-90}"
