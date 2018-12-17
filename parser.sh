#!/bin/sh
#
# parser <path> <filename>
#

EVTC_FILE_PATH="$1"
EVTC_FILE_NAME="$2"

OUT_FILE_NAME="$(echo "$EVTC_FILE_NAME" | sha256sum - | cut -d ' ' -f1 | cut -c1-12)"

PARSED_EVTC_FOLDER="$(dirname $1)"
PARSED_HTML_FOLDER="$FILE_BASE_PATH/evtc-$OUT_FILE_NAME"

mono GuildWars2EliteInsights.exe \
    -p \
    -c settings.conf \
    "$EVTC_FILE_PATH"

mkdir -p "$PARSED_HTML_FOLDER"

for file in $PARSED_EVTC_FOLDER/*; do
    echo $file | grep -Eq "*.html$"
    if [ $? -eq 0 ]; then
        cp "$file" "$PARSED_HTML_FOLDER/index.html"
    fi

    echo $file | grep -Eq "*.json$"
    if [ $? -eq 0 ]; then
        cp "$file" "$PARSED_HTML_FOLDER/data.json"
    fi
done

if [ "$DPS_BASE_URL" = "" ]; then
    DPS_BASE_URL="http://${SERVER_LISTEN_ADDR:"127.0.0.1"}:${SERVER_LISTEN_PORT:"3000"}"
fi

EVTC_JSON_DATA=$(cat "$PARSED_HTML_FOLDER/data.json")

if [ "$(echo "$EVTC_JSON_DATA" | jq -r .success)" = "1" ]; then
    EVTC_SUCCESS_COLOR="3897943"
    EVTC_SUCCESS_TEXT="Success :thumbsup:"
else
    EVTC_SUCCESS_COLOR="11216719"
    EVTC_SUCCESS_TEXT="Failed :thumbsdown:"
fi

WEBHOOK_EMBED_CONTENT="{\"embeds\": [{
    \"color\": $EVTC_SUCCESS_COLOR,
    \"description\": \"PoV: $(echo "$EVTC_JSON_DATA" | jq -r .recordedBy) ($(echo "$EVTC_JSON_DATA" | jq -r ".players | map(select(.character == \"$(echo "$EVTC_JSON_DATA" | jq -r .recordedBy)\")) | .[] | .profession"))\\nDuration: $(echo "$EVTC_JSON_DATA" | jq -r .duration)\\nSuccess: $EVTC_SUCCESS_TEXT \",
    \"timestamp\": \"$(date --date="$(echo "$EVTC_JSON_DATA" | jq -r .timeEnd)" "+%Y-%m-%dT%H:%M:%S.000Z")\",
    \"title\": \"DPS Report ($(echo "$EVTC_JSON_DATA" | jq -r .fightName))\",
    \"url\": \"$DPS_BASE_URL/$OUT_FILE_NAME\"
}]}"

for DISCORD_WEBHOOK_URL in $(echo "$DISCORD_WEBHOOK_URLS" | tr ';' '\n'); do
    curl \
        --silent \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$WEBHOOK_EMBED_CONTENT" \
        "$DISCORD_WEBHOOK_URL"
done

echo $OUT_FILE_NAME > "$PARSED_EVTC_FOLDER/data.txt"

if [ -f "$PARSED_HTML_FOLDER/index.html" ]; then
    exit 0
fi

exit 1
