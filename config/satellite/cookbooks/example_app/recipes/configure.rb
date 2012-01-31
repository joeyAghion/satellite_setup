[ 'build-essential',
  'binutils-doc',
  'autoconf',
  'flex',
  'bison',
  'openssl',
  'libreadline5',
  'libreadline-dev',
  'git-core',
  'zlib1g',
  'zlib1g-dev',
  'libssl-dev',
  'libxml2-dev',
  'autoconf',
  'libxslt-dev',
  'imagemagick',
  'libmagick9-dev'
].each do |pkg|
  package(pkg)
end

gem_package 'bundler' do
  version '1.0.10'
end

group 'example_app'

user 'example_app' do
  gid 'example_app'
  home '/home/example_app'
  shell '/bin/bash'
  supports :manage_home => true
end

directory '/home/example_app/.ssh' do
  owner 'example_app'
  group 'example_app'
  mode 0700
end

# Ensure example_app can sudo
cookbook_file '/etc/sudoers.d/example_app' do
  mode 0440
end

[ 'authorized_keys',  # place the keys you want to authorize for SSH in this file
  'id_dsa',  # a new private key file, authorized to pull from your git repo
   'config'  # avoid prompt when pulling from github
].each do |config_file|
  cookbook_file "/home/example_app/.ssh/#{config_file}" do
    owner 'example_app'
    group 'example_app'
    mode 0600
  end
end

# Allow other developers to SSH as primary ubuntu account as well.
cookbook_file "/home/ubuntu/.ssh/authorized_keys" do
  owner 'ubuntu'
  group 'ubuntu'
  mode 0600
end

[ '/app',
  '/app/example_app',
  '/app/example_app/shared',
  '/app/example_app/shared/log',
  '/app/example_app/shared/pids',
  '/app/example_app/shared/config'
].each do |dir|
  directory dir do
    owner 'example_app'
    group 'example_app'
    mode 0755
  end
end

cookbook_file "/app/example_app/shared/config/newrelic.yml" do
  owner 'example_app'
  group 'example_app'
  mode 0755
end

include_recipe 'monit'
monitrc 'delayed_job', {}, :immediately

logrotate_app "example_app" do
  path "/app/example_app/shared/log/*.log"
  frequency "daily"
  rotate 30
end

include_recipe 'example_app::deploy'
