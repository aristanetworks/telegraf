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
GOBIN=../
TMP_BIN_DIR=./rpm_bin
TMP_CONFIG_DIR=./rpm_config
CONFIG_FILES_DIR=./ConfigFiles

LICENSE=MIT
URL=github.com/aristanetworks/telegraf
TELEGRAF_UPSTREAM_VERSION="v1.2.0-823-g89c596cf"
DESCRIPTION="InfluxDB Telegraf agent version: $TELEGRAF_UPSTREAM_VERSION"
VENDOR=Influxdata

set -e

# It's common practice to use a 'v' prefix on tags, but the prefix should be
# removed when making the RPM version string.
#
# Use "git describe" as the basic RPM version data.  If there are no tags
# yet, simulate a v0 tag on the initial/empty repo and a "git describe"-like
# tag (eg v0-12-gdeadbee) so there's a legitimate, upgradeable RPM version.
#
# Include "-dirty" on the end if there are any uncommitted changes.
#
# Replace hyphens with underscores; RPM uses them to separate version/release.
git_ver=$(git describe --dirty --match "v[0-9]*-ar" 2>/dev/null || echo "v0-`git rev-list --count HEAD`-g`git describe --dirty --always`")
version=$(echo "$git_ver" | sed -e "s/^v//" -e "s/-/_/g")
echo "Version, $version"

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
--after-install ./post_install_config.sh \
--after-remove ./post_uninstall_config.sh \
$COMMON_FPM_ARGS"

# Make a copy of the generated binaries into a tmp directory bin
echo "Seting up temporary bin directory"
mkdir $TMP_BIN_DIR > /dev/null 2>&1 || rm -rf $TMP_BIN_DIR/*
mkdir -p $TMP_BIN_DIR/usr/bin/
for binary in "telegraf"
do
    cp $GOBIN/$binary $TMP_BIN_DIR/usr/bin/
done

# Add a default telegraf config
mkdir -p $TMP_BIN_DIR/etc/telegraf/
cp $CONFIG_FILES_DIR/telegraf-default.conf $TMP_BIN_DIR/etc/telegraf/telegraf.conf

# copy service file
mkdir -p $TMP_BIN_DIR/lib/systemd/system
cp $CONFIG_FILES_DIR/telegraf-dhclient.service $TMP_BIN_DIR/lib/systemd/system/
cp $CONFIG_FILES_DIR/telegraf-networkd.service $TMP_BIN_DIR/lib/systemd/system/
# To ensure telegraf.service is removed when the rpm itself is removed/uninstalled.
cp $CONFIG_FILES_DIR/telegraf-networkd.service $TMP_BIN_DIR/lib/systemd/system/telegraf.service

fpm -s dir -t rpm $BINARY_FPM_ARGS --description "$DESCRIPTION" -n "telegraf" usr etc lib || cleanup_exit 1

mv ./*.rpm RPMS

# Create Config RPMS
CONFIG_FPM_ARGS="\
-C $TMP_CONFIG_DIR \
--prefix / \
-a noarch \
-d telegraf \
--config-files /etc/telegraf/ \
-v $version \
$COMMON_FPM_ARGS"

mkdir $TMP_CONFIG_DIR > /dev/null 2>&1 || rm -rf $TMP_CONFIG_DIR/*
mkdir -p $TMP_CONFIG_DIR/etc/telegraf
mkdir -p $TMP_CONFIG_DIR/etc/telegraf/telegraf.d

# Redis-Config
rm -f $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-redis.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --description "$DESCRIPTION" -n "telegraf-Redis" etc || cleanup_exit 1

# Perforce-Config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-perforce.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --description "$DESCRIPTION" -n "telegraf-Perforce" etc || cleanup_exit 1

# Swift-Config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-swift.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --description "$DESCRIPTION" -n "telegraf-Swift" etc || cleanup_exit 1

# Varnish config
rm -rf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/*
cp $CONFIG_FILES_DIR/telegraf-varnish.conf $TMP_CONFIG_DIR/etc/telegraf/telegraf.d/
fpm -s dir -t rpm $CONFIG_FPM_ARGS --description "$DESCRIPTION" -n "telegraf-varnish" etc || cleanup_exit 1

mv ./*.rpm RPMS

echo "Created RPMS"
ls -l RPMS | awk '{print($9);}'
cleanup_exit 0
