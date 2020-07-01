#!/bin/bash
DEFULT_ENV=.env
# TODO args?
ENV=$1
ENV_FILE=$ENV.env
TEMP_ENV_FILE=$(mktemp)
shift
if [[ -f "$DEFULT_ENV" ]]; then
    echo "Load env from: $DEFULT_ENV"
    cat ".env" >> "$TEMP_ENV_FILE"
    echo >> "$TEMP_ENV_FILE"
fi
if [[ -f "$ENV_FILE" ]]; then
    echo "Load env from: $ENV_FILE"
    cat "$ENV_FILE" >> "$TEMP_ENV_FILE"
    echo >> "$TEMP_ENV_FILE"
fi
cat "$TEMP_ENV_FILE"
if [[ -s "$TEMP_ENV_FILE" ]]; then
    TEMP_ENV_FILE2=$(mktemp)
    echo "Load env from: $TEMP_ENV_FILE"
    echo "# temp env" > "$TEMP_ENV_FILE2"
    while read line; do
        if [[ "$line" = "#"* ]]; then continue; fi
        b=$(echo "$line" | cut -d = -f2-)
        if [[ "$b" == "" ]]; then continue; fi
        a=$(echo "$line" | cut -d = -f1)
        echo "export $a=\${$a-$b}" >> "$TEMP_ENV_FILE2"
    done < "$TEMP_ENV_FILE"
    source "$TEMP_ENV_FILE2" || exit 1
    rm "$TEMP_ENV_FILE2"
fi
rm "$TEMP_ENV_FILE"
env | grep K8S
K8S_TEMPLATE=${K8S_TEMPLATE-"template.*.yaml"}
K8S_MANIFEST=${K8S_MANIFEST-"manifest.*.yaml"}
TPL_PREFIX=$(echo "$K8S_TEMPLATE" | cut -d '*' -f1)
TPL_SUFFIX=$(echo "$K8S_TEMPLATE" | cut -d '*' -f2)
GEN_PREFIX=$(echo "$K8S_MANIFEST" | cut -d '*' -f1)
GEN_SUFFIX=$(echo "$K8S_MANIFEST" | cut -d '*' -f2)
if [[ "$K8S_MANIFEST_PATH" == "" ]]; then
    export K8S_MANIFEST_PATH=.
fi
echo "Manifest file path: $K8S_MANIFEST_PATH"
for src in $K8S_TEMPLATE; do
    dst=$src
    dst=${dst/$TPL_PREFIX/$GEN_PREFIX}
    dst=${dst/$TPL_PREFIX/$GEN_PREFIX}
    echo "envsubst $src -> $dst"
    cat "$src" | envsubst > "$K8S_MANIFEST_PATH/$dst" || exit 1
done
SKAFFOLD_TEMPLATE=$K8S_MANIFEST_PATH/${GEN_PREFIX}skaffold${GEN_SUFFIX}
if [[ -f "$SKAFFOLD_TEMPLATE" ]]; then
    echo "Deploying using Skaffold, file: $SKAFFOLD_TEMPLATE"
    if [[ "$SKAFFOLD_TEMPLATE" != "skaffold.yaml" ]]; then
        cp "$SKAFFOLD_TEMPLATE" "skaffold.yaml" || exit 1
    fi
    skaffold $@ || exit 1
else
    echo "Deploying using kubectl, files: ${GEN_PREFIX}*${GEN_SUFFIX}"
    cat ${GEN_PREFIX}*${GEN_SUFFIX} | kubectl apply -f - 
fi
