#!/usr/bin/env bash
set -e

# Set default values
: ${GENTOO_ARCH:=amd64}
: ${GENTOO_PROFILE:=""}
: ${GENTOO_PORTAGE:=""}
: ${GENTOO_MIRROR:="http://distfiles.gentoo.org"}

if [ "$( echo ${1} | tr a-z A-Z)" == "HELP" ]; then
	echo " This utility can be configured with a number of options including
	\$GENTOO_ARCH (defaults to amd64)
	\$GENTOO_PROFILE (e.g. nomultilib, hardened, minimal. defaults to nothing)
	\$GENTOO_PORTAGE (include portage? defaults to no)
	\$GENTOO_MIRROR (use alternate mirror. defaults to http://distfiles.gentoo.org)"
fi

# Check for Gentoo profile, if there if a profile, add a "-"
if [ "${GENTOO_PROFILE}x" != "x" ]; then
	GENTOO_PROFILE="-${GENTOO_PROFILE}"
fi

# Import the Gentoo signing keys

# Gentoo-keys team
gpg --recv-key --keyserver hkp://keys.gnupg.net '0x825533CBF6CD6C97'

# Gentoo automated weekly release key
gpg --recv-key --keyserver hkp://keys.gnupg.net '0xBB572E0E2D182910'


# Identify the current Gentoo version
GENTOO_CUR=`curl -s ${GENTOO_MIRROR}/releases/${GENTOO_ARCH}/autobuilds/latest-stage3-${GENTOO_ARCH}${GENTOO_PROFILE}.txt | awk '/stage3/ {print $1}'`

GENTOO_BZIP=${GENTOO_CUR##*/}
GENTOO_TAR=${GENTOO_BZIP%%.bz2}

: ${ACI_NAME:=${GENTOO_TAR%%.tar}}

# Pull down the Gentoo stage3 image

if [ ! -e ${GENTOO_BZIP} ]; then
		echo "Downloading Gentoo Stage 3 (${GENTOO_BZIP})"
		curl -O ${GENTOO_MIRROR}/releases/${GENTOO_ARCH}/autobuilds/current-stage3-${GENTOO_ARCH}${GENTOO_PROFILE}/${GENTOO_BZIP}
		echo "Downloading Gentoo digests"
		curl -O ${GENTOO_MIRROR}/releases/${GENTOO_ARCH}/autobuilds/current-stage3-${GENTOO_ARCH}${GENTOO_PROFILE}/${GENTOO_BZIP}.DIGESTS
		echo "Downloading Gentoo digests (detached signature)"
		curl -O ${GENTOO_MIRROR}/releases/${GENTOO_ARCH}/autobuilds/current-stage3-${GENTOO_ARCH}${GENTOO_PROFILE}/${GENTOO_BZIP}.DIGESTS.asc
fi

# Temporarily change the exit behavior to provide more accurate error messages
set +e
# Validate GPG hashes
echo "Validating GPG signatures of digest hashes"
gpg --verify ${GENTOO_BZIP}.DIGESTS.asc
EXIT_CODE=$?
if [ "${EXIT_CODE}" != "0" ]; then
	echo "Digest file failed GPG validation (Exit code: ${EXIT_CODE})."
	exit ${EXIT_CODE}
fi

# Check to ensure that the images were signed with the proper release key
echo "Validating SHA512 hashes from GPG signed DIGESTS file"
grep -A1 SHA512 ${GENTOO_BZIP}.DIGESTS.asc | awk "/${GENTOO_BZIP}$/ {print \$0}" | sha512sum -c -
EXIT_CODE=$?
if [ "${EXIT_CODE}" != "0" ]; then
	echo "Payload file failed SHA512 validation (Exit code: ${EXIT_CODE})."
	exit ${EXIT_CODE}
fi

set -e
# If the rootfs does not exist, then explode the corresponding tarball
# and install the Gentoo portage tree into the correct location

if [ ! -d "rootfs" ]; then

	echo "Creating rootfs"
	mkdir -p rootfs

	set +e
	echo "Exploding stage3 to rootfs"
	tar jxpf ${GENTOO_BZIP} -C rootfs --xattrs
	set -e
	mkdir -p rootfs/usr/portage
	if [ "${GENTOO_PORTAGE}x" != "x" ]; then
		echo "Performing rsync of portage tree"
		rsync -az rsync://rsync.us.gentoo.org/gentoo-portage rootfs/usr/portage/
		echo "Completed rsync of portage tree"
	else
		echo "Skipping sync of portage tree. Set environment variable GENTOO_PORTAGE= to a non empty value to sync."
	fi
else
	echo "Directory rootfs already exists.  Content may be out of sync."
fi

# Begin operations to finish packaging our assets into ACI format
echo "Writing ACI manifest"
echo "{\"acKind\":\"ImageManifest\",\"acVersion\":\"0.7.4\",\"name\":\"${ACI_NAME}\",\"labels\":[{\"name\":\"os\",\"value\":\"linux\"},{\"name\":\"arch\",\"value\":\"${GENTOO_ARCH}\"}],\"app\":{\"exec\":[\"/bin/bash\"],\"environment\":[{\"name\":\"TERM\",\"value\":\"linux\"},{\"name\":\"LANG\",\"value\":\"en_US.UTF-8\"}],\"user\":\"0\",\"group\":\"0\"}}" > manifest

echo "Building ACI image"
tar Jcpf ${GENTOO_TAR%%.tar}.aci --xattrs rootfs manifest

echo "Built Image ${GENTOO_TAR%%.tar}.aci"


# some common packages needed to build subsequent packages include:
# dev-vcs/git
# sys-devel/bc
# app-arch/cpio
