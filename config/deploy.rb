require 'bundler/capistrano'

# This capistrano deployment recipe is made to work with the optional
# StackScript provided to all Rails Rumble teams in their Linode dashboard.
#
# After setting up your Linode with the provided StackScript, configuring
# your Rails app to use your GitHub repository, and copying your deploy
# key from your server's ~/.ssh/github-deploy-key.pub to your GitHub
# repository's Admin / Deploy Keys section, you can configure your Rails
# app to use this deployment recipe by doing the following:
#
# 1. Add `gem 'capistrano'` to your Gemfile.
# 2. Run `bundle install --binstubs --path=vendor/bundles`.
# 3. Run `bin/capify .` in your app's root directory.
# 4. Replace your new config/deploy.rb with this file's contents.
# 5. Configure the two parameters in the Configuration section below.
# 6. Run `git commit -a -m "Configured capistrano deployments."`.
# 7. Run `git push origin master`.
# 8. Run `bin/cap deploy:setup`.
# 9. Run `bin/cap deploy:migrations` or `bin/cap deploy`.
#
# Note: You may also need to add your local system's public key to
# your GitHub repository's Admin / Deploy Keys area.
#
# Note: When deploying, you'll be asked to enter your server's root
# password. To configure password-less deployments, see below.

#############################################
##                                         ##
##              Configuration              ##
##                                         ##
#############################################

GITHUB_REPOSITORY_NAME = 'redmine'
LINODE_SERVER_HOSTNAME = 'rainchen.com'

#############################################
#############################################

# General Options

set :bundle_flags,               "--deployment"

set :application,                "#{GITHUB_REPOSITORY_NAME}"
set :deploy_to,                  "/var/www/apps/#{GITHUB_REPOSITORY_NAME}"
set :normalize_asset_timestamps, false
set :rails_env,                  "production"

set :user,                       "root"
set :runner,                     "www-data"
set :admin_runner,               "www-data"

# Password-less Deploys (Optional)
#
# 1. Locate your local public SSH key file. (Usually ~/.ssh/id_rsa.pub)
# 2. Execute the following locally: (You'll need your Linode server's root password.)
#
#    cat ~/.ssh/id_rsa.pub | ssh root@LINODE_SERVER_HOSTNAME "cat >> ~/.ssh/authorized_keys"
#
# 3. Uncomment the below ssh_options[:keys] line in this file.
#
# ssh_options[:keys] = ["~/.ssh/id_rsa"]

# SCM Options
set :scm,        :git
set :repository, "git@github.com:rainchen/#{GITHUB_REPOSITORY_NAME}.git"
set :branch,     "develop"
ssh_options[:forward_agent] = true # tells cap to use my local private key

# Roles
role :app, LINODE_SERVER_HOSTNAME
role :db,  LINODE_SERVER_HOSTNAME, :primary => true

namespace :deploy do
  desc "Initialize configuration using example files provided in the distribution"
  task :upload_config do
    %w{config db}.each do |dir|
      run "mkdir -p #{shared_path}/#{dir}"
      sudo "chown -R www-data:www-data #{shared_path}/#{dir}"
    end

    Dir["config/*.yml.example"].each do |file|
      remote_file = "#{shared_path}/config/#{File.basename(file, '.example')}"
      unless remote_file_exists? remote_file
        top.upload(File.expand_path(file), remote_file)
      end
    end
  end

  desc "Symlink shared resources on each release"
  task :symlink_shared, :roles => :app do
    %w{database configuration}.each do |file|
      run "ln -nfs #{shared_path}/config/#{file}.yml #{release_path}/config/#{file}.yml"
    end

    # link files dir
    run "mkdir -p #{shared_path}/system/files"
    run "ln -nfs #{shared_path}/system/files #{release_path}/files"

    # link db
    # run "test -f #{shared_path}/db/redmine.db && ln -nfs #{shared_path}/db/redmine.db #{release_path}/db/redmine.db"
  end
end

after 'deploy:setup', 'deploy:upload_config'

# Add Configuration Files & Compile Assets
after 'deploy:update_code', 'deploy:symlink_shared'
after 'deploy:update_code' do
  # Setup Configuration
  # run "cp #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  # sudo "chown www-data:www-data #{release_path}/config/database.yml"

  # Compile Assets
  run "cd #{release_path}; RAILS_ENV=production bundle exec rake assets:precompile"
end

after 'deploy:update_code' do
  upload_local("config/initializers/secret_token.rb")
end

# Restart Passenger
deploy.task :restart, :roles => :app do
  # Fix Permissions
  sudo "chown -R www-data:www-data #{current_path}"
  sudo "chown -R www-data:www-data #{latest_release}"
  sudo "chown -R www-data:www-data #{shared_path}/bundle"
  sudo "chown -R www-data:www-data #{shared_path}/log"
  sudo "chown -R www-data:www-data #{shared_path}/db"

  # Restart Application
  run "touch #{current_path}/tmp/restart.txt"
end

set :keep_releases, 5 # number for keep old releases
after "deploy", "deploy:cleanup"

namespace :remote do
  desc "Open the rails console on one of the remote servers"
  task :console, :roles => :app do
    hostname = find_servers_for_task(current_task).first
    command = "cd #{current_path} && bundle exec rails console #{fetch(:rails_env)}"
    if exists?(:rvm_ruby_string)
      # set rvm shell and get ride of "'"
      # https://github.com/wayneeseguin/rvm/blob/master/lib/rvm/capistrano.rb
      # default_shell == "rvm_path=$HOME/.rvm/ $HOME/.rvm/bin/rvm-shell '1.9.2-p136'"

      rvm_shell = %{rvm_path=$HOME/.rvm/ $HOME/.rvm/bin/rvm-shell "#{fetch(:rvm_ruby_string)}"}
      command = %{#{rvm_shell} -c "#{command}"}
    else
      if fetch(:user) != 'root'
        command = %{source ~/.profile && "#{command}"}
      end
    end
    exec %{ssh -l #{user} #{hostname} -t '#{command}'}
  end

  desc 'run rake task. e.g.: `cap remote:rake db:version`'
  task :rake do
    rake_task = ARGV.dup.drop(1).join(" ")
    top.run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake #{rake_task}"
    # ARGV.values_at(Range.new(ARGV.index('remote:rake')+1,-1)).each do |rake_task|
    #   top.run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake #{rake_task}"
    # end
    exit(0)
  end

  desc 'run remote command. e.g.: `cap remote:run "tail -n 10 log/production.log"`'
  task :run do
    command=ARGV.values_at(Range.new(ARGV.index('remote:run')+1,-1))
    top.run "cd #{current_path}; RAILS_ENV=#{rails_env} #{command*' '}"
    exit(0)
  end

  desc 'run specified rails code on server. e.g.: `cap remote:runner p User.all` or `cap remote:runner "User.all.each{ |u| p u }"`'
  task :runner do
    # command=ARGV.values_at(Range.new(ARGV.index('remote:runner')+1,-1))
    # top.run "cd #{current_path}; RAILS_ENV=#{rails_env} bundle exec rails runner '#{command*' '}'"
    command = ARGV.dup.drop(1).join(" ")
    top.run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rails runner '#{command}'"
    exit(0)
  end

  desc 'tail log on remote server'
  task :tail_log do
    top.run "tail -f #{current_path}/log/#{rails_env}.log" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
    exit(0)
  end
end


namespace :deploy do
  namespace :web do
    desc 'Visit the app'
    task :visit do
      system "open http://pm.rainchen.com"
    end
  end
end
after 'deploy:restart', 'deploy:web:visit'

# upload Gemfile.lock
before 'bundle:install' do
  # backup Gemfile.local and Gemfile.lock
  system "mv Gemfile.local .Gemfile.local"
  system "cp Gemfile.lock .Gemfile.lock"

  # update Gemfile.lock for Gemfile
  system "bundle install --quiet"

  # upload Gemfile.lock to remote
  # upload(File.expand_path("Gemfile.lock"), "#{release_path}/Gemfile.lock")
  upload_local("Gemfile.lock")


  # restore Gemfile.local and Gemfile.lock
  system "mv .Gemfile.local Gemfile.local"
  system "rm Gemfile.lock"
  system "mv .Gemfile.lock Gemfile.lock"
end

def remote_file_exists?(full_path)
  'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
end

def upload_local(path)
  upload(File.expand_path(path), "#{release_path}/#{path}")
end