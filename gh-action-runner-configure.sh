#!/bin/sh

USER="aqua-penguin-bot"
REPO="test"
REPO_URL="https://github.com/$USER/$REPO"

for cmd in git curl tar gh; do
    if ! [ -x "$(command -v $cmd)" ]; then
        echo 'Required command:' $cmd 'is not installed' >&2
        exit 1
    fi
done

if [ -x ${GH_ACCESS_TOKEN} ]; then
    echo "value GH_ACCESS_TOKEN is not set"
    exit 1
fi

NODE_NAME=$HOST
if [ -z "$HOST" ]
then
    NODE_NAME=$(uname -r)
fi

rm -rf actions-runner
mkdir -p actions-runner
curl -o ./actions-runner/actions-runner-linux-x64-2.297.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.297.0/actions-runner-linux-x64-2.297.0.tar.gz
tar -xzf ./actions-runner/actions-runner-linux-x64-2.297.0.tar.gz -C actions-runner
cd ./actions-runner

echo "[*] Downloaded actions-runner repository"

# auth to gh api via cli
echo $GH_ACCESS_TOKEN | gh auth login --with-token

echo "[*] Authenticated with github"

# get enrollment key
ENROLL_KEY=$(gh api --method POST -H "Accept: application/vnd.github+json" /repos/$USER/$REPO/actions/runners/registration-token | jq '.token' | tr -d '"')
if [ $ENROLL_KEY = "" ]
then
    echo "error getting enrollment key"
    exit 1
fi

echo "[*] Configuring github actions runner for $USER/$REPO"
z
config_output=$(./config.sh --url $REPO_URL --token $ENROLL_KEY --unattended --name $NODE_NAME)
ret=$?
if [ $ret -ne 0 ]; then
    echo "[!] Error configuring github actions runner: $ret"
    REMOVAL_TOKEN=$(gh api --method POST -H "Accept: application/vnd.github+json" /repos/$USER/$REPO/actions/runners/remove-token | jq '.token' | tr -d '"')
    ./config.sh remove --token $REMOVAL_TOKEN
fi
