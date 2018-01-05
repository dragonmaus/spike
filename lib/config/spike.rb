# frozen_string_literal: true

require 'secret'

module Config
  attr_reader :hostname, :nickname, :password, :realname, :username
  module_function :hostname, :nickname, :password, :realname, :username

  @hostname = 'the.dragon'
  @nickname = 'MechaSpike'
  @password = Secret::Spike::PASSWORD
  @realname = 'Spike the Dragon'
  @username = 'spike'

  @channels = (@channels + %w[#derpibooru-pol]).sort
end
