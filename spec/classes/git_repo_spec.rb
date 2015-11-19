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
end
