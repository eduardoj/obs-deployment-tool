# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ObsDeploy::CheckDiff do
  let(:ssh_driver) { double('ObsDeploy::SSH') }
  let(:check_diff) { described_class.new(ssh_driver: ssh_driver) }
  let(:running_commit) { '52a3a8b' }
  let(:package_commit) { '2c565b0' }
  let(:diff_url) do
    "https://github.com/openSUSE/open-build-service/compare/#{running_commit}...#{package_commit}.diff"
  end
  let(:fixture_file) { File.new('spec/fixtures/github_diff_without_migration.txt') }

  before do
    allow(ssh_driver).to receive(:installed_package_version).and_return(running_commit)
    allow(ssh_driver).to receive(:available_package_version).and_return(package_commit)
    stub_request(:get, diff_url).to_return(fixture_file)
  end

  it { expect(check_diff).not_to be_nil }

  describe '#pending_migration?' do
    subject { check_diff.pending_migration? }

    context 'data is present' do
      context 'pending migration' do
        let(:fixture_file) { File.new('spec/fixtures/github_diff_with_migration.txt') }

        it { is_expected.to be true }
      end
      context 'no pending migration' do
        it { is_expected.to be false }
      end
    end

    context 'no data is present' do
      context 'if no available package' do
        let(:package_commit) { nil }

        it { is_expected.to be false }
      end

      context 'if no git diff is present it should abort' do
        before do
          dbl = double('Net::HTTP response')
          allow(dbl).to receive(:class).and_return(Net::HTTPNotFound)
          allow(Net::HTTP).to receive(:get_response).and_return(dbl)
        end

        it { expect { check_diff.pending_migration? }.to raise_error Exception }
      end
    end
  end

  describe '#pending_data_migration?' do
    subject { check_diff.pending_data_migration? }

    context 'if pending data migration is present' do
      let(:fixture_file) { File.new('spec/fixtures/github_diff_with_data_migration.txt') }

      it { is_expected.to be true }
    end
  end

  describe '#migrations' do
    subject { check_diff.migrations }

    context 'data is present' do
      context 'pending migration' do
        let(:fixture_file) { File.new('spec/fixtures/github_diff_with_migration.txt') }
        let(:migration_file) { 'db/migrate/20201209105103_add_channel_disable_flag.rb' }

        it { expect(subject).to contain_exactly(migration_file) }
      end

      context 'no pending migration' do
        it { is_expected.to be_empty }
      end
    end
  end
end
