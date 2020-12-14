# frozen_string_literal: true

require 'open-uri'
require 'net/http'
require 'logger'
require 'cheetah'

require 'nokogiri'
require_relative 'obs_deploy/version'
require_relative 'obs_deploy/check_diff'
require_relative 'obs_deploy/zypper'
require_relative 'obs_deploy/ssh'
require 'tempfile'

module ObsDeploy
  class Error < StandardError; end
end
