#!/bin/bash
###
### Build treesitter and its friends
###
### Usage:
###   build.sh [options] [languages]
###
### Options:
###   -h, --help    Show this message.
###   -d, --debug   Show debug messages.
###   -c, --core    Build treesitter library only.
###   -u, --update  Update to the latest tag
###
###  Without specifying any language, everything will be built.
###
### More parsers can be found in:
###   https://github.com/tree-sitter/tree-sitter/blob/master/docs/index.md
###

help() {
    sed -rn 's/^### ?//;T;p' "$0"
    exit 0
}

SCRIPT=$(realpath "$0")
TOPDIR=${SCRIPT%/*}
C_ARGS=(-fPIC -c -I"${HOME}"/.local/include -I.)

case $(uname) in
    "Darwin") soext="dylib" ;;
    *"MINGW"*) soext="dll"   ;;
    *)   soext="so"    ;;
esac

__DEBUG_SH__=${__DEBUG_SH__:+${__DEBUG_SH__}}
PDEBUG()
{
    if [ -n "$__DEBUG_SH__" ]; then
        local line=${BASH_LINENO[0]}
        local func=${FUNCNAME[1]}
        >&2 echo "DEBUG: ($BASHPID) $(date '+%H:%M:%S:%3N'): $0:$line ($func) -- $*"
    fi
}

pdebug_setup() {
    set -x
    export __DEBUG_SH__=1
}

die() {
    set +xe
    echo "================================ DIE ===============================" >&2
    echo >&2 "$*"
    echo >&2 "Call stack:"
    local n=$((${#BASH_LINENO[@]} - 1))
    local i=0
    while [ $i -lt $n ]; do
        echo >&2 "    [$i] -- line ${BASH_LINENO[i]} -- ${FUNCNAME[i + 1]}"
        i=$((i + 1))
    done
    echo >&2 "================================ END ==============================="

    [[ $- == *i* ]] && return 1 || exit 1
}

build-tree-sitter() {
    echo "======================== Building tree-sitter ========================"
    pushd "${TOPDIR}"/tree-sitter || die "change dir"
    make -j8
    PREFIX=${HOME}/.local make install
    [ -f "${HOME}"/.local/lib/libtree-sitter.a ] && rm "${HOME}"/.local/lib/libtree-sitter.a
    popd > /dev/null 2>&1 || die "change dir"
    echo ""
}

build-language() {
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
    pushd "${sourcedir}" || die "Failed to change directory to ${sourcedir}"

    ### Build
    [[ -f parser.c ]] || die "parser.c is not found."
    cc "${C_ARGS[@]}" parser.c  || die "Compile fail"

    if [ -f scanner.c ]; then
        cc "${C_ARGS[@]}" scanner.c || die "Compile fail"
        cc -fPIC -shared ./*.o -o "${libname}" || die "Link fail"
    elif [ -f scanner.cc ]; then
        c++ "${C_ARGS[@]}" -c scanner.cc || die "Compile fail"
        c++ -fPIC -shared ./*.o -o "${libname}" || die "Link fail"
    fi

    cp -aRfv "${libname}" "${targetname}"
    popd > /dev/null 2>&1 || die "change dir"
    echo ""
}

build-all-langs() {
    echo "Building all ..."
    pushd "${TOPDIR}" || die "change dir"

    for file in *; do
        if [[ ! -d $file ]]; then
            echo "Skipping file: $file"
            continue
        fi

        if [[ "$file" = "tree-sitter" ]]; then
            echo "Skipping directory: $file"
            continue
        fi

        echo "Building ${file}"
        build-language  "${file//tree-sitter-/}"
    done
}

update-to-lastest-tag() {
    echo "======================== Updating: $(basename "${PWD}") ========================"
    git fetch origin
    local tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
    git checkout "${tag}"
    exit $?
}

while [ $# -gt 0 ] && [[ "$1" = -* ]]; do
    case "$1" in
        -h | --help) help 1 ;;
        -d | --debug) pdebug_setup ;;
        -c | --core) build-tree-sitter || die "Failed to build tree-sitter library." ;;
        -u | --update) git submodule foreach "${SCRIPT}" -U ;;
        -U) update-to-lastest-tag ;;
        *)
            if [[ $1 = -* ]]; then
                echo "Unrecognized opt: $1"
                help
                exit 1
            else
                break
            fi
            ;;
    esac

    shift
done

pushd "${TOPDIR}" || die "change dir"

if [ $# -ne 0 ]; then
    for lang in "$@"; do
        build-language "${lang}"
    done
else
    build-tree-sitter || die "Failed to build tree-sitter library."
    build-all-langs || die "Failed to build parser."
fi
