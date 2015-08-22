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

