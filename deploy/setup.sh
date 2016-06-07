#!/bin/bash

# Exit early if any of the commands fails
set -e

# Fetch the latest package lists and upgrade any previously installed
# packages.
sudo apt-get update
sudo apt-get -y upgrade

# Enable unattended-upgrades to install essential security updates
# nightly.
cat <<EOF > /tmp/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

sudo mv /tmp/20auto-upgrades /etc/apt/apt.conf.d

# Libraries required to build Ruby
sudo apt-get -y install autoconf bison build-essential libssl-dev \
     libreadline-dev zlib1g-dev libgdbm-dev

# Download Ruby source code
cd $HOME
wget https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.1.tar.gz
tar zxf ruby-2.3.1.tar.gz
cd ruby-2.3.1/

# Compile and install Ruby system-wide
./configure --disable-install-doc
make
sudo make install

# Clean up build artifacts after installed
cd $HOME
rm -rf ruby-2.3.1 ruby-2.3.1.tar.gz

# Use bundler to bootstrap gem installs
sudo gem install --no-document bundler

# This is the directory where the application source will live. Assume
# that the application tarball was uploaded to /tmp/zero.tar
sudo mkdir -p /srv/zero
sudo mv /tmp/zero.tar /srv/zero/zero.tar

cd /srv/zero
sudo tar xf zero.tar
sudo rm zero.tar

# These libraries are necessary for building native gem extensions
sudo apt-get install -y libpq-dev nodejs

# Install and build gems
sudo bundle install --deployment --without development test

# Precompile assets
sudo RAILS_ENV=production bundle exec rake assets:precompile

# Create application user
sudo adduser --system --group --no-create-home --gecos '' zero

# root will still own the files, but add the application user's group
sudo chown -R root:zero /srv/zero

# Remove world read-write and group write access to the source
sudo chmod -R o-rwx /srv/zero
sudo chmod -R g-w /srv/zero

# Allow everyone to view the top-level directory (but not any files).
sudo chmod o+rx /srv/zero
sudo chmod -R o+r /srv/zero/public

# Create our new temp directory
sudo mkdir -p /var/tmp/zero
sudo chown zero /var/tmp/zero

# Remove the existing temp directory, then replace it with a symlink
sudo rm -rf /srv/zero/tmp
sudo ln -s /var/tmp/zero/ /srv/zero/tmp

# Provide a dummy log file. The actual logs will be capture from
# STDOUT and written to /var/log/upstart/zero.log
sudo ln -s /dev/null /srv/zero/log/production.log

# Copy secrets file. Assume file was uploaded to /tmp/.env
sudo mv /tmp/.env /srv/zero/.env
sudo chown root:zero /srv/zero/.env
sudo chmod 440 /srv/zero/.env

# Start application service
sudo cp /srv/zero/deploy/upstart.conf /etc/init/zero.conf
sudo start zero

# Configure nginx web server as reverse proxy
sudo apt-get -y install nginx

sudo rm -f /etc/nginx/sites-enabled/default
sudo cp /srv/zero/deploy/nginx.conf /etc/nginx/sites-available/zero
sudo ln -sf /etc/nginx/sites-available/zero /etc/nginx/sites-enabled/zero

sudo service nginx restart
