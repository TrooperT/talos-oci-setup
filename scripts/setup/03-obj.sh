#!/bin/bash

set +x

base_dir=$(git rev-parse --show-toplevel)
config_file=$base_dir/config.env

echo "Checking for config file"
if [[ -f $config_file ]]; then
	echo "Config file found"
	source $config_file
	echo "Config file loaded"
fi

# NOTE: By this step we expect compartment_id to be set by config file
# Set Compartment
# export compartment_id=<OCID goes here>

export object_namespace=$(oci os ns get --query data --raw-output)
export object_bucket_name=talos-images
export object_bucket_id=$(oci os bucket create --compartment-id $compartment_id --name $object_bucket_name --namespace-name $object_namespace --query data.id --raw-output)
# For future use during teardown phase
# oci os bucket delete --bucket-name $object_bucket_name --namespace-name $object_namespace --force

echo "Config file:"
cat <<EOF > $config_file
# Stage 1
export vcn_id=$vcn_id
export vcn_name=$vcn_name
export compartment_id=$compartment_id
export subnet_name=$subnet_name
export cidr_block=$cidr_block
export subnet_block=$subnet_block
export rt_id=$rt_id
export ig_id=$ig_id
export sl_id=$sl_id
# Stage 2
export network_load_balancer_id=$network_load_balancer_id
export network_load_balancer_ip=$network_load_balancer_ip
# Stage 3
export object_namespace=$object_namespace
export object_bucket_name=$object_bucket_name
export object_bucket_id=$object_bucket_id
EOF

cat $config_file
