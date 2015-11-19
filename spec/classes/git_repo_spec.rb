require 'rspec'
require 'pd-cap-recipes/classes/git_repo'

describe(GitRepo) do
  subject { GitRepo.new }
  let(:git) { double(Grit::Git).as_null_object }
  let(:tag) { 'xyz' }
  before(:each) do
    allow(Grit::Git).to receive(:new).and_return(git)
  end

  describe('#remote_tag') do
    it 'by default pushes a tag to origin' do
      expect(git).to receive(:tag).with(anything, tag)
      expect(git).to receive(:push)
        .with(anything, 'origin', "refs/tags/#{tag}")
      subject.remote_tag(tag)
    end
    it 'allows remote to be overridden' do
      expect(git).to receive(:push) .with(anything, 'stompy', anything)
      subject.remote_tag(tag, 'stompy')
    end
  end

  describe('#delete_remote_tag') do
    it 'by default deletes tag at origin' do
      expect(git).to receive(:tag).with(d: tag)
      expect(git).to receive(:push)
        .with(anything, 'origin', ":refs/tags/#{tag}")
      subject.delete_remote_tag(tag)
    end
    it 'allows remote to be overridden' do
      expect(git).to receive(:push) .with(anything, 'stompy', anything)
      subject.delete_remote_tag(tag, 'stompy')
    end
  end

  describe('#preferred_remote') do
    let(:config_keys) do
      # Partial list from `Grit::Repo.new('.').config.keys`
      [
        "user.email",
        "fetch.prune",
        "core.repositoryformatversion",
        "remote.slurp.url",
        "remote.slurp.fetch",
        "branch.master.remote",
        "branch.master.merge"
      ]
    end
    let(:repo) { instance_double(Grit::Repo) }
    let(:config) { instance_double(Grit::Config) }
    subject { GitRepo.new }

    before(:each) do
      allow(Grit::Repo).to receive(:new).and_return(repo)
      allow(repo).to receive(:config).and_return(config)
    end

    describe('when only one remote') do
      it 'returns that remote' do
        allow(config).to receive(:keys).and_return(config_keys)
        expect(subject.preferred_remote).to eq('slurp')
      end
    end
    describe('when multiple remotes') do
      it 'returns origin' do
        allow(config).to receive(:keys).and_return(
          config_keys + ["remote.abc.url", "remote.abc.fetch"]
        )
        expect(subject.preferred_remote).to eq('origin')
      end
    end
  end
end
