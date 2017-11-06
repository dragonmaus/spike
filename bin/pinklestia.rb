# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path '../Gemfile', __dir__
load Gem.bin_path('bundler', 'bundle')

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'cinch'
require 'config/common'
require 'config/pinklestia'
require 'common'
require 'pinklestia'

bot = Cinch::Bot.new do
  configure do |c|
    c.channels = Config.channels
    c.message_split_end = '…'
    c.message_split_start = '… '
    c.nick = Config.nickname
    c.plugins.plugins = [Common, Pinklestia]
    c.realname = Config.realname
    c.sasl.password = Config.password
    c.sasl.username = Config.nickname
    c.server = Config.server
    c.user = Config.username
  end
end

bot.start
