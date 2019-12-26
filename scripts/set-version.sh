#!/bin/bash

set -exo pipefail

# constants
toc_file="VendorTrashManager.toc"
relnotes_file="release-notes.md"

version="${1}"
release_notes="${2}"

# verify project state is consistent before this script runs

if [ -n "$(git diff --name-only | grep -v "${toc_file}" | grep -v "${relnotes_file}")" ] || [ -n "$(git ls-files --others --exclude-standard | grep -v "${relnotes_file}")" ]; then
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

if [ -z "${version}" ]; then
    echo "no version specified"
    exit 1
fi

if [ -z "${release_notes}" ] && [ -f "${relnotes_file}" ]; then
    release_notes="$(cat "${relnotes_file}")"
    if [ -z "${release_notes}" ]; then
        echo ""
        echo "[WARNING]: release notes file '${relnotes_file}' is empty, you should probably delete it"
        echo ""
    fi
fi

version="v${version}"

sed -i.bak -E 's/^##\s+Version:\s+([^\n]+)$/## Version: '"${version}"'/' "${toc_file}"
rm -f "${toc_file}.bak"

git add "${toc_file}"
git commit -m "App version is now ${version}"

git tag "${version}"

git push origin
git push origin "refs/tags/${version}"

release_opts=""
if [ -n "${release_notes}" ]; then
    release_opts="-m $(printf '%q' "${release_notes}")"
else
    echo "no release notes found, making a pre-release"
    release_opts="-p"
fi

hub release create -m "${version}" ${release_opts} "${version}"
