#!/bin/bash

set -exo pipefail

# constants
toc_file="VendorTrashManager.toc"

version="${1}"

# verify project state is consistent before this script runs

if [ -n "$(git diff --name-only | grep -v "${toc_file}")" ] || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    git status
    echo ""
    echo "dirty or untracked files exist"
    echo ""
    exit 1
fi

prefix="v"
if [[ "${version}" = "${prefix}"* ]]; then
    version="${version#"${prefix}"}"
fi

test -n "${version}" || (
    echo "no version specified"
    exit 1
)

version="v${version}"

sed -i.bak -E 's/^##\s+Version:\s+([^\n]+)$/## Version: '"${version}"'/' "${toc_file}"
rm -f "${toc_file}.bak"

git add "${toc_file}"
git commit -m "App version is now ${version}"

git tag "${version}"

git push origin
git push origin "refs/tags/${version}"
