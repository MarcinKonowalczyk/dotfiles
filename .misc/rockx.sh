#!/usr/bin/env bash
# spellchecker: words rockx

INPUT="$1"
[ -z "$INPUT" ] && INPUT=$(find . -maxdepth 1 -type f -name "*.rock" | fzf)
[ -z "$INPUT" ] && exit 1

# make sure we end with .rock
if [[ "$INPUT" != *.rock ]]; then
    echo "Selected file is not a .rock package."
    exit 1
fi

INPUT=$(realpath "$INPUT")

DIR="$(echo "${INPUT%.rock}")"
if [ -d "$DIR" ]; then
    # confirm if we want to remove the existing directory
    read -p "Directory '$DIR' already exists. Do you want to continue? ([Y]/n): " -n 1 -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

rm -rf "${DIR:-}"

mkdir "$DIR"
(
    cd "$DIR" || exit 1

    podman run --name=rockx --replace oci-archive:"$INPUT" &>/dev/null &
    echo $! >.pid

    # Wait for the container to start
    echo "waiting for a temp container to start..."
    id=$(podman ps --filter 'name=rockx' --format "{{.ID}}")
    while [ -z "$id" ]; do
        sleep 1
        id=$(podman ps --filter 'name=rockx' --format "{{.ID}}")
    done

    echo "Container started with ID: $id"

    TAR=$(mktemp --suffix=.tar)
    podman export "$id" -o "$TAR"
    kill -s SIGINT "$(cat .pid)"
    rm .pid
    echo "Container exported to '$TAR' and stopped."

    if [ -f "$TAR" ]; then
        tar -xf "$TAR" -C "$DIR"
        rm "$TAR"
    else
        echo "No export.tar found in the package."
        exit 1
    fi

)

echo "Package extracted to '$DIR'."
exit 0
