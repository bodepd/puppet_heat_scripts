# Intro

The Puppet Heat scripts project is intended to hold basic scripts that
can be used to integrate Puppet with Heat.

# Masterless scripts

Currently, the project only contains scripts that function without a central
master via the *puppet apply* command. Future versions should contain
a version of the script that also supports *puppet* usage with a master via
*puppet agent*

## Design assumptions

The masterless script requires that users follow a few conventions. These
conventions are required in order for a single script to be able to support
all generic use cases related to using Puppet with this heat script.

### Control Repo

The heat script consumes a variation of what is commonly referred to as a
*control repo*. Essentially a repo that contains all of the artifacts required
to map heat *server instances* into functioning Puppet nodes with roles.

The control Repo should be a single repository that is addressable by the instances
that will be create by heat (in general, this means that it should be a public
repo).

It should contain the following:

#### Puppetfile

A file that lists all modules that need to be installed. *Note* This file
currently uses librarian-puppet-simple (which does not support installing from
forge or dependency resolution) and not R10k. I intend to update it to use R10K
once I can get it working. My attempts so far have lead to stack traces.

EX:
````
mod 'openstack-infra/pip',
  :git      => 'https://github.com/bodepd/puppet-pip',
  :revision => '1.0.0'

mod 'openstack-infra/logrotate',
  :git => 'https://github.com/bodepd/puppet-logrotate'
````


#### Site manifest

A manifest in the path: *manifests/site.pp*. This manifest should contain a
description of how roles defined with the fact $::role map to classification
information.

EX:
````
if $:role == 'server' {
  include server
} elsif $role == 'client' {
  include client
}
````

*NOTE*: Perhaps this should be changed for hiera\_include with classification
info set in hiera.

#### Hiera files

This project should also contain your project specific hiera data.

*./hiera/hiera.yaml* : The specific hiera configuration file that should be
deployed.
*./hiera/data/* : Hiera data associated with this template. This directory
will be copied to /etc/puppet/hieradata/\*. Do make sure that is the path
used by your hiera.yaml file.

*NOTE*: There are two types of hiera data that you should not store in the
*control repo* specific hiera data.

  * secrets (password, private keys) have no place here b/c this data will likely
    be published to a publically accessible repo.
  * connection specific data - some data depends on connectivity information that
    is only available after certain nodes have been provisioned by heat. This
    information does not belong here.

#### Example

This project was built around the following example:

    https://github.com/bodepd/puppet-openstack-gater

## Building your own heat template

This project comes with a single script that should be embedding inside of
your heat template:

````
resources:
  jenkins\_server:
    type: OS::Nova::Server
    properties:
      userdata:
        str_replace:
          template: { get_file: heat_puppet_userdata.sh }
          params:
            $PUPPET_REPO: { get_param: puppet_repo }
            # this just works, you can just set any facts that you want as params
            $FACTS: 'role=jenkinsserver'
            $USER_HIERA_YAML: { get_file: jenkins_server.yaml }
            $CONNECTION_HIERA_OVERRIDES:
              str_replace:
                template: "jenkins_server: $CONN"
                params:
                  $CONN: { get_attr: [ jenkins_server, networks, private, 0 ] }

````

This script is intended to be a userdata template and expects the following parameters:

* PUPPET\_REPO - the url of the control repo utilized by this project
* FACTS - a list of facts that should be set for a node. They are set as k=v and a list
of them is delimited by ';'. At a minimum, you should set the role fact.

EX:
````
$FACTS: 'role=jenkinsserver;dc=us'
````

* USER\_HIERA\_YAML: passes a local hiera file into user.yaml. This file is intended to
hold secrets, keys, etc. Things that you would not put into your public control repo.

* CONNECTION\_HIERA\_OVERRIDES: allows resource to specify individual hiera keys into
this string which is appended to the user.yaml hiera config. This is intended to
populate hiera data with data that is required to interconnect nodes (like ip address).
This information is only available after nodes have been provisioned via the
[get-attr](http://docs.openstack.org/developer/heat/template_guide/hot_spec.html#get-attr)
intrinsic function.

## TODO

Clearly this is just a prototype and not fully flushed out :) I still want to adjust things
to make it a little more standard, and get some feedback on some of the conventions that I
am using.

# Attributions

Thanks to Ben Schwartz for this blog that I read while working on this project:
  http://txt.fliglio.com/2014/01/openstack_with_puppet_and_heat/
