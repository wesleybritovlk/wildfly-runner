#!/bin/bash
prepare_runtime() {
    local name=$1
    local xml_path=$2
    local wf_base=$3
    local r_dir="/tmp/wf-run/$name"
    rm -rf "$r_dir"
    mkdir -p "$r_dir"/{deployments,log,data,tmp}
    cp -r "$wf_base/standalone/configuration" "$r_dir/"
    cp "$xml_path" "$r_dir/configuration/standalone.xml"
    sed -i '/<deployments>/,/<\/deployments>/d' "$r_dir/configuration/standalone.xml"
    echo "$r_dir"
}