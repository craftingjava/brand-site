#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: ${0} <profile_name>"
    exit 1
fi

profile_name=$1
profile_file=".profile-${profile_name}"

if [ ! -f ${profile_file} ]; then
  echo "Profile descriptor ${profile_file} doesn't exist."
  exit 1
fi

profile_data=$(egrep -v "^#|^$" ${profile_file} | head -1)

project_id=$(echo ${profile_data} | cut -d':' -f1)
db_region=$(echo ${profile_data} | cut -d':' -f2)
db_instance=$(echo ${profile_data} | cut -d':' -f3)
db_name=$(echo ${profile_data} | cut -d':' -f4)
db_password=$(echo ${profile_data} | cut -d':' -f5)

build_dir="build"
local_db="wp_${db_instance}"

build() {
    mkdir -p ${build_dir}

    php wordpress-helper.php setup \
        --no-interaction \
        --env=s \
        --dir=${build_dir} \
        --sql_gen=2 \
        --project_id=${project_id} \
        --db_region=${db_region} \
        --db_instance=${db_instance} \
        --db_name=${db_name} \
        --db_user=root \
        --db_password=${db_password} \
        --local_db_user=${local_db} \
        --local_db_password=${local_db}

    for plugin_url in $(cat plugins.txt); do
        echo "Downloading plugin ${plugin_url}..."
        plugin=$(mktemp)
        wget ${plugin_url} -O ${plugin}
        unzip -oq -d ${build_dir}/wordpress/wp-content/plugins ${plugin}
        rm -f ${plugin}
    done

	unzip -q rise-1.200.27.zip -d build/wordpress/wp-content/themes
}

deploy() {
    gcloud config set project ${project_id}

    gsutil defacl ch -u AllUsers:R "gs://${project_id}.appspot.com"

    gcloud app deploy --promote --stop-previous-version \
        ${build_dir}/app.yaml ${build_dir}/cron.yaml
}

clean() {
    if [ -d "${build_dir}" ]; then
        rm -rf ${build_dir}
    fi
}

cmd=$0

case "${cmd}" in
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
