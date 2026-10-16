#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
revision=d0b5b51fac4c52c493371b9b18e66ce604ea4326
library=.types/vscode-wow-api
server=${LUA_LANGUAGE_SERVER:-lua-language-server}

if [[ $("$server" --version) != 3.19.1 ]]; then
    echo 'typecheck: lua-language-server 3.19.1 is required' >&2
    exit 1
fi
mkdir -p .types
if [[ ! -d "$library" ]]; then
    staging=$(mktemp -d .types/wow-api.XXXXXX)
    trap 'rm -rf -- "$staging"' EXIT
    git init -q "$staging"
    git -C "$staging" fetch -q --depth 1 https://github.com/Ketho/vscode-wow-api.git "$revision"
    git -C "$staging" checkout -q --detach FETCH_HEAD
    # The parent commit also pins FrameXML's submodule; never follow its branch tip.
    git -C "$staging" submodule update --init --depth 1 Annotations/FrameXML
    mv -- "$staging" "$library"
    trap - EXIT
fi
if [[ $(git -C "$library" rev-parse HEAD) != "$revision" ]] ||
    [[ -n $(git -C "$library" status --porcelain --untracked-files=all) ]] ||
    [[ $(git -C "$library" submodule status Annotations/FrameXML) != ' '* ]]; then
    echo "typecheck: $library must be a clean checkout of $revision with its pinned FrameXML submodule" >&2
    exit 1
fi

python3 tools/forever_tools/sync.py check
python3 -m unittest discover -s tests -p '*_test.py'
python3 -m unittest discover -s tools -p '*_test.py'
python3 -m tools.lint_taint
python3 tools/lint_art.py
python3 tools/lint_secret.py
python3 tools/check_editorconfig.py
python3 tools/check_locales.py
python3 tools/check_family.py
python3 tools/typecheck_coverage.py
python3 tools/lint_multivalue.py

# A fresh output file prevents a failed/crashed server from reusing an earlier clean report.
report=$(mktemp .types/diagnostics.XXXXXX.json)
trap 'rm -f -- "$report"' EXIT
status=0
"$server" --check=. --checklevel=Information --check_format=json \
    --check_out_path="$report" --logpath=.types/log || status=$?
python3 tools/check_diagnostics.py "$report"
exit "$status"
