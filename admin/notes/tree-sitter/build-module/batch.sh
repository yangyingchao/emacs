#!/bin/bash

source ${HOME}/.local/share/shell/yc-common.sh


echo "Building tree-sitter.."

pushd ../tree-sitter
git reset HEAD --hard
git pull
make -j8
PREFIX=${HOME}/.local make install
popd

echo ""

languages=(
    'bash'
    'c'
    'cmake'
    'cpp'
    "elisp"
    # 'css'
    # 'c-sharp'
    # 'dockerfile'
    # 'go'
    # 'go-mod'
    # 'html'
    # 'javascript'
    'json'
    'python'
    # 'rust'
    # 'toml'
    # 'tsx'
    # 'typescript'
    'yaml'
)

for language in "${languages[@]}"
do
    ./build.sh $language
done
