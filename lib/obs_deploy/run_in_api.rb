# frozen_string_literal: true

module ObsDeploy
  class RunInAPI
    API_ROOT = '/srv/www/obs/api'.freeze
    RAILS_ENV = 'production'.freeze

    def db_migrate_with_data
      run 'rails db:migrate:with_data'
    end

    private

    def run(params)
      remote_command = "cd #{API_ROOT} && RAILS_ENV=#{RAILS_ENV} /usr/bin/bundle exec #{params}"
      %w[chroot --userspec=wwwrun:www / /bin/bash -c] + [remote_command]
    end
  end
end
