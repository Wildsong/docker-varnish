#
#   This creates a local volume that accesses data on a Windows server.
#

# Read the secrets file to get server,username,password
. ~/.smbcredentials

# NGINX runs in the container as a service user so its UID does not matter
# and we only care about having read access to the files so we leave them
# set to default UID/GID here (0=root) and make them world readable

function makevol () {
  vol=$1
  mount=$2

  docker volume create --driver local --name $vol --opt type=cifs \
    --opt device=//${server}/${mount} \
    --opt o=ro,addr=${server},username=${username},password=${password},file_mode=0755,dir_mode=0755
  docker volume inspect $vol
  if [ $? -eq 0 ]; then
    echo test
    # Test!!  There should files in there. This creates a volume if it does not exist!!
    docker run -ti --rm -v $vol:/cache:rw debian:11 ls -l /cache
  fi
}

# Note these are READ ONLY. (o=ro)

makevol cifs_bridges "Applications/GIS/PublicWorks/bridgeimages"
makevol cifs_waterway "Applications/GIS/Planning/waterway/photos"

# currently, surveys are served by Delta
#####makevol cifs_surveys "Applications/GIS/PublicWorks/Survey"

