#!/bin/bash

setsebool -P -N use_nfs_home_dirs=1 unconfined_mozilla_plugin_transition=0

rpm-ostree override remove nano-default-editor

# run scripts
echo "-- Running scripts defined in recipe.yml --"
buildscripts=$(yq '.scripts[]' < /usr/etc/ublue-recipe.yml)
for script in $(echo -e "$buildscripts"); do \
    echo "Running: ${script}" && \
    /tmp/scripts/$script; \
done
echo "---"

repos=$(yq '.extrarepos[]' < /usr/etc/ublue-recipe.yml)
if [[ -n "$repos" ]]; then
    echo "-- Adding repos defined in recipe.yml --"
    for repo in $(echo -e "$repos"); do \
        wget $repo -P /etc/yum.repos.d/; \
    done
    echo "---"
fi

echo "-- Installing RPMs defined in recipe.yml --"
rpm_packages=$(yq '.rpms[]' < /usr/etc/ublue-recipe.yml)
for pkg in $(echo -e "$rpm_packages"); do \
    echo "Installing: ${pkg}" && \
    rpm-ostree install $pkg; \
done
echo "---"

# install yafti to install flatpaks on first boot, https://github.com/ublue-os/yafti
pip install --prefix=/usr yafti

# add a package group for yafti using the packages defined in recipe.yml
flatpaks=$(yq '.flatpaks[]' < /tmp/ublue-recipe.yml)
# only try to create package group if some flatpaks are defined
if [[ -n "$flatpaks" ]]; then
    yq -i '.screens.applications.values.groups.Custom.description = "Flatpaks defined by the image maintainer"' /usr/etc/yafti.yml
    yq -i '.screens.applications.values.groups.Custom.default = true' /usr/etc/yafti.yml
    for pkg in $(echo -e "$flatpaks"); do \
        yq -i ".screens.applications.values.groups.Custom.packages += [{\"$pkg\": \"$pkg\"}]" /usr/etc/yafti.yml
    done
fi

systemctl enable ratbagd.service
systemctl enable remote-fs.target
systemctl enable rpm-ostree-countme.service
sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/user.conf
sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf
