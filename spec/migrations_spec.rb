require 'spec_helper'

describe "Migration check", :recipe => true do
  it "should run before deploy" do
    expect(before_callbacks_for_task('deploy')).to include('db:check_for_pending_migrations')
  end

  it "should not run before deploy:migrations" do
    expect(before_callbacks_for_task('deploy:migrations')).to_not include('db:check_for_pending_migrations')
  end

  describe "task execution" do
    let(:task_lambda) { lambda { config.find_and_execute_task 'db:check_for_pending_migrations' } }

    describe "with pending migrations" do
      before(:each) do
        expect(config).to receive(:pending_migrations) { [1] }
      end

      it "should prompt to continue and continue on success" do
        expect(config).to receive(:confirm) { true }
        task_lambda.call
      end

      it "should prompt to continue and fail on success" do
        expect(config).to receive(:confirm) { false }
        expect(task_lambda).to raise_error(Capistrano::Error)
      end
    end

    describe "without pending migrations" do
      before(:each) do
        expect(config).to receive(:pending_migrations) { [] }
      end

      it "should not prompt to continue and continue on success" do
        expect(config).to_not receive(:confirm) { true }
        task_lambda.call
      end
    end
  end

  describe "pending_migrations" do
    before(:each) do
      expect(config).to receive(:server_migrations) { [1,2] }
    end

    it "should return true if local migrations exist that have not been runned on the server" do
      expect(config).to receive(:local_migrations) { [1,2,3] }
      expect(config.pending_migrations).to eq [3]
    end

    it "should return false if no local migrations exist that have not been runned on the server" do
      expect(config).to receive(:local_migrations) { [1,2] }
      expect(config.pending_migrations).to eq []
    end
  end
end

