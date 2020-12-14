# frozen_string_literal: true

module ObsDeploy
  class CheckDiff
    def initialize(server: 'https://api.opensuse.org', product: 'SLE_12_SP4', https_verify_none: false)
      @server = server
      @product = product
      @https_verify_none = https_verify_none
    end

    def url_get(url)
      return Net::HTTP.get(URI(url)) unless @https_verify_none

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.get(uri).body
    end

    def package_version
      doc = Nokogiri::XML(url_get(package_url))
      doc.xpath("//binary[starts-with(@filename, 'obs-api')]/@filename").to_s
    end

    def package_commit
      package_version.match(/obs-api-.*\..*\..*\.(.*)-.*\.rpm/).captures.first
    end

    def obs_running_commit
      doc = Nokogiri::XML(url_get(about_url))
      doc.xpath('//commit/text()').to_s
    end

    def github_diff
      Net::HTTP.get(
        URI("https://github.com/openSUSE/open-build-service/compare/#{obs_running_commit}...#{package_commit}.diff")
      )
    end

    def pending_migration?
      return true if github_diff.nil? || github_diff.empty?

      github_diff.match?(%r{db/migrate})
    end

    def pending_data_migration?
      return true if github_diff.nil? || github_diff.empty?

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
      "https://build.opensuse.org/public/build/OBS:Server:Unstable/#{@product}/x86_64/obs-server"
    end

    def about_url
      "#{@server}/about"
    end
  end
end
