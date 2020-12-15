# frozen_string_literal: true

module ObsDeploy
  class CheckDiff
    def initialize(ssh_driver:, server: 'https://api.opensuse.org')
      @server = server
      @ssh_driver = ssh_driver
    end

    def github_diff
      base_url = 'https://github.com/openSUSE/open-build-service/compare/'
      url = "#{base_url}#{@ssh_driver.installed_package_version}...#{@ssh_driver.available_package_version}.diff"
      response = Net::HTTP.get_response(URI(url))
      unless response.is_a?(Net::HTTPSuccess)
        raise StandardError, "Error retrieving URL: #{url}, HTTP response class: #{response.class}"
      end

      response.body
    end

    def pending_migration?
      return false if github_diff.empty?

      github_diff.match?(%r{db/migrate})
    end

    def pending_data_migration?
      return false if github_diff.empty?

      github_diff.match(%r{db/data})
    end

    def migrations
      return [] unless pending_migration?

      github_diff.match(%r{db/migrate/.*\.rb}).to_a
    end
  end
end
