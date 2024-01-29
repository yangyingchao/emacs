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
###
### More parses can be found in:
###   https://github.com/tree-sitter/tree-sitter/blob/master/docs/index.md
###

help()
{
    sed -rn 's/^### ?//;T;p' "$0"
}

SCRIPT=$(realpath "$0")
TOPDIR=${SCRIPT%/*}

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
    pushd "${TOPDIR}"/tree-sitter || die "change dir"
    make -j8
    PREFIX=${HOME}/.local make install
    [ -f "${HOME}"/.local/lib/libtree-sitter.a ] && rm "${HOME}"/.local/lib/libtree-sitter.a
    popd >/dev/null 2>&1  || die "change dir"
    echo ""
}

build-language ()
{
    [ $# -ne 1 ] && die "Usage: build-language language."

    pushd "${TOPDIR}" || die "change dir"

    local lang=$1
    local repo="tree-sitter-${lang}"
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
        "go-mod") lang="gomod" ;;
    esac

    echo "PWD: ${PWD}, repo: ${repo}"
    [ -d "${repo}" ] || die "Directory ${repo} does not exist"

    cp "${grammardir}"/grammar.js "${sourcedir}"

    # We have to go into the source directory to compile, because some
    # C files refer to files like "../../common/scanner.h".
    pushd "${sourcedir}" || die "Failed to change directory to ${sourcedir}"

    ### Build
    cc -fPIC -c -I. parser.c  || die "Compile fail"
    if [ -f scanner.c ]; then
        cc -fPIC -c -I. scanner.c || die "Compile fail"
        cc -fPIC -shared ./*.o -o "${libname}" || die "Link fail"
    elif [ -f scanner.cc ]; then
        c++ -fPIC -I. -c scanner.cc || die "Compile fail"
        c++ -fPIC -shared ./*.o -o "${libname}" || die "Link fail"
    fi

    # Copy out
    cp -aRfv "${libname}" "${targetname}"
    popd >/dev/null 2>&1  || die "change dir"

    echo ""
}

build-all-langs ()
{
    echo "Building all ..."
    pushd "${TOPDIR}" || die "change dir"

    for file in *; do
        if [[ ! -d $file ]]; then
            echo "Skipping file: $file"
            continue
        fi

        if [[ "$file" = "tree-sitter" ]]; then
            echo "Skipping directory: $file"
            continue;
        fi

        echo "Building ${file}"
        build-language  "${file//tree-sitter-/}"
    done
}

update-to-lastest-tag ()
{
    echo "======================== Updating: $(basename "${PWD}") ========================"
    git fetch origin
    local tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
    git checkout "${tag}"
    echo ""
}

while [ $# -ne 0 ]; do
    case "$1" in
        -h|--help)  help; exit 0 ;;
        -l|--lib)   build-tree-sitter || die "Failed to build tree-sitter library." ;;
        -a|--all)   build-all-langs  || die "Failed to build tree-sitter library." ;;
        -A|--ALL)
            build-tree-sitter || die "Failed to build tree-sitter library."
            build-all-langs || die "Failed to build parser."
            exit $?
            ;;
        -u|--update)
            git submodule foreach "${SCRIPT}" -U
            for fn in $(git status -s | grep tree-sitter | awk '{print $2}' \
                            | grep -v "build.sh" | sed -E 's/.*?tree-sitter-//g'); do
                if [ "$fn" = "tree-sitter" ]; then
                    build-tree-sitter
                else
                    build-language "$fn"
                fi
            done
            ;;
        -U) update-to-lastest-tag ;;
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

pushd "${TOPDIR}" || die "change dir"
for lang in "$@"; do
    build-language "${lang}"
done
