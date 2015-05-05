require 'spec_helper'

describe 'deploy slowly', recipe: true do
  it 'returns error when given out of range value' do
    config.set :slow_block_size, 1.1
    config.find_and_execute_task 'deploy:slow'
    puts "daklsdf;asjkldf"
  end
end
