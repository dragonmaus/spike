# frozen_string_literal: true

require 'secret'

module Config
  attr_reader :hostname, :nickname, :password, :realname, :username
  module_function :hostname, :nickname, :password, :realname, :username

  @hostname = 'pretty.princess'
  @nickname = 'Pinklestia'
  @password = Secret::Pinklestia::PASSWORD
  @realname = 'Pretty Princess Celestia'
  @username = 'pinklestia'
end
