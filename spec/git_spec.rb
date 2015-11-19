require 'spec_helper'

describe "Git sanity check", :recipe => true do
  it "should not ask for a tag when doing a restart" do
    config.find_and_execute_task('deploy:restart')
  end

  describe 'branch check', :tag => true do
    describe "with a current_revision" do
      before(:each) do
        config.set :current_revision, '1'
        config.set :stage, 'development'
      end

      let(:task_lambda) {lambda { config.find_and_execute_task 'git:validate_branch_is_tag' }}

      it "should complain is the branch variable get overridden" do
        config.set :branch, 'release'
        expect(task_lambda).to raise_error(Capistrano::Error)
      end

      it "should not complain is the branch variable get overridden" do
        config.set :reverse_deploy_ok, true
        expect(task_lambda).to_not raise_error
      end
    end

    describe 'without a current revision' do
      before(:each) do
        config.set :current_revision, lambda { raise 'Error like capistrano' }
      end

      it "should return the branch without exception" do
        config.branch
      end
    end
  end
end

describe 'git_cut_tag' do
  let(:head) { double('head', name: :stompy) }
  let(:git_repo) do
    double(GitRepo, head_detached?: false, head: head, fetch: nil)
  end
  it 'pushes a new tag to remote' do
    allow(git_repo).to receive(:preferred_remote).and_return('stompy')
    expect(git_repo).to receive(:remote_tag)
      .with(anything, 'stompy')
    git_cut_tag(git_repo)
  end
end

describe 'update_tag_for_stage task', recipe: true do
  before(:each) do
    expect(GitRepo).to receive(:new).and_return(git_repo)
  end
  let(:git_repo) { double(GitRepo) }
  let(:stage) { 'foo' }
  let(:update_tag_for_stage) do
    lambda { config.find_and_execute_task 'git:update_tag_for_stage' }
  end

  it "updates tag on remote and adds deployment tag" do
    config.set :stage, stage
    allow(Time).to receive(:now).and_return(Time.utc(1970))

    allow(git_repo).to receive(:preferred_remote).and_return('stompy')
    expect(git_repo).to receive(:delete_remote_tag).with(stage, 'stompy')
    expect(git_repo).to receive(:remote_tag).with(stage, 'stompy')
    expect(git_repo).to receive(:remote_tag)
      .with("DEPLOYED---#{stage}---0", 'stompy')
    expect(update_tag_for_stage).to_not raise_error
  end
end
