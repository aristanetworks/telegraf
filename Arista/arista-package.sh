#!/usr/bin/env bash

. ./tools2-functions

#redefine cleanup_exit
cleanup_exit() {
    OK=${1:-1}
    rm -rf $TMP_BIN_DIR > /dev/null 2>&1
    rm -rf $TMP_CONFIG_DIR > /dev/null 2>&1
    rm -rf ./*.rpm > /dev/null 2>&1
    exit $OK
}

check_linux
check_gopath
check_fpm

ARCH=x86_64
GOBIN=$GOPATH/bin
TMP_BIN_DIR=./rpm_bin
TMP_CONFIG_DIR=./rpm_config
CONFIG_FILES_DIR=./ConfigFiles

LINUX_CONFIG_FILES_VER=1.7
REDIS_CONFIG_FILES_VER=1.8
PERFORCE_CONFIG_FILES_VER=1.7
SWIFT_CONFIG_FILES_VER=1.2
QUBIT_SCYLLA_CONFIG_FILES_VER=1.8
QUBIT_SCYLLA_DEV_CONFIG_FILES_VER=1.1
QUBIT_WORKER_CONFIG_FILES_VER=1.7
QUBIT_SPIN_CONFIG_FILES_VER=1.7

CONFIG_FILES_ITER=14
BIN_RPM_ITER=2

LICENSE=MIT
URL=github.com/aristanetworks/telegraf
DESCRIPTION="InfluxDB Telegraf agent"
VENDOR=Influxdata

set -e

# Get version from tag closest to HEAD
# this is based on the upstream telegraf version
# BIN_RPM_ITER accounts for any updates to telegraf that we do in our repo
version=$(git describe --tags --abbrev=0 | sed 's/^v//' )

# Build and install the latest code
echo "Building and Installing telegraf"
make -C ../
#make -C ../ test-short

echo "Creating RPMS"

# Cleanup old RPMS
mkdir ./RPMS > /dev/null 2>&1 || rm -rf ./RPMS/*
rm ./*.rpm > /dev/null 2>&1  || true

COMMON_FPM_ARGS="\
--log error \
--vendor $VENDOR \
--url $URL \
--license $LICENSE"

# Create Binary RPMS
BINARY_FPM_ARGS="\
 -C $TMP_BIN_DIR \
--prefix / \
-a $ARCH \
-v $version \
--iteration $BIN_RPM_ITER \
$COMMON_FPM_ARGS"

# Make a copy of the generated binaries into a tmp directory bin
echo "Seting up temporary bin directory"
mkdir $TMP_BIN_DIR > /dev/null 2>&1 || rm -rf $TMP_BIN_DIR/*
mkdir -p $TMP_BIN_DIR/usr/bin/
for binary in "telegraf"
do
    cp $GOBIN/$binary $TMP_BIN_DIR/usr/bin/
done

# Add a default telegraf configig
mkdir -p $TMP_BIN_DIR/etc/telegraf/
cp $CONFIG_FILES_DIR/telegraf-default.conf $TMP_BIN_DIR/etc/telegraf/telegraf.conf

fpm -s dir -t rpm $BINARY_FPM_ARGS --description "$DESCRIPTION" -n "telegraf" . || cleanup_exit 1

mv ./*.rpm RPMS

# Create Config RPMS
CONFIG_FPM_ARGS="\
-C $TMP_CONFIG_DIR \
--prefix / \
-a noarch \
-d telegraf \
--config-files /etc/telegraf/ \
--after-install ./post_install_config.sh \
--after-remove ./post_uninstall_config.sh \
$COMMON_FPM_ARGS"

# Create directory structure for config files
echo "Setting up temporary config file tree"
mkdir $TMP_CONFIG_DIR > /dev/null 2>&1 || rm -rf $TMP_CONFIG_DIR/*
mkdir -p $TMP_CONFIG_DIR/etc/default
cp $CONFIG_FILES_DIR/telegraf.default $TMP_CONFIG_DIR/etc/default/telegraf
mkdir -p $TMP_CONFIG_DIR/etc/logrotate.d
cp $CONFIG_FILES_DIR/telegraf.logrotate $TMP_CONFIG_DIR/etc/logrotate.d/telegraf
mkdir -p $TMP_CONFIG_DIR/lib/systemd/system
cp $CONFIG_FILES_DIR/telegraf-dhclient.service $TMP_CONFIG_DIR/lib/systemd/system/
cp $CONFIG_FILES_DIR/telegraf-networkd.service $TMP_CONFIG_DIR/lib/systemd/system/
# To ensure telegraf.service is removed when the rpm itself is removed/uninstalled.
cp $CONFIG_FILES_DIR/telegraf-networkd.service $TMP_CONFIG_DIR/lib/systemd/system/telegraf.service
mkdir -p $TMP_CONFIG_DIR/etc/telegraf
mkdir -p $TMP_CONFIG_DIR/etc/telegraf/telegraf.d

# Linux-Config
rm -f $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-linux.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$LINUX_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-Linux" etc lib || cleanup_exit 1

# Redis-Config
rm -f $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-redis.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$REDIS_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-Redis" etc lib || cleanup_exit 1

# Perforce-Config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-perforce.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$PERFORCE_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-Perforce" etc lib || cleanup_exit 1

# Swift-Config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-swift.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$SWIFT_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-Swift" etc lib || cleanup_exit 1

# QUBIT Scylla config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-qubit-scylla.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$QUBIT_SCYLLA_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-qubit-scylla" etc lib || cleanup_exit 1

# QUBIT Scylla dev config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-qubit-scylla-dev.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$QUBIT_SCYLLA_DEV_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-qubit-scylla-dev" etc lib || cleanup_exit 1


# QUBIT Worker config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-qubit-worker.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$QUBIT_WORKER_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-qubit-worker" etc lib || cleanup_exit 1

# QUBIT Spin config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-qubit-spin.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --iteration "$CONFIG_FILES_ITER" -v "$QUBIT_SPIN_CONFIG_FILES_VER" --description "$DESCRIPTION" -n "telegraf-qubit-spin" etc lib || cleanup_exit 1


mv ./*.rpm RPMS

echo "Created RPMS"
ls -l RPMS | awk '{print($9);}'
cleanup_exit 0
