#!/usr/bin/env bash

die ()
{
    set +xe
    >&2 echo ""
    >&2 echo "================================ DIE ==============================="

    >&2 echo "$@"

    >&2 echo "Call stack:"
    local n=$((${#BASH_LINENO[@]}-1))
    local i=0
    while [ $i -lt $n ]; do
        local line=${BASH_LINENO[i]}
        local func=${FUNCNAME[i+1]}

        i=$((i+1))

        >&2 echo "    [$i] -- line $line -- $func"
    done
    >&2  echo "================================ END ==============================="
    exit 1
}

echo "Building tree-sitter.."

[ -d ../tree-sitter ] || git clone https://github.com/tree-sitter/tree-sitter.git ../tree-sitter
[ -d ../tree-sitter ] || die "Failed to get tree-sitter source"

pushd ../tree-sitter
git reset HEAD --hard
git pull
make -j8
PREFIX=${HOME}/.local make install
popd

echo ""
