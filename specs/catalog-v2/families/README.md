# Catalog-v2 families

This directory contains one reviewed JSON source file per movement family.
`horizontal-press.json`, `incline-press.json`, and `decline-press.json`
establish the initial small-batch workflow; later families follow the same
contract-first process.

Files here must never be derived from, compared with, or merged with the legacy
exercise roster. `Scripts/catalog_v2.py --check` discovers and validates every
`*.json` file in this directory.
