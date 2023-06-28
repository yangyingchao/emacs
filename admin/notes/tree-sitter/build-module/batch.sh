#!/bin/bash
languages=(
    'bash'
    'c'
    'cmake'
    'cpp'
    "elisp"
    'css'
    # 'c-sharp'
    # 'dockerfile'
    # 'go'
    # 'go-mod'
    # 'html'
    'javascript'
    'json'
    'python'
    # 'rust'
    # 'toml'
    # 'tsx'
    # 'typescript'
    "java",
    'yaml'
)

for language in "${languages[@]}"
do
    ./build.sh $language
done
