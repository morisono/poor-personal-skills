#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

TEXT_EXTS = {'.js', '.ts', '.tsx', '.jsx', '.py', '.sh', '.ps1', '.json', '.yaml', '.yml', '.toml', '.md', '.env'}
DIRECT_MODEL_RE = re.compile(r'(?i)(fetch\(|axios\.|requests\.|urllib|curl .*deepseek|direct.*deepseek)')
OUTPUT_BOUND_RE = re.compile(r'(?i)(max_tokens|max completion|max_output|max_output_tokens|temperature|top_p)')
COST_KEYWORDS_RE = re.compile(r'(?i)(deepseek|openai|anthropic|gateway|ai gateway|cache|retry|backoff|spend|quota|budget|queue|dlp|pii|auth|authorization)')

@dataclass
class Finding:
    severity: str
    path: str
    message: str


def iter_files(paths: Iterable[Path]) -> Iterable[Path]:
    for p in paths:
        if p.is_dir():
            for child in p.rglob('*'):
                if child.is_file():
                    yield child
        elif p.is_file():
            yield p


def is_text_file(path: Path) -> bool:
    return path.suffix.lower() in TEXT_EXTS or path.name.startswith('.env')


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return ''


def audit(paths: list[Path]) -> list[Finding]:
    findings: list[Finding] = []
    for file in iter_files(paths):
        if not is_text_file(file):
            continue
        text = read_text(file)
        if not text:
            continue

        if COST_KEYWORDS_RE.search(text):
            pass

        if DIRECT_MODEL_RE.search(text):
            findings.append(Finding('major', str(file), 'possible direct upstream model access'))

        if not OUTPUT_BOUND_RE.search(text):
            findings.append(Finding('minor', str(file), 'no obvious output bound found'))

        if re.search(r'(?i)retry', text) and not re.search(r'(?i)(backoff|attempt|max[_- ]?retry|retry[_- ]?count)', text):
            findings.append(Finding('major', str(file), 'retry logic appears unbounded or underspecified'))

        if re.search(r'(?i)(deepseek|llm|model)', text) and not re.search(r'(?i)(cache|ttl|memo|etag|key)', text):
            findings.append(Finding('minor', str(file), 'no obvious cache strategy found near model path'))

    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description='Audit Cloudflare x DeepSeek cost-control gaps')
    parser.add_argument('paths', nargs='*', default=['.'])
    parser.add_argument('--json', action='store_true', help='emit JSON')
    parser.add_argument('--strict', action='store_true', help='exit non-zero on major findings')
    args = parser.parse_args()

    findings = audit([Path(p) for p in args.paths])

    if args.json:
        print(json.dumps([asdict(f) for f in findings], ensure_ascii=False, indent=2))
    else:
        for f in findings:
            print(f'[{f.severity}] {f.path}: {f.message}')

    major_count = sum(1 for f in findings if f.severity == 'major')
    minor_count = sum(1 for f in findings if f.severity == 'minor')
    print(f'summary: major={major_count} minor={minor_count}')

    return 1 if args.strict and major_count else 0


if __name__ == '__main__':
    raise SystemExit(main())
