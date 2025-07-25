#!/bin/sh
CWD="$(pwd)"
MY_SCRIPT_PATH=`dirname "${BASH_SOURCE[0]}"`
cd "${MY_SCRIPT_PATH}"

echo "Creating Docs for the Passkeys Demo\n"
rm -drf docs/*

jazzy  --readme ./README.md \
       --github_url https://github.com/LittleGreenViper/PassKeysDemo \
       --title "Passkeys Demo Doumentation" \
       --min_acl public \
       --theme fullwidth
cp ./icon.png docs/
