#!/usr/bin/env bash

MOUNT_MODE='standard'

EC2_AZ=`wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone`

FS_ID=${EFS_ID}

ENDPOINT="${EC2_AZ}.${FS_ID}.efs.${EC2_AZ%?}.amazonaws.com:/"
mkdir -p /mnt/a
case "${MOUNT_MODE}" in
rancheros)
  echo "mounts: [ ['${ENDPOINT}', '${MNT}', 'nfs4', 'nfsvers=4.1,nolock'] ]" | ros config merge
;;
standard)
  echo -n "Mounting ${ENDPOINT} to ${MNT}... "
  rpcbind
  mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${ENDPOINT}" "/mnt/a"
  if [ $? -ne 0 ]; then
    echo "Error"
  else
    echo "Success"
  fi
  mkdir -p /mnt/a/letsencrypt
  umount /mnt/a
  rm -rf /mnt/a
  mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${ENDPOINT}/letsencrypt" "/etc/letsencrypt"
  if [ $? -ne 0 ]; then
    echo "Error"
  else
    echo "Success"
  fi
;;
*)
  echo "Unsupported mount mode ${MOUNT_MODE}"
  echo "Supported mount modes: rancheros, standard"
  exit 1
;;
esac
echo "End of options"


# Validate required environment variables.
[[ -z "$DOMAINS" ]] && MISSING="$MISSING DOMAINS"
[[ -z "$EMAIL" ]] && MISSING="$MISSING EMAIL"
if [[ -n "$MISSING" ]]; then
	echo "Missing required environment variables: $MISSING" >&2
	exit 1
fi

# Wait for HAproxy to start before updating certificates on startup.
# TODO: Use Dockerize, instead of assuming it takes 60 seconds to start.
(sleep 60; /opt/letsencrypt/bin/update-certs.sh) &

exec "$@"