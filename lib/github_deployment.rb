# frozen_string_literal: true

# this class is responsible for handling the GitHub deployments through
# the API
class GithubDeployment
  require 'octokit'
  require 'active_support/core_ext/object/blank'

  def initialize(access_token:, repository: 'openSUSE/open-build-service', ref: 'master')
    @client = Octokit::Client.new(access_token: access_token)
    @repository = repository
    @ref = ref
  end

  def lock
    deployment = latest_deployment

    return create_a_deployment_and_lock if deployment.blank?

    deployment_status = latest_deployment_status(deployment)

    if deployment_status.blank?
      puts "It can not be locked.\n\n"
      print_deployment_details(deployment)
      return
    end

    perform_lock = false

    case deployment_status.state
    when 'queued'
      puts "The last deployment is already locked. The lock will not be performed.\n\n"
    when 'in_progress'
      puts "The last deployment is not locked, but in state '#{deployment_status.state}'. The lock will not
            be performed.\n\n"
    else
      perform_lock = true
    end

    return print_deployment_details(deployment) unless perform_lock

    create_a_deployment_and_lock
  end

  def print_deployment_history
    deployments = fetch_github_deployments

    deployments.each do |deployment|
      print_deployment_details(deployment)
    end
  end

  def print_deployment_details(deployment)
    puts "Deployment created at #{deployment.created_at} by #{deployment.creator.login} for the
          #{deployment.environment} environment:"

    print_deployment_status_details(deployment)

    puts '-----'
  end

  def print_deployment_status_details(deployment)
    deployment_status = latest_deployment_status(deployment)

    if deployment_status.blank?
      puts 'The current state of the deployment is pending'
      return
    end

    puts "Current state of the deployment is: #{deployment_status.state}"
    puts "Last state change occured at: #{deployment_status.created_at}"
    puts "Last modified by: #{deployment_status.creator.login}"
  end

  def unlock
    deployment_status = latest_deployment_status(latest_deployment)

    unless deployment_status.blank? || deployment_status.state == 'queued'
      puts 'Last deployment is not locked, nothing to do here'
      print_deployment_details(latest_deployment)

      return
    end

    @client.create_deployment_status(latest_deployment.url, 'inactive',
                                     { accept: 'application/vnd.github.ant-man-preview+json' })
  end

  def current
    print_deployment_details(latest_deployment) unless latest_deployment.blank?
  end

  private

  def fetch_github_deployments
    @all_github_deployments ||= []
    return @all_github_deployments unless @all_github_deployments.blank?

    begin
      @all_github_deployments = @client.deployments(@repository)
    rescue ::Octokit::NotFound, ::Octokit::InvalidRepository => e
      puts e.message.to_s
    end
  end

  def fetch_deployment_statuses(deployment)
    @client.deployment_statuses(deployment.url)
  end

  def latest_deployment
    @latest_deployment ||= fetch_github_deployments.first
  end

  def latest_deployment_status(deployment)
    fetch_deployment_statuses(deployment).first
  end

  def create_a_deployment_and_lock
    deployment = create_deployment
    @client.create_deployment_status(deployment.url, 'queued', { accept: 'application/vnd.github.flash-preview+json' })
  end

  def create_deployment
    # prevent working with outdated data, we have to retrieve fresh
    # data after creating new deployments
    @all_github_deployments = []
    @latest_deployment = nil

    @client.create_deployment(@repository, @ref, { auto_merge: false })
  end
end
