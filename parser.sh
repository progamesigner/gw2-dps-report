#!/bin/sh
#
# parser <evtc file path> <evtc file name>
#

# get arguments
EVTC_FILE_PATH="$1"
EVTC_FILE_NAME="$2"

PARSED_EVTC_FOLDER="$(dirname "$EVTC_FILE_PATH")"

# parse evtc file with GW2EI
mono GuildWars2EliteInsights.exe -p -c settings.conf "$EVTC_FILE_PATH"

# find generated file paths
for path in $PARSED_EVTC_FOLDER/*; do
    case "$path" in
        *.html) PARSED_HTML_PATH="$path";;
        *.json) PARSED_JSON_PATH="$path";;
    esac
done

# copy generated files to destination
OUTPUT_FILE_NAME="$(jq --raw-output --arg name "$EVTC_FILE_NAME" '[$name, .arcVersion, .fightName, .recordedBy] | join(":")' "$PARSED_JSON_PATH" | sha256sum - | cut -d ' ' -f1 | cut -c1-12)"
OUTPUT_FILE_PATH="$FILE_BASE_PATH/evtc-$OUTPUT_FILE_NAME"

mkdir -p "$OUTPUT_FILE_PATH"
cp "$PARSED_HTML_PATH" "$OUTPUT_FILE_PATH/index.html"
cp "$PARSED_JSON_PATH" "$OUTPUT_FILE_PATH/data.json"

sed -i \
    "s/<\/head>/<title>$(jq --raw-output '.targets[0].name' "$PARSED_JSON_PATH")<\/title><\/head>/" \
    "$OUTPUT_FILE_PATH/index.html"

# pass parser result for server
jq \
    --compact-output \
    --raw-output \
    --sort-keys \
    --arg name "$OUTPUT_FILE_NAME" \
    '
.recordedBy as $recorder |
{
    name: $name,
    arcVersion: .arcVersion,
    eiVersion: .eliteInsightsVersion,
    fightName: .fightName,
    fightStart: (
        try (
            .timeStart |
            strptime("%Y-%m-%d %H:%M:%S %Z") |
            strftime("%Y-%m-%dT%H:%M:%S.000Z")
        ) catch (
            now |
            strftime("%Y-%m-%dT%H:%M:%S.000Z")
        )
    ),
    fightEnd: (
        try (
            .timeEnd |
            strptime("%Y-%m-%d %H:%M:%S %Z") |
            strftime("%Y-%m-%dT%H:%M:%S.000Z")
        ) catch (
            now |
            strftime("%Y-%m-%dT%H:%M:%S.000Z")
        )
    ),
    fightDuration: .duration,
    recorderName: $recorder,
    recorderProfession: (
        .players |
        map(select(.character == $recorder)) |
        .[] |
        .profession
    ),
    isSuccess: .success
}
    ' "$PARSED_JSON_PATH" > "$PARSED_EVTC_FOLDER/data.json"

# check result and exit
if [ -f "$PARSED_EVTC_FOLDER/data.json" -a -f "$OUTPUT_FILE_PATH/index.html" -a -f "$OUTPUT_FILE_PATH/data.json" ]; then
    exit 0
fi
exit 1
