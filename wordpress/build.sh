#!/bin/bash

if [ $# -lt 4 ]; then
    echo "Usage: ${0} <site_name> <project_id> <db_name> <db_password>"
    exit 1
fi

site_name=$1
project_id=$2
db_name=$3
db_password=$4

build_dir="build"
local_db="wp_${site_name}"

build() {
    mkdir -p $build_dir

    php wordpress-helper.php setup \
        --no-interaction \
        --env=s \
        --dir=$build_dir \
        --sql_gen=2 \
        --project_id=$project_id \
        --db_region=europe-west1 \
        --db_instance=$site_name \
        --db_name=$db_name \
        --db_user=root \
        --db_password=$db_password \
        --local_db_user=$local_db \
        --local_db_password=$local_db

    for plugin_url in $(cat plugins.txt); do
        echo "Downloading plugin ${plugin_url}..."
        plugin=$(mktemp)
        wget $plugin_url -O $plugin
        unzip -oq -d $build_dir/wordpress/wp-content/plugins $plugin
        rm -f $plugin
    done

	unzip -q rise-1.200.27.zip -d build/wordpress/wp-content/themes
}

deploy() {
    gcloud config set project $project_id

    gsutil defacl ch -u AllUsers:R "gs://${project_id}.appspot.com"

    gcloud app deploy --promote --stop-previous-version \
        $build_dir/app.yaml $build_dir/cron.yaml
}

clean() {
    if [ -d "$build_dir" ]; then
        rm -rf $build_dir
    fi
}

cmd=$0

case "$cmd" in
    build*)
        build
        ;;
    deploy*)
        deploy
        ;;
    clean*)
        clean
        ;;
    install*)
        build
        deploy
        clean
        ;;
    *)
        echo "Unrecognized command ${cmd}"
        ;;
esac
