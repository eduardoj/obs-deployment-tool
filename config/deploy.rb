# frozen_string_literal: true

require 'shellwords'
require 'bundler/setup'
require 'mina/deploy'

require_relative '../lib/obs_deploy'
require_relative '../lib/github_deployment'

class PendingMigrationError < StandardError; end

set :domain, ENV['DOMAIN'] || 'obs'
# if we don't unset it, it will use the default:
# https://github.com/mina-deploy/mina/blob/master/lib/mina/backend/remote.rb#L28
set :port, ENV['SSH_PORT'] || nil
set :package_name, ENV['PACKAGE_NAME'] || 'obs-api'
set :product, ENV['PRODUCT'] || 'SLE_12_SP4'
set :deploy_to, ENV['DEPLOY_TO_DIR'] || '/srv/www/obs/api/'
set :github_token, ENV['GITHUB_TOKEN'] || nil
set :github_repository, ENV['GITHUB_REPOSITORY'] || nil
set :github_branch, ENV['GITHUB_BRANCH'] || 'master'

set :user, ENV['obs_user'] || 'root'
set :check_diff, ObsDeploy::CheckDiff.new(product: fetch(:product), server: "https://#{fetch(:domain)}")

# Let mina controls the dry-run
set :zypper, ObsDeploy::Zypper.new(package_name: fetch(:package_name), dry_run: false)
set :apache_sysconfig, ObsDeploy::ApacheSysconfig.new
set :systemctl, ObsDeploy::Systemctl.new
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
        puts "Running Version: #{fetch(:check_diff).obs_running_commit}"
      end
    end

    desc 'check available version'
    task :available do
      run(:local) do
        puts "Available Version: #{fetch(:check_diff).package_version}"
      end
    end
  end
end

namespace :systemd do
  desc 'obs-api list systemctl dependencies'
  task :list_dependencies do
    run(:remote) do
      command Shellwords.join(fetch(:systemctl).list_dependencies)
    end
  end
  desc 'obs-api status'
  task :status do
    run(:remote) do
      command Shellwords.join(fetch(:systemctl).status)
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

desc 'Deploys without pending migrations'
task deploy: 'dependencies:migration:check' do
  invoke 'zypper:update'
  invoke 'obs:package:installed'
end

desc 'Deploy with pending migration'
task :deploy_with_migration do
  begin
    # rubocop:disable Lint/UnreachableCode
    raise NotImplementedError, 'Working in progress'
    invoke 'dependencies:migration:check'
    # rubocop:enable Lint/UnreachableCode
  rescue PendingMigrationError
    invoke 'zypper:update'
    apache_sysconfig = fetch(:apache_sysconfig)
    run(:remote) do
      command Shellwords.join(apache_sysconfig.enable_maintenance_mode)
      command Shellwords.join(fetch(:systemctl).restart_apache)
      command 'run_in_api rails db:migrate'
      command 'run_in_api rails db:migrate:with_data'
      command Shellwords.join(apache_sysconfig.disable_maintenance_mode)
      command Shellwords.join(fetch(:systemctl).restart_apache)
    end
    basic test
    invoke 'obs:package:installed'
  end
end
