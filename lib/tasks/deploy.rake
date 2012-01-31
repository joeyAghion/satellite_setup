namespace :deploy do
  desc 'Merge master into a staging branch and deploy it to example_app-staging.'
  task :staging => 'git:tag:staging' do
    puts `git push git@heroku.com:example_app-staging.git origin/staging:master`
    ENV['RAILS_ENV'] = 'staging'
    task('satellite:deploy').invoke
  end

  desc 'Merge staging into a production branch and deploy it to example_app-production.'
  task :production => 'git:tag:production' do
    puts `git push git@heroku.com:example_app-production.git origin/production:master`
    ENV['RAILS_ENV'] = 'production'
    task('satellite:deploy').invoke
  end
end

namespace :git do
  task :tag, [:from, :to] => :confirm_clean do |t, args|
    raise "Must specify 'from' and 'to' branches" unless args[:from] && args[:to]
    `git fetch`
    `git branch -f #{args[:to]} origin/#{args[:to]}`
    `git checkout #{args[:to]}`
    `git reset --hard origin/#{args[:from]}`
    puts "Updating #{args[:to]} with these commits:"
    puts `git log origin/#{args[:to]}..#{args[:to]} --format=format:"%h  %s  (%an)"`
    `git push -f origin #{args[:to]}`
    `git checkout master`
    `git branch -D #{args[:to]}`
  end

  task :confirm_clean do
    raise "Must have clean working directory" unless `git status` =~ /working directory clean/
  end

  namespace :tag do
    task :staging do
      task('git:tag').invoke('master',  'staging')
    end
    task :production do
      task('git:tag').invoke('staging', 'production')
    end
  end
end
