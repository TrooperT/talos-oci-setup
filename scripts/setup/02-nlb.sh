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

# Find subnet
export subnet_id=$(oci network subnet list --compartment-id=$compartment_id --display-name $subnet_name --query data[0].id --raw-output)

# Create Public IP Reservation
echo "Creating Loadbalancer IP Reservation"
export reservation_id=$(oci network public-ip create --compartment-id $compartment_id --displayname controlplane-lb --lifetime reserved --query data.id --raw-output)

# Create Network Load Balancer
echo "Creating Network Loadbalancer"
export network_load_balancer_id=$(oci nlb network-load-balancer create --compartment-id $compartment_id --display-name controlplane-lb --subnet-id $subnet_id --is-preserve-source-destination false --is-private false --reserved-ips "[{\"id\":\"$reservation_id\"}]" --query data.id --raw-output)

# Define Talos API healthcheck
cat <<EOF > talos-health-checker.json
{
  "intervalInMillis": 10000,
  "port": 50000,
  "protocol": "TCP"
}
EOF

# Create Loadbalancer backend-set with healthcheck
echo "Creating NLB Backend set for Talos API"
oci nlb backend-set create --health-checker file://talos-health-checker.json --name talos --network-load-balancer-id $network_load_balancer_id --policy TWO_TUPLE --is-preserve-source false

# Create Loadbalancer listener
echo "Creating NLB Listener for Talos API"
oci nlb listener create --default-backend-set-name talos --name talos --network-load-balancer-id $network_load_balancer_id --port 50000 --protocol TCP

# Define Kubernetes API healthcheck
cat <<EOF > controlplane-health-checker.json
{
  "intervalInMillis": 10000,
  "port": 6443,
  "protocol": "HTTPS",
  "returnCode": 401,
  "urlPath": "/readyz"
}
EOF

# Create Loadbalancer backend-set with healthcheck
echo "Creating NLB Backend set for Kubernetes API"
oci nlb backend-set create --health-checker file://controlplane-health-checker.json --name controlplane --network-load-balancer-id $network_load_balancer_id --policy TWO_TUPLE --is-preserve-source false

# Create Loadbalancer listener
echo "Creating NLB Listener for Kubernetes API"
oci nlb listener create --default-backend-set-name controlplane --name controlplane --network-load-balancer-id $network_load_balancer_id --port 6443 --protocol TCP

# Save the external IP
export network_load_balancer_ip=$(oci nlb network-load-balancer list --compartment-id $compartment_id --display-name controlplane-lb --query 'data.items[0]."ip-addresses"')

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
EOF

cat $config_file
