#!/bin/bash

## https://docs.github.com/en/rest/apps/oauth-applications?apiVersion=2022-11-28#reset-a-token

CLIENT_ID="<GITHUB_CLIENT_ID>"
CLIENT_SECRET="<GITHUB_CLIENT_SECRET>"
URL="https://api.github.com/applications/${CLIENT_ID}/token"
TOKEN=$1

curl --request PATCH \
--url "${URL}" \
--user "${CLIENT_ID}:${CLIENT_SECRET}" \
--header "Accept: application/vnd.github+json" \
--header "X-GitHub-Api-Version: 2022-11-28" \
--data "{\"access_token\": \"${TOKEN}\"}"