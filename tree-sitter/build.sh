#!/bin/bash
###
### Build treesitter and its friends
###
### Usage:
###   build.sh [options] [languages]
###
### Options:
###   -h, --help Show this message.
###   -l, --lib  Build treesitter library only.
###   -a, --all  Build all languages.
###   -A, --ALL  Build library & all languages.
###   -u, --update Update to latest tag
###   -s, --source specify source code dir to compile
###
### More parses can be found in:
###   https://github.com/tree-sitter/tree-sitter/blob/master/docs/index.md
###

help()
{
    sed -rn 's/^### ?//;T;p' "$0"
}

TOPDIR=$(dirname `realpath $0`)
SOURCEDIR=

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

build-tree-sitter ()
{
    echo "======================== Building tree-sitter ========================"
    pushd ${TOPDIR}/tree-sitter
    git reset HEAD --hard
    git pull
    make -j8
    PREFIX=${HOME}/.local make install
    ls ${HOME}.local/lib/libtree-sitter.a
    [ -f ${HOME}.local/lib/libtree-sitter.a ] && rm ${HOME}.local/lib/libtree-sitter.a
    popd >/dev/null 2>&1

    echo ""
}

build-language ()
{
    [ $# -ne 1 ] && die "Usage: build-language language."

    pushd ${TOPDIR}

    local lang=$1
    local repo="tree-sitter-${lang}"
    if [[ -n "${SOURCEDIR}" ]]; then
        repo=${SOURCEDIR}
    fi

    local sourcedir="${repo}/src"
    local grammardir="${repo}"
    local libname="libtree-sitter-${lang}.${soext}"
    local targetname="${HOME}/.local/lib/${libname}"

    # emacs crashes when overwrite shared library script inside emacs..
    if [[ -n "${INSIDE_EMACS}" ]]; then
        targetname=${targetname}_new
    fi

    echo "======================== Building language $lang ========================"

    case "${lang}" in
        "go-mod")
            lang="gomod"
            ;;
    esac

    echo "PWD: ${PWD}, repo: ${repo}"
    [ -d ${repo} ] || die "Directory ${repo} does not exist"

    cp "${grammardir}"/grammar.js "${sourcedir}"

    # We have to go into the source directory to compile, because some
    # C files refer to files like "../../common/scanner.h".
    pushd "${sourcedir}" || die "Failed to change directory to ${sourcedir}"

    ### Build
    cc -fPIC -c -I. parser.c
    [ -f scanner.c ] && cc -fPIC -c -I. scanner.c
    [ -f scanner.cc ] && c++ -fPIC -I. -c scanner.cc
    [ -f scanner.cc ] && c++ -fPIC -shared *.o -o ${libname} || cc -fPIC -shared *.o -o ${libname}

    # Copy out
    cp -aRfv ${libname} ${targetname}
    popd >/dev/null 2>&1

    echo ""
}

build-all-langs ()
{
    echo "Building all ..."

    pushd ${TOPDIR}

    for file in `ls -1`; do
        if [[ ! -d $file ]]; then
            echo "Skipping file: $file"
            continue
        fi

        if [[ "$file" = "tree-sitter" ]]; then
            echo "Skipping directory: $file"
            continue;
        fi

        echo "Building ${file}"
        build-language $(echo $file | sed "s/tree-sitter-//g")
    done
}

update-to-lastest-tag ()
{
    echo "======================== Updating: $(basename ${PWD}) ========================"
    git fetch origin
    git checkout $(git describe --tags $(git rev-list --tags --max-count=1))
    echo ""
}

while [ $# -ne 0 ]; do
    case "$1" in
        -h|--help)  help; exit 0 ;;
        -d|--debug) DEBUG=1 ;;
        -l|--lib)   build-tree-sitter || die "Failed to build tree-sitter library." ;;
        -a|--all)   build-all-langs  || die "Failed to build tree-sitter library." ;;
        -A|--ALL)
            build-tree-sitter || die "Failed to build tree-sitter library."
            build-all-langs || die "Failed to build parser."
            exit $?
            ;;
        -u|--update)
            git submodule foreach $0 -U
            for fn in `git status -s | grep tree-sitter | sed -E 's/.*?tree-sitter-//g'`; do
                if [ "$fn" = "tree-sitter" ]; then
                    build-tree-sitter
                else
                    build-language $fn
                fi
            done
            ;;
        -U) update-to-lastest-tag ;;
        -s|--source) shift; SOURCEDIR=$1 ;;
        *)
            if [[ $1 = -* ]]; then
                echo "Unrecognized opt: $1"
                help
                exit 1
            else
                break
            fi
    esac

    shift
done

pushd ${TOPDIR}
if [[ -n "${SOURCEDIR}" ]]; then
    [ $# -eq 1 ] || die "Accept 1 language only when '-s' is given..."
fi

for lang in $@; do
    build-language ${lang}
done
