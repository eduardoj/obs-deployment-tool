# frozen_string_literal: true

require 'mina'
require 'rake'

RSpec.shared_context 'rake' do
  let(:task) { self.class.description }
  let(:rake_task) { Rake.application[task] }

  subject do
    rake_task.reenable
    rake_task.invoke
  end

  before(:context) do
    Rake.application = Mina::Application.new
    Rake.application.load_rakefile
  end
end
