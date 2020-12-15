# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ObsDeploy::CheckDiff do
  let(:ssh_driver) { double('ObsDeploy::SSH') }
  let(:check_diff) { described_class.new(ssh_driver: ssh_driver) }
  let(:http_response) { fixture_file }
  let(:diff_url) do
    "https://github.com/openSUSE/open-build-service/compare/#{running_commit}...#{package_commit}.diff"
  end

  it { expect(check_diff).not_to be_nil }

  describe 'pending_migration?' do
    before do
      allow(ssh_driver).to receive(:installed_package_version).and_return(running_commit)
      allow(ssh_driver).to receive(:available_package_version).and_return(package_commit)
    end

    context 'data is present' do
      before do
        stub_request(:get, diff_url).to_return(fixture_file)
      end

      context 'pending migration' do
        let(:fixture_file) { File.new('spec/fixtures/github_diff_with_migration.txt') }
        let(:running_commit) { '52a3a8b' }
        let(:package_commit) { '2c565b0' }

        it { expect(check_diff.pending_migration?).to be true }
      end
      context 'no pending migration' do
        let(:fixture_file) { File.new('spec/fixtures/github_diff_without_migration.txt') }
        let(:running_commit) { 'bc7f6c0' }
        let(:package_commit) { '554e943' }

        it { expect(check_diff.pending_migration?).to be false }
      end
    end

    context 'no data is present' do
      context 'if no available package' do
        let(:running_commit) { '52a3a8b' }
        let(:package_commit) { nil }

        it { expect(check_diff.pending_migration?).to be false }
      end

      context 'if no git diff is present it should abort' do
        let(:running_commit) { '52a3a8b' }
        let(:package_commit) { '2c565b0' }

        before do
          dbl = double('Net::HTTP response')
          allow(dbl).to receive(:class).and_return(Net::HTTPNotFound)
          allow(Net::HTTP).to receive(:get_response).and_return(dbl)
        end

        it { expect { check_diff.pending_migration? }.to raise_error Exception }
      end
    end
  end

  describe 'pending_data_migration?' do
    before do
      allow(ssh_driver).to receive(:installed_package_version).and_return(running_commit)
      allow(ssh_driver).to receive(:available_package_version).and_return(package_commit)
      stub_request(:get, diff_url).to_return(fixture_file)
    end

    context 'pending migration' do
      let(:fixture_file) { File.new('spec/fixtures/github_diff_with_data_migration.txt') }
      let(:running_commit) { '2392177' }
      let(:package_commit) { '8c6783b' }

      it { expect(check_diff.pending_migration?).to be true }
    end
  end

  describe '#migrations' do
    before do
      allow(ssh_driver).to receive(:installed_package_version).and_return(running_commit)
      allow(ssh_driver).to receive(:available_package_version).and_return(package_commit)
      stub_request(:get, diff_url).to_return(fixture_file)
    end

    subject { check_diff.migrations }

    context 'data is present' do
      context 'pending migration' do
        let(:fixture_file) { File.new('spec/fixtures/github_diff_with_migration.txt') }
        let(:migration_file) { 'db/migrate/20180110074142_change_handler_to_longtext_in_delayed_jobs.rb' }
        let(:running_commit) { '52a3a8b' }
        let(:package_commit) { '2c565b0' }

        it { expect(subject.first).to include(migration_file) }
      end

      context 'no pending migration' do
        let(:fixture_file) { File.new('spec/fixtures/github_diff_without_migration.txt') }
        let(:running_commit) { 'bc7f6c0' }
        let(:package_commit) { '554e943' }

        it { expect(subject).to be_empty }
      end
    end
  end
end
