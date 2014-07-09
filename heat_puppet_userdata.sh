#!/bin/bash
#
# This script is intended to be a generic script that can
# be used to perform configuration using master-less-puppet
# (ie: puppet apply)
#

set -x

# install puppet
apt-key adv --recv-key --keyserver pool.sks-keyservers.net 4BD6EC30
echo "deb http://apt.puppetlabs.com precise main" > /etc/apt/sources.list.d/puppetlabs.list
echo "deb http://apt.puppetlabs.com precise dependencies" >> /etc/apt/sources.list.d/puppetlabs.list
apt-get update
apt-get -y install puppet ruby1.9.1-full git rubygems vim
update-alternatives --set ruby /usr/bin/ruby1.9.1
update-alternatives --set gem /usr/bin/gem1.9.1
# install librarian-puppet-simple. I would be using r10k, but it just seemed to result
# in stack traces, happy to switch once I can get it working
gem install librarian-puppet-simple

#
# This script is based on the idea that it should refer to a Puppet project (essentially an
# artifact with a Puppetfile and a manifests directory with site.pp)
#
TMP_PATH=`mktemp -d`
git clone $PUPPET_REPO $TMP_PATH

# put the Puppetfile into the system location
cp $TMP_PATH/Puppetfile /etc/puppet/Puppetfile
# install Puppet modules (and what-not)
cd /etc/puppet
librarian-puppet install --verbose

# install pip. This should definitely not be happening here, but it is. Get
# over it.
PIP_GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py;curl -O $PIP_GET_PIP_URL || wget $PIP_GET_PIP_URL;python get-pip.py
easy_install --upgrade pip

# setup hiera data
# this template assumes that hiera data is stored in the data dir
# and that hiera.yaml maps it's yaml datadir to that directory.
# it also assumes that user.yaml can override the bits that need to
# be customized for this project
if [ -d $TMP_PATH/hiera ]; then
  cp $TMP_PATH/hiera/hiera.yaml /etc/puppet/hiera.yaml
  mkdir -p /etc/puppet/hieradata
  if [ -d $TMP_PATH/hiera/data ]; then
    cp -Rvf $TMP_PATH /etc/puppet/hiera/data/ /etc/puppet/hieradata
  fi
  # write in the hiera file with our user hiera data (which should be used to store secrets)
cat <<EOF > /etc/puppet/hieradata/user.yaml
$USER_HIERA_YAML
EOF
fi
# write connection specific overrides
cat <<EOF >> /etc/puppet/hieradata/user.yaml
$CONNECTION_HIERA_OVERRIDES
EOF

echo $VAR

# export all facts specified in FACTS parameter
for i in $(echo "$FACTS" | tr -d ' ' | tr ";" "\n")
do
  export FACTER_${i}
done

puppet apply $TMP_PATH/manifests/site.pp --modulepath=/etc/puppet/modules
