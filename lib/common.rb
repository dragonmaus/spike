# frozen_string_literal: true

class Common
  include Cinch::Plugin

  listen_to :connect, method: :connect
  listen_to :leaving, method: :rejoin

  match /\Agoodbye,?\s(.*)\z/i, method: :goodbye, use_prefix: false
  match /\Aregister\s+with\s+(\w+)serv,?\s(.*)\z/i, method: :register, use_prefix: false

  def connect(*)
    nick = bot.nick.sub /_+\z/, ''
    return if nick == bot.nick

    User('NickServ').send "GHOST #{nick} #{bot.config.sasl.password}"
    bot.nick = nick # try to commit the change as soon as possible
    sleep 2
    bot.nick = nick # in case the first try doesn't work
  end

  def goodbye(m, nicks)
    return if !Config.super? m.user
    return if !mentioned_in? nicks

    m.reply 'Goodbye!'
    bot.quit
  end

  def register(m, type, nicks)
    return if !Config.super? m.user
    return if !mentioned_in? nicks

    case type.downcase
    when 'host'
      User('NickServ').send "IDENTIFY #{Config.nickname} #{Config.password}"
      sleep 1
      User('HostServ').send "REQUEST #{Config.hostname}"

      m.reply "Vhost #{Config.hostname} requested!"
    when 'nick'
      User('NickServ').send "REGISTER #{Config.password} #{Config.username}@#{Config.hostname}"

      m.reply 'Nickname registered!'
    end
  end

  def rejoin(m, user)
    return if user != bot.nick
    bot.quit if m.user == bot # we've been ghosted

    sleep 2 # allow for channels with +J set
    bot.join m.channel
  end

  private

  def mentioned_in?(nicks)
    nicks.downcase
         .tr(',', ' ')
         .gsub(/\s+/, ' ')
         .strip
         .split(' ')
         .include? bot.nick.downcase
  end
end
