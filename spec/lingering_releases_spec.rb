require 'spec_helper'

describe 'lingering_releases', recipe: true do
  describe 'task execution' do
    let(:task_lambda) { lambda { config.find_and_execute_task 'deploy:cleanup_lingering_releases' } }

    it 'should not raise any errors' do
      expect { task_lambda.call }.to_not raise_error
    end
  end
end
