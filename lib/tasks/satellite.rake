namespace :satellite do
  require 'fog'

  module Satellite
    KEY_NAME = 'satellite_keypair'
    IMAGE_ID = 'ami-c162a9a8'  # m1.large 64-bit Ubuntu 11.10 http://uec-images.ubuntu.com/releases/11.10/release/
    FLAVOR_ID = 'm1.large'

    def self.servers
      connection.servers.select{|s| s.tags['label'] == 'satellite' }.map do |server|
        Satellite::Server.new(server)
      end
    end
    
    class Server
      attr_accessor :aws_server
      delegate :state, :id, :dns_name, :ready?, :destroy, :private_key_path, :created_at, :tags, :ssh, to: :aws_server

      def self.spawn!
        aws_server = Satellite.connection.servers.bootstrap(
          tags: {'label' => 'satellite', 'rails_env' => Satellite.rails_env},
          key_name: KEY_NAME,
          private_key_path: private_key_path,
          image_id: IMAGE_ID,
          flavor_id: FLAVOR_ID)
        return new(aws_server).tap(&:prepare!)
      end

      def self.private_key_path
        if File.exist?(path = "#{ENV['HOME']}/.ssh/#{KEY_NAME}.pem")
          path
        else
          puts "#{KEY_NAME} key not found... falling back to default."
          "#{ENV['HOME']}/.ssh/id_rsa"
        end
      end

      def initialize(aws_server)
        @aws_server = aws_server
        @aws_server.private_key_path ||= self.class.private_key_path
      end
      
      def prepare!
        [ %{sudo sh -c "grep '^[^#].*us-east-1\.ec2' /etc/apt/sources.list | sed 's/us-east-1\.ec2/us/g' > /etc/apt/sources.list.d/better.list"},
          %{sudo apt-get update; sudo apt-get install -y make gcc rsync curl zlib1g-dev libssl-dev libreadline-dev libreadline5},
          %{mkdir -p /tmp/bootstrap},
          %{cd /tmp/bootstrap && curl -L 'ftp://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.tar.gz' | tar xvzf - && cd ruby-1.9.2-p290 && ./configure && make && sudo make install},
          %{cd /tmp/bootstrap && curl -L 'http://production.cf.rubygems.org/rubygems/rubygems-1.6.2.tgz' | tar xvzf - && cd rubygems* && sudo ruby setup.rb --no-ri --no-rdoc},
          %{sudo gem install rdoc chef ohai --no-ri --no-rdoc --source http://gems.rubyforge.org}
        ].each {|cmd| run cmd }
      end
      
      def configure!
        system "rsync -rlP --rsh=\"ssh -i #{private_key_path}\" --delete --exclude '.*' ./config/satellite ubuntu@#{dns_name}:/tmp/chef/"
        run_chef("configure.json")
      end

      def run_chef(attributes_file)
        run "cd /tmp/chef/satellite; RAILS_ENV=#{Satellite.rails_env} sudo -H -E chef-solo -c solo.rb -j #{attributes_file} -l info"
      end
      
      def run(cmd)
        $stdout.puts cmd
        aws_server.ssh(cmd).each do |result|
          $stdout.puts result.stdout unless result.stdout.empty?
          $stderr.puts result.stderr unless result.stderr.empty?
        end
      end
    end
  protected
    def self.connection
      @connection ||= Fog::Compute.new(provider: 'AWS',
        aws_access_key_id: config['S3_ACCESS_KEY_ID'],
        aws_secret_access_key: config['S3_SECRET_ACCESS_KEY'])
    end
    def self.config
      @config ||= Heroku::Config.from_file(rails_env)
    end
    def self.rails_env
      ENV['RAILS_ENV'] || 'staging'
    end
  end

  desc "Print information about running servers."
  task :info do
    servers = Satellite.servers
    puts "#{servers.size} satellite server(s)"
    servers.group_by(&:state).each do |state, group|
      puts "\tstate: #{state} (#{group.size})"
      group.each {|s| $stdout.puts "\t\t#{s.id}\t#{s.tags['rails_env']}\t#{s.dns_name}\t#{s.created_at}" }
    end
  end

  desc "Start new server instance(s). Accepts ENV['COUNT'] for number of instances to start (default: 1)."
  task :spawn do
    (ENV['COUNT'] || 1).to_i.times do
      server = Satellite::Server.spawn!
      puts("Started server: #{server.id}\t#{server.dns_name}")
    end
  end
  
  task :select_servers do
    @servers = Satellite.servers.select(&:ready?)
    @servers.select!{|s| s.id == ENV['ID'] } if ENV['ID']
    @servers.select!{|s| s.tags['rails_env'] == ENV['RAILS_ENV'] } if ENV['RAILS_ENV']
    puts "Found #{@servers.size} server(s)..."
  end

  desc "Configure server instance(s). Accepts ID/RAILS_ENV for choosing instances to configure (default: all)."
  task :configure => :select_servers do
    @servers.each do |server|
      puts "Configuring #{server.id}..."
      server.configure!
    end
  end
  
  desc "Destroy server instance(s). Accepts ID/RAILS_ENV for choosing instances to destroy (default: all)."
  task :destroy => :select_servers do
    @servers.each do |server|
      puts "Destroying #{server.id}..."
      server.destroy
    end
  end

  desc "Update satellite's code and restart worker(s). Accepts ID/RAILS_ENV for choosing instances to update (default: all)."
  task :deploy => :select_servers do
    @servers.each do |server|
      puts "Deploying #{server.id}..."
      server.run_chef("deploy.json")
    end
  end

  namespace :worker do
    desc "Launch local background worker; depends on RAILS_ENV and associated heroku config"
    task :start => ['heroku:config_from_file', 'environment'] do
      require 'delayed/command'
      Delayed::Command.new(['start']).daemonize
    end

    desc "Stop local background worker; depends on RAILS_ENV and associated heroku config"
    task :stop => ['heroku:config_from_file', 'environment'] do
      require 'delayed/command'
      Delayed::Command.new(['stop']).daemonize
    end

    desc "Tail worker log. Depends on RAILS_ENV or ID identifying a single server"
    task :tail => :select_servers do
      raise "Must provide ID or RAILS_ENV specifying a single server!" unless @servers.size == 1
      pattern = ENV['LOGS'] || "delayed_job.log"
      system! "ssh example_app@#{@servers.first.dns_name} 'tail -n25 -f /app/example_app/shared/log/#{pattern}'"
    end
  end
end

desc "same as satellite:info"
task :satellite => 'satellite:info'
