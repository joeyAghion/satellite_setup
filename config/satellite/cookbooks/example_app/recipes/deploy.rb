deploy "/app/example_app" do

  repo "git@github.com:my_org/example_app.git"  # update this!
  branch node['rails_env']  # assumes a branch named for this RAILS_ENV (e.g., staging, production)
  shallow_clone true
  environment node['rails_env']
  symlinks 'pids' => 'tmp/pids', 'log' => 'log', 'config/newrelic.yml' => 'config/newrelic.yml'
  before_restart do
    current_release = release_path
    execute("bundle install --without development test") do
      cwd current_release
      user 'example_app'
      group 'example_app'
      environment 'HOME' => '/home/example_app'
    end
  end
  restart_command { execute "monit restart delayed_job" }
  user 'example_app'
  group 'example_app'

end
