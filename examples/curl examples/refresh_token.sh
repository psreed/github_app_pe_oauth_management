#!/bin/bash

## https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/refreshing-user-access-tokens#refreshing-a-user-access-token-with-a-refresh-token

CLIENT_ID="<GITHUB_CLIENT_ID>"
CLIENT_SECRET="<GITHUB_CLIENT_SECRET>"
URL="https://github.com/login/oauth/access_token"
REFRESH_TOKEN=$1

curl --request POST \
--url "${URL}" \
--user "${CLIENT_ID}:${CLIENT_SECRET}" \
--header "Accept: application/vnd.github+json" \
--data "grant_type=refresh_token" \
--data "refresh_token=${REFRESH_TOKEN}"
