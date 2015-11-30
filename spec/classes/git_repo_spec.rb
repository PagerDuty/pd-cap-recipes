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
    it 'pushes tag to preferred remote' do
      expect(git).to receive(:tag).with(anything, tag)
      expect(git).to receive(:push).with(anything, 'slurp', "refs/tags/#{tag}")

      subject.preferred_remote = 'slurp'
      subject.remote_tag(tag)
    end
  end

  describe('#delete_remote_tag') do
    it 'deletes tag on preferred–remote' do
      expect(git).to receive(:tag).with(d: tag)
      expect(git).to receive(:push).with(anything, 'slurp', ":refs/tags/#{tag}")
      subject.preferred_remote = 'slurp'
      subject.delete_remote_tag(tag)
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
    describe('when preferred_remote is set') do
      it 'returns that it is set to' do
        subject.preferred_remote = 'sloop'
        expect(subject.preferred_remote).to eq('sloop')
      end
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
