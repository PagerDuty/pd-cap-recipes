require 'spec_helper'

describe 'Commit comments', recipe: true do
  describe 'without a current revision', tag: true do
    before(:each) do
      config.set :current_revision, lambda { raise 'Error' }
      ENV['EDITOR'] = "echo 'Some comment' >> #{COMMENT_FILE}"
    end

    it 'should get comment without exception' do
      expect { config.comment }.to_not raise_error
    end
  end
end
