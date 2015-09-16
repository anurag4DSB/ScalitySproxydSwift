#!/bin/bash -xue

PYTHON_MOX_CENTOS=ftp://ftp.is.co.za/mirror/fedora.redhat.com/epel/6/x86_64/python-mox-0.5.3-2.el6.noarch.rpm

function common {
    git clone -b ${DEVSTACK_BRANCH} https://github.com/openstack-dev/devstack.git
    cp devstack/samples/local.conf devstack/local.conf
    cat >> devstack/local.conf <<EOF
disable_service c-sch c-api c-vol horizon
enable_service key mysql s-proxy s-object s-container s-account
SCREEN_LOGDIR="\${DEST}/logs"
EOF
    cp jenkins/${JOB_NAME%%/*}/extras.d/55-swift-sproxyd.sh devstack/extras.d/55-swift-sproxyd.sh
    if [[ $DEVSTACK_BRANCH == "stable/icehouse" ]]; then
        # Workaound depencies version conflict :
        # last python-glanceclient (0.17 at the time of writing), wich gets installed by default,
        # requires keystoneclient >= 1.0.0
        # whereas keystone requires keystoneclient <= 0.11.2
        # python-glanceclient >= 0.13.1 is required by openstackclient 0.4.1
        sudo pip install "python-glanceclient==0.13.1", "oslo.i18n<2.0.0"
    fi
    ./devstack/stack.sh
}

function ubuntu_common {
    wget https://bootstrap.pypa.io/ez_setup.py -O - | sudo python;
    sudo easy_install pip
    if [[ $DEVSTACK_BRANCH == "stable/icehouse" ]]; then
        sudo aptitude install -y gcc python-dev
    fi
    # Workaround pip upgrading six without completely removing the old one
    # which then cause an error.    
    sudo easy_install -U six
}

function ubuntu14_specifics {
    :
}

function ubuntu12_specifics {
    # Nova Kilo and after needs a libvirt >= 0.9.11. Ubuntu 12.04 vanilla ships 0.9.8.
    sudo add-apt-repository --yes cloud-archive:icehouse
}

function centos_specifics {
    sudo yum install -y wget
    wget https://bootstrap.pypa.io/ez_setup.py -O - | sudo python;
    sudo easy_install -U six
    sudo yum install -y python-pip
    sudo yum install -y $PYTHON_MOX_CENTOS
    if [[ $DEVSTACK_BRANCH == "stable/icehouse" ]]; then
        # Required to get 'cryptography' python package compiled during its installation through pip.
        sudo yum install -y gcc python-devel libffi-devel openssl-devel
        # Required by keystoneclient
        sudo yum install -y MySQL-python
        # devstack uses the ip command.
        export PATH=$PATH:/sbin/
    fi
}

function main {
    source jenkins/openstack-ci-scripts/jenkins/distro-utils.sh
    if is_ubuntu; then
        ubuntu_common
        if [[ $os_CODENAME == "precise" ]]; then
            ubuntu12_specifics
        elif [[ $os_CODENAME == "trusty" ]]; then
            ubuntu14_specifics
        fi
    elif is_centos; then
        centos_specifics
    fi
    common
}

main
