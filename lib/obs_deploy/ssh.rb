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
    end

    def ssh_command
      ['ssh'] + basic_connection_string + identity + ssh_port
    end

    def run(cmd)
      Cheetah.run(ssh_command + cmd, logger: logger)
    end

    private

    def identity
      @identity_file ? ['-i', @identity_file] : []
    end

    def basic_connection_string
      [[@user, '@', @server].join]
    end

    def ssh_port
      @port && @port != 22 ? ['-p', @port.to_s] : []
    end

    def logger
      Logger.new(STDOUT, level: logger_level, formatter: logger_formatter)
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
