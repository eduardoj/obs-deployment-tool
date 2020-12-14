# frozen_string_literal: true

require 'shellwords'
require 'bundler/setup'
require 'mina/deploy'

require_relative '../lib/obs_deploy'
require_relative '../lib/github_deployment'

class PendingMigrationError < StandardError; end

set :user, ENV['obs_user'] || 'root'
set :domain, ENV['DOMAIN'] || 'obs'
# if we don't unset it, it will use the default:
# https://github.com/mina-deploy/mina/blob/master/lib/mina/backend/remote.rb#L28
set :port, ENV['SSH_PORT'] || nil

set :package_name, ENV['PACKAGE_NAME'] || 'obs-api'
set :deploy_to, ENV['DEPLOY_TO_DIR'] || '/srv/www/obs/api/'

set :github_token, ENV['GITHUB_TOKEN'] || nil
set :github_repository, ENV['GITHUB_REPOSITORY'] || nil
set :github_branch, ENV['GITHUB_BRANCH'] || 'master'

set :ssh_driver, ObsDeploy::SSH.new(user: fetch(:user), server: fetch(:domain), port: fetch(:port),
                                    package_name: fetch(:package_name))
set :check_diff, ObsDeploy::CheckDiff.new(server: "https://#{fetch(:domain)}",
                                          ssh_driver: fetch(:ssh_driver))
set :zypper, ObsDeploy::Zypper.new(package_name: fetch(:package_name), dry_run: false)
set :github_deployment, GithubDeployment.new(access_token: fetch(:github_token), repository: fetch(:github_repository),
                                             ref: fetch(:github_branch))

# tasks without description shouldn't be called in the CLI
namespace :dependencies do
  namespace :migration do
    task :check do
      raise ::PendingMigrationError, 'pending migration' if fetch(:check_diff).pending_migration?
    end
  end
end

namespace :github do
  namespace :deployments do
    desc 'list a history of all performed deployments'
    task :history do
      fetch(:github_deployment).print_deployment_history
    end

    desc 'infos about the latest deployment'
    task :current do
      fetch(:github_deployment).current
    end

    desc 'Lock deployments'
    task :lock do
      fetch(:github_deployment).lock
    end

    desc 'Unlock deployments'
    task :unlock do
      fetch(:github_deployment).unlock
    end
  end
end

namespace :obs do
  namespace :migration do
    desc 'migration needed'
    task :check do
      begin
        invoke 'dependencies:migration:check'
        puts 'No pending migration'
      rescue ::PendingMigrationError
        puts 'Pending migrations:'
        invoke 'obs:migration:show'
      end
    end
    desc 'show pending migrations'
    task :show do
      puts "Migrations: #{fetch(:check_diff).migrations}"
    end
  end

  desc 'get diff'
  task :diff do
    run(:local) do
      puts "Diff: #{fetch(:check_diff).github_diff}"
    end
  end

  namespace :package do
    desc 'check installed version'
    task :installed do
      run(:local) do
        puts "Running Version: #{fetch(:ssh_driver).installed_package_version}"
      end
    end

    desc 'check available version'
    task :available do
      run(:local) do
        package_version = fetch(:ssh_driver).available_package_version
        abort 'No Available Version found.' if package_version.nil?

        puts "Available Version: #{package_version}"
      end
    end
  end

  namespace :zypper do
    desc 'refresh repositories'
    task :refresh do
      run(:remote) do
        command Shellwords.join(fetch(:zypper).refresh)
      end
    end
    task update: :refresh do
      run(:remote) do
        command Shellwords.join(fetch(:zypper).update)
      end
    end
  end
end

desc 'Deploys without pending migrations'
task deploy: 'dependencies:migration:check' do
  invoke 'obs:zypper:update'
  invoke 'obs:package:installed'
end
