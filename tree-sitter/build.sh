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

TOPDIR=$(dirname `realpath $0`)

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
    echo "Building tree-sitter.."
    pushd ${TOPDIR}/tree-sitter
    git reset HEAD --hard
    git pull
    make -j8
    PREFIX=${HOME}/.local make install
    popd

    echo ""
}

build-language ()
{
    [ $# -ne 1 ] && die "Usage: build-language language."

    pushd ${TOPDIR}

    local lang=$1
    local sourcedir="tree-sitter-${lang}/src"
    local grammardir="tree-sitter-${lang}"
    local repo="tree-sitter-${lang}"
    local org="tree-sitter"

    echo "Building language $lang"

    case "${lang}" in
        "dockerfile")
            org="camdencheek"
            ;;
        "cmake")
            org="uyha"
            ;;
        "go-mod")
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
        "meson")
            org="Decodetalkers"
            ;;
    esac

    echo "PWD: ${PWD} , repo: ${repo}"
    if ! [ -d ${repo} ]; then
        echo "${repo} does not exist, clone and add as submodule? (Y/n)"
        read -r ans
        case ${ans} in
            y|Y|"")
                git submodule add --name tree-sitter/${repo} -- \
                    "https://github.com/${org}/${repo}.git" "${repo}" || \
                    die "Failed to clone repo: ${org}/${repo}"
            ;;
            *)
                die "Operation abort..."
            ;;
        esac
    fi

    [ -d ${repo} ] || die "Directory ${repo} does not exist"

    local sourcedir=${TOPDIR}/${sourcedir}
    cp "${grammardir}"/grammar.js "${sourcedir}"

    # We have to go into the source directory to compile, because some
    # C files refer to files like "../../common/scanner.h".
    pushd "${sourcedir}" || die "Failed to change directory to ${sourcedir}"

    ### Build

    cc -fPIC -c -I. parser.c
    [ -f scanner.c ] && cc -fPIC -c -I. scanner.c
    [ -f scanner.cc ] && c++ -fPIC -I. -c scanner.cc

    [ -f scanner.cc ] && \
        c++ -fPIC -shared *.o -o "libtree-sitter-${lang}.${soext}" \
            || cc -fPIC -shared *.o -o "libtree-sitter-${lang}.${soext}"

    # Copy out

    cp -aRfv "libtree-sitter-${lang}.${soext}" ~/.local/lib/
    popd
}

build-all-langs ()
{
    echo "Building all languages..."

    local languages=(
        'bash'
        'c'
        'cmake'
        'cpp'
        "elisp"
        'css'
        # 'c-sharp'
        # 'dockerfile'
        'go'
        'go-mod'
        # 'html'
        'javascript'
        'json'
        'python'
        # 'rust'
        # 'toml'
        # 'tsx'
        # 'typescript'
        "java"
        'yaml'
        "meson"
    )

    for language in ${languages[@]}; do
        build-language $language
    done
}

update-to-lastest-tag ()
{
    git checkout $(git describe --tags $(git rev-list --tags --max-count=1))
}

while [ $# -ne 0 ]; do
    case "$1" in
        -h|--help)  help; exit 0 ;;
        -d|--debug) DEBUG=1 ;;
        -l|--lib)
            build-tree-sitter || die "Failed to build tree-sitter library."
            ;;
        -a|--all)
            build-all-langs  || die "Failed to build tree-sitter library."
            ;;
        -A|--ALL)
            build-tree-sitter || die "Failed to build tree-sitter library."
            build-all-languages || die "Failed to build parser."
            exit $?
            ;;
        -u|--update)
            git submodule foreach $0 -U
            build-tree-sitter
            build-all-languages
            ;;
        -U) # internal only
            update-to-lastest-tag ;;
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

for lang in $@; do
    build-language ${lang}
done
