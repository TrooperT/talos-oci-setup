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

# Download disk image from Talos Image factory
echo "Downloading Talos disk image"
export TMPDIR=$(mktemp -d -p $base_dir)
docker run --rm -it -v $TMPDIR:/downloads --name qemu alpine:3.20 /bin/sh -c \
"apk add qemu-img xz wget && \
wget https://factory.talos.dev/image/7d4c31cbd96db9f90c874990697c523482b2bae27fb4631d5583dcd9c281b1ff/v1.7.5/oracle-arm64.raw.xz -O /downloads/talos-1.7.5-oracle-arm64.raw.xz && \
rm -v /downloads/talos-1.7.5-oracle-arm64.raw||true && \
ls -lah /downloads && \
unxz /downloads/talos-1.7.5-oracle-arm64.raw.xz && \
qemu-img info /downloads/talos-1.7.5-oracle-arm64.raw && \
qemu-img convert -f raw -O qcow2 /downloads/talos-1.7.5-oracle-arm64.raw /downloads/talos-1.7.5-oracle-arm64.qcow2 && \
qemu-img info /downloads/talos-1.7.5-oracle-arm64.qcow2"


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
# Stage 4: WIP
EOF

cat $config_file
