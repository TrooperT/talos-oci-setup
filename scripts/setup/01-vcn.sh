#!/bin/bash

set +x

base_dir=$(git rev-parse --show-toplevel)
config_file=$base_dir/config.env

echo "Checking for config file"
if [[ -f $config_file ]]; then
	echo "Config file found"
	source $config_file
	echo "Config file loaded"
else
	echo "Config file not found"

fi

# Check for Tenant OCID
if [[ -n "$compartment_id" ]]; then
 	echo "Detected tenancy: $compartment_id"
else
	read -p "Tenancy OCID: " compartment_id
fi

export cidr_block="${cidr_block:=10.0.0.0/16}"
export subnet_block="${subnet_block:=10.0.0.0/24}"
export vcn_name="${vcn_name:=home-labs.dev}"
export subnet_name="${subnet_name:=talos}"

# export compartment_id=<substitute-value-of-compartment_id> 
# https://docs.cloud.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/network/vcn/create.html#cmdoption-compartment-id

echo "Creating VCN"
export vcn_id=$(oci network vcn create --cidr-block $cidr_block --display-name $vcn_name --compartment-id $compartment_id --query data.id --raw-output)

echo "Assigning Subnet"
export rt_id=$(oci network subnet create --cidr-block $subnet_block --display-name $subnet_name --compartment-id $compartment_id --vcn-id $vcn_id --query 'data."route-table-id"' --raw-output)

echo "Creating Internet Gateway"
export ig_id=$(oci network internet-gateway create --compartment-id $compartment_id --is-enabled true --vcn-id $vcn_id --query data.id --raw-output)

echo "Updating Route Table"
oci network route-table update --rt-id $rt_id --route-rules "[{\"cidrBlock\":\"0.0.0.0/0\",\"networkEntityId\":\"$ig_id\"}]" --force

# disable firewall
export sl_id=$(oci network vcn list --compartment-id $compartment_id --query 'data[0]."default-security-list-id"' --raw-output)

echo "Updating Security List"
oci network security-list update --security-list-id $sl_id --egress-security-rules '[{"destination": "0.0.0.0/0", "protocol": "all", "isStateless": false}]' --ingress-security-rules '[{"source": "0.0.0.0/0", "protocol": "all", "isStateless": false}]' --force

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
EOF

cat $config_file

