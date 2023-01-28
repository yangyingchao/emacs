#!/bin/bash

lang=$1
topdir="$PWD"

case $(uname) in
    "Darwin")
        soext="dylib"
        ;;
    *"MINGW"*)
        soext="dll"
        ;;
    *)
        soext="so"
        ;;
esac

die ()
{
    set +xe
    >&2 echo ""
    >&2 echo "================================ DIE ==============================="

    >&2 echo "$@"

    >&2 echo "Call stack:"
    local n=$((\${#BASH_LINENO[@]}-1))
    local i=0
    while [ $i -lt $n ]; do
        local line=\${BASH_LINENO[i]}
        local func=\${FUNCNAME[i+1]}

        i=$((i+1))

        >&2 echo "    [$i] -- line $line -- $func"
    done
    >&2  echo "================================ END ==============================="
    exit 1
}

echo "Building ${lang}"

### Retrieve sources

org="tree-sitter"
repo="tree-sitter-${lang}"
sourcedir="tree-sitter-${lang}/src"
grammardir="tree-sitter-${lang}"

case "${lang}" in
    "dockerfile")
        org="camdencheek"
        ;;
    "cmake")
        org="uyha"
        ;;
    "go-mod")
        # The parser is called "gomod".
        lang="gomod"
        org="camdencheek"
        ;;
    "typescript")
        sourcedir="tree-sitter-typescript/typescript/src"
        grammardir="tree-sitter-typescript/typescript"
        ;;
    "tsx")
        repo="tree-sitter-typescript"
        sourcedir="tree-sitter-typescript/tsx/src"
        grammardir="tree-sitter-typescript/tsx"
        ;;
    "yaml")
        org="ikatyang"
        ;;
    "elisp")
        org="Wilfred"
        ;;
esac

repo_dir=${topdir}/../${repo}
sourcedir=${topdir}/../${sourcedir}

if [ -d ${repo_dir} ];
then
    cd ${repo_dir}
    git reset HEAD --hard
    git pull
    cd ..
else
    cd ${topdir}/..
    git clone "https://github.com/${org}/${repo}.git" \
    --depth 1 --quiet
fi

[ -d ${repo_dir} ] || die "directory ${repo_dir} does not exist"

cp "${grammardir}"/grammar.js "${sourcedir}"
# We have to go into the source directory to compile, because some
# C files refer to files like "../../common/scanner.h".
cd "${sourcedir}"

### Build

cc -fPIC -c -I. parser.c
# Compile scanner.c.
if test -f scanner.c
then
    cc -fPIC -c -I. scanner.c
fi
# Compile scanner.cc.
if test -f scanner.cc
then
    c++ -fPIC -I. -c scanner.cc
fi
# Link.
if test -f scanner.cc
then
    c++ -fPIC -shared *.o -o "libtree-sitter-${lang}.${soext}"
else
    cc -fPIC -shared *.o -o "libtree-sitter-${lang}.${soext}"
fi

### Copy out

cp -aRfv "libtree-sitter-${lang}.${soext}" ~/.local/lib/
cd "${topdir}"

