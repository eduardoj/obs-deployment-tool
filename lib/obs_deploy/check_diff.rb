# frozen_string_literal: true

REGULAR_EXPRESSION_FOR_MIGRATION = %r{^--- /dev/null\n\+{3}.+/src/api/(db/migrate/.+\.rb)$}.freeze
REGULAR_EXPRESSION_FOR_DATA_MIGRATION = %r{^--- /dev/null\n\+{3}.+/src/api/(db/data/.+\.rb)$}.freeze

module ObsDeploy
  class CheckDiff
    def initialize(ssh_driver:, server: 'https://api.opensuse.org')
      @server = server
      @ssh_driver = ssh_driver
    end

    def pending_migration?
      github_diff
      return false if @github_diff.empty?

      @github_diff.match?(REGULAR_EXPRESSION_FOR_MIGRATION)
    end

    def pending_data_migration?
      github_diff
      return false if @github_diff.empty?

      @github_diff.match?(REGULAR_EXPRESSION_FOR_DATA_MIGRATION)
    end

    def migrations
      return [] unless pending_migration?

      @github_diff.scan(REGULAR_EXPRESSION_FOR_MIGRATION).flatten
    end

    private

    def github_diff
      available_package_version = @ssh_driver.available_package_version
      return @github_diff = '' if available_package_version.nil?

      base_url = 'https://github.com/openSUSE/open-build-service/compare/'
      url = "#{base_url}#{@ssh_driver.installed_package_version}...#{available_package_version}.diff"
      response = Net::HTTP.get_response(URI(url))
      unless response.is_a?(Net::HTTPSuccess)
        raise StandardError, "Error retrieving URL: #{url}, HTTP response class: #{response.class}"
      end

      @github_diff = response.body
    end
  end
end
