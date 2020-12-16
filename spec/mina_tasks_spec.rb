# frozen_string_literal: true

require 'spec_helper'

RSpec::Matchers.define_negated_matcher :not_raise_error, :raise_error

RSpec.describe 'Task within the obs: namespace' do
  include_context 'rake'

  let(:ssh_driver) { double(ObsDeploy::SSH) }
  let(:commit) { 'a1234adf24daf32' }

  before do
    allow(Mina::Configuration.instance).to receive(:fetch).with(:ssh_driver).and_return(ssh_driver)
  end

  describe 'obs:package:installed' do
    before do
      allow(ssh_driver).to receive(:installed_package_version).and_return(commit)
    end

    it { expect { subject }.to not_raise_error.and output(/#{commit}/).to_stdout }
  end

  describe 'obs:package:available' do
    let(:task) { 'obs:package:available' }

    context 'with an available package' do
      before do
        allow(ssh_driver).to receive(:available_package_version).and_return(commit)
      end

      it { expect { subject }.to not_raise_error.and output(/#{commit}/).to_stdout }
    end

    context 'without an available package' do
      before do
        allow(ssh_driver).to receive(:available_package_version)
        allow($stderr).to receive(:abort)
      end

      it { expect { subject }.to raise_error(Exception).and output.to_stderr }
    end
  end
end
