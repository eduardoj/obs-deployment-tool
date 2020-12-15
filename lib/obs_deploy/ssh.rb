# frozen_string_literal: true

module ObsDeploy
  # Retrieves output from commands sent to a remote server
  class SSH
    attr_reader :user, :server, :port, :identity_file

    def initialize(opts = {})
      @user = opts[:user] || 'root'
      @server = opts[:server] || 'localhost'
      @port = opts[:port] || 22
      @identity_file = opts[:identity_file]
      @debug = opts[:debug] || false
      @package_name = opts[:package_name] || 'obs-api'
    end

    def run(cmd)
      Cheetah.run(ssh_command + cmd, logger: logger)
    end

    def installed_package_version
      installed_package = Cheetah.run(ssh_command + %w[rpm -q] + [@package_name], stdout: :capture, logger: logger)
      extract_commit(installed_package)
    end

    def available_package_version
      list_updates = Cheetah.run(ssh_command + %w[zypper list-updates], stdout: :capture, logger: logger)
      update_line = list_updates[/(.+\s+#{@package_name}\s+[^\n]+).+/, 1]
      return if update_line.nil?

      available_package = update_line.split(/\s+\|\s+/)[4]

      extract_commit(available_package)
    end

    private

    def extract_commit(package)
      package[/.+\.(.+)-.+/, 1]
    end

    def ssh_command
      ['ssh'] + identity + ssh_port + ["#{@user}@#{@server}"]
    end

    def identity
      @identity_file ? ['-i', @identity_file] : []
    end

    def ssh_port
      @port && @port != 22 ? ['-p', @port.to_s] : []
    end

    def logger
      Logger.new($stdout, level: logger_level, formatter: logger_formatter)
    end

    def logger_level
      @debug ? Logger::DEBUG : Logger::INFO
    end

    def logger_formatter
      proc do |severity, _datetime, _progname, msg|
        "#{severity} - #{msg}\n"
      end
    end
  end
end
