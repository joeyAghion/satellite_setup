module Heroku
  class Config

    # a map of heroku config vars for the given env
    def self.from_file(env)
      YAML.load_file(Rails.root.join("config/heroku.yml"))[env]['config']
    end

  end
end

namespace :heroku do
  desc "load environment vars described by heroku.yml into ENV, according to RAILS_ENV or Rails.env"
  task :config_from_file do
    env = ENV['RAILS_ENV'] || Rails.env
    raise "RAILS_ENV or Rails.env must be specified" unless env
    Heroku::Config.from_file(env).each { |k,v| ENV[k] ||= v }
  end
end
