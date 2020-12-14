# frozen_string_literal: true

module ObsDeploy
  class CheckDiff
    def initialize(server: 'https://api.opensuse.org', product: 'SLE_12_SP4')
      @server = server
      @product = product
    end

    def package_version
      doc = Nokogiri::XML(Net::HTTP.get(package_url))
      doc.xpath("//binary[starts-with(@filename, 'obs-api')]/@filename").to_s
    end

    def package_commit
      package_version.match(/obs-api-.*\..*\..*\.(.*)-.*\.rpm/).captures.first
    end

    def obs_running_commit
      doc = Nokogiri::XML(Net::HTTP.get(about_url))
      doc.xpath('//commit/text()').to_s
    end

    def github_diff
      url = "https://github.com/openSUSE/open-build-service/compare/#{obs_running_commit}...#{package_commit}.diff"
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

    def data_migrations
      return [] unless pending_data_migration?

      github_diff.match(%r{db/data/.*\.rb}).to_a
    end

    def migrations
      return [] unless pending_migration?

      github_diff.match(%r{db/migrate/.*\.rb}).to_a
    end

    def package_url
      URI("#{@server}/public/build/OBS:Server:Unstable/#{@product}/x86_64/obs-server")
    end

    def about_url
      URI("#{@server}/about")
    end
  end
end
