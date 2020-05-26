#!/usr/bin/env bash

BODY="$(date +'%Y%m%d%H%M%S')"
REPO="english/test-releases"
ASSET1="$(git rev-parse --show-toplevel)/asset1.zip"
ASSET2="$(git rev-parse --show-toplevel)/asset2.yml"
COMMIT="$(git rev-parse HEAD)"
TAG=$BODY
PRE_RELEASE="true"

# 1. create a draft release
payload=$(
  jq --null-input \
     --arg tag "$TAG" \
     --arg commit "$COMMIT" \
     --arg body "$BODY" \
     --argjson prerelease "$PRE_RELEASE" \
     '{ tag_name: $tag, target_commitish: $commit, body: $body, draft: true, prerelease: $prerelease }'
)

response=$(
  curl -d "$payload" \
       "https://api.github.com/repos/$REPO/releases?access_token=$GITHUB_TOKEN"
)

release_url="$(echo "$response" | jq -r .url)"
upload_url="$(echo "$response" | jq -r .upload_url | sed -e "s/{?name,label}//")"

# 2. upload release assets
curl -H "Content-Type:application/gzip" \
     --data-binary "@$ASSET1" \
     "$upload_url?name=$(basename "$ASSET1")&access_token=$GITHUB_TOKEN"

curl -H "Content-Type:application/yaml" \
     --data-binary "@$ASSET2" \
     "$upload_url?name=$(basename "$ASSET2")&access_token=$GITHUB_TOKEN"

# 3. publish the release to trigger a new webhook for app-version-manager that includes the uploaded
# assets
curl -X PATCH \
     -H "Content-Type:application/json" \
     -d '{ "draft": false }' \
     "$release_url?access_token=$GITHUB_TOKEN"
