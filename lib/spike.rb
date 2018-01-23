# frozen_string_literal: true

require 'addressable/uri'
require 'cache'
require 'json'
require 'keystore'
require 'patch'
require 'restclient'
require 'secret'

class Spike
  include Cinch::Plugin

  GREETINGS = JSON.parse File.read(File.expand_path('data/greetings.json', __dir__))

  listen_to :connect, method: :boot
  listen_to :online, method: :deliver

  match /((?:https?:\/\/)?(?:\w+\.)*google\.(?:com|(?:co\.)?[a-z]{2})(?:\S*[^[:space:]!"',.:;>?])?)/i, method: :google_uri, use_prefix: false
  # match /\bkeikaku\b/i, method: :means_plan, use_prefix: false
  match /b(?:ing)?(\s.*)?\z/i, method: :bing
  match /cdj(?:ack)?(?:\s+(\d+)\s+(\d+))?\z/i, method: :jack
  match /d(?:dg|uckduckgo)?(\s.*)?\z/i, method: :duckduckgo
  match /\A(?:greetings|hello|hi),?\s(.*)\z/i, method: :greetings, use_prefix: false
  # match /dear\s+(\S+?),?\s+(\S.*)\z/, method: :mail
  match /dict(?:ionary)?(?:\s(.*))?\z/i, method: :dictionary
  match /g(?:oogle)?(\s.*)?\z/i, method: :google
  # match /ping([a-z]*)/i, method: :ping
  # match /rimshot/i, method: :rimshot
  match /\A([^[:alpha:]]*[[:blank:][:upper:]]+[^[:alpha:]]*)\z/, method: :scream, use_prefix: false
  # match /trigger(?:ed)?/i, method: :triggered

  def bing(m, query)
    return if Config.ignore? m.user

    query = String(query).superstrip.downcase
    uri = Addressable::URI.parse 'https://www.bing.com/search'
    uri.query = uri.class.form_encode q: query if query.present?

    m.reply uri
  end

  def boot(*)
    return
    @mail ||= Cache.new 'mail'
    @mail.data.each_key { |nick| User(nick).monitor } if @mail.data.present?
  end

  def deliver(_m, user)
    return if @mail.blank?

    mail = @mail.data
    return if mail[user.nick].blank?

    user.channels.each do |c|
      next if !c.users.include? bot
      messages = mail[user.nick].delete c.to_s
      next if messages.blank?

      c.send "Message#{messages.keys.length == 1 ? '' : 's'} for you, #{user.nick}!"
      messages.each { |s, m| c.send "=> From #{s} at #{Time.at(m['stamp']).utc.strftime('%a, %e %b, %k:%M:%S %Z')}: #{m['message']}" }
    end

    if mail[user.nick].blank?
      mail.delete user.nick
      user.unmonitor
    end
    @mail.data = mail
  end

  def dictionary(m, query)
    return if Config.ignore? m.user

    headers = { 'accept' => 'application/json',
                'app_id' => Secret::OxfordDictionary::APP_ID,
                'app_key' => Secret::OxfordDictionary::APP_KEY }
    original_query = query
    query = String(original_query).downcase.split(/[^-_a-z]/).reject(&:blank?).join('_').gsub(/_*-_*/, '-').gsub(/__+/, '_')
    return m.reply 'https://en.oxforddictionaries.com/' if query.blank?
    url = "https://od-api.oxforddictionaries.com/api/v1/entries/en/#{query}"

    @dictionary ||= Keystore.new 'dictionary'
    entry = JSON.parse(@dictionary.get(query) || '{}')

    if entry.blank? || Time.at(entry['last_update'].to_i) < (Time.now - 2.fortnights)
      new_entry = begin
        response = RestClient.get url, headers
        throw if response.code != 200
        JSON.parse(response.body)
      rescue
        entry.presence || { 'status' => 'not found' }
      end.reject { |k, _| k == 'last_update' }

      if entry.blank? || new_entry != entry.reject { |k, _| k == 'last_update' }
        entry = new_entry.merge('last_update' => Time.now.to_i)
        @dictionary.set(query, entry.to_json)
      end
    end

    if entry.blank? || entry['status'] == 'not found'
      m.reply %["#{original_query}"? That's not even a word! (At least according to the Oxford English Dictionary.)]
    else
      word           = entry['results'][0]['word']
      part_of_speech = entry['results'][0]['lexicalEntries'][0]['lexicalCategory'].downcase
      pronunciation  = entry['results'][0]['lexicalEntries'][0]['pronunciations'][0]['phoneticSpelling']
      definition     = entry['results'][0]['lexicalEntries'][0]['entries'][0]['senses'][0]['definitions'][0]
      m.reply %["#{word}", #{part_of_speech} (/#{pronunciation}/)]
      m.reply definition
    end
  end

  def duckduckgo(m, query)
    return if Config.ignore? m.user

    query = String(query).superstrip.downcase
    uri = Addressable::URI.parse 'https://duckduckgo.com/'
    uri.query = uri.class.form_encode q: query if query.present?

    m.reply uri
  end

  def google(m, query)
    return if Config.ignore? m.user

    query = String(query).superstrip.downcase
    uri = Addressable::URI.parse 'https://www.google.com/search'
    uri.query = uri.class.form_encode q: query if query.present?

    m.reply uri
  end

  def google_uri(m, old_uri)
    return if Config.ignore? m.user

    uri = Addressable::URI.parse old_uri
    uri = Addressable::URI.parse "https://#{old_uri}" if uri.scheme.blank?

    if uri.host != 'www.google.com'
      host = uri.host.split '.'
      host.pop until host[-1] == 'google'
      host.unshift 'www' if host.length == 1
      host.push 'com'
      uri.host = host.join '.'
    end
    uri.scheme = 'https' if uri.scheme != 'https'

    if uri.fragment.present? && uri.fragment.include?('=')
      uri.query = uri.fragment
      uri.fragment = nil
    end

    if uri.query_values.present?
      return m.reply uri.query_values['url'] if uri.query_values['url'].present?

      if uri.query_values['q'].present?
        uri.fragment = nil
        uri.path = '/search'
        query = {}
        query['q'] = uri.query_values['q']
        query['tbm'] = uri.query_values['tbm'] if uri.query_values['tbm'].present?
        uri.query = uri.class.form_encode query, true
      end
    end

    uri.fragment = nil if uri.fragment.blank?
    uri.path = '/' if uri.path.blank?
    uri.query = nil if uri.query.blank?

    m.reply uri if uri.to_s != old_uri
  end

  def greetings(m, nicks)
    return if !mentioned_in? nicks

    now = Time.now.utc.round

    # completely arbitrary
    morn = Time.mktime(now.year, now.month, now.day, 6, 0, 0)
    noon = Time.mktime(now.year, now.month, now.day, 12, 0, 0)
    even = Time.mktime(now.year, now.month, now.day, 18, 0, 0)
    night = Time.mktime(now.year, now.month, now.day, 20, 0, 0)

    greetings = []
    greetings += GREETINGS['general']
    if now >= morn && now < noon
      greetings += GREETINGS['morning']
    elsif now > noon && now < even
      greetings += GREETINGS['afternoon']
    elsif now >= even && now < night
      greetings += GREETINGS['evening']
    end

    response = ['', ', ' + m.user.name]
    punctuation = ['.', '!']

    m.reply greetings.sample + response.sample + punctuation.sample
  end

  def jack(m, season, episode)
    now = Time.now.utc.round

    data = {}

    File.readlines(File.expand_path('data/jack.list', __dir__)).each do |line|
      x, d, s, e, t = line.strip.split /\s+/, 5
      continue if x != 'JACK'

      d = Time.at(d.to_i).utc
      s = s.to_i
      e = e.to_i

      if season.blank? && episode.blank? && d >= now
        season = s
        episode = e
      end

      data[s] ||= {}
      data[s][e] = { airdate: d, title: t }
    end

    season = season.to_i
    episode = episode.to_i

    return m.reply "Air time of season #{season} episode #{episode} is unknown" if data[season].blank? || data[season][episode].blank?

    airdate = data[season][episode][:airdate]
    title = data[season][episode][:title]

    m.reply "Episode #{episode} of season #{season} \"#{title}\" #{now > airdate ? 'aired' : 'airs'} #{time_distance(now, airdate)} (#{airdate.strftime('%b %d %T %Y %z %Z')})"
  end

  def mail(m, nick, message)
    return if Config.ignore? m.user

    return m.reply "I'm right here, you know…" if User(nick) == bot

    @mail ||= Cache.new 'mail'

    mail = @mail.data
    target = mail[nick] || {}
    channel = target[m.channel.to_s] || {}
    source = route[m.user.nick] || {}

    source['message'] = message
    source['stamp'] = m.time.to_i

    channel[m.user.nick] = source.sort.to_h
    target[m.channel.to_s] = channel.sort.to_h
    mail[nick] = target.sort.to_h
    @mail.data = mail.sort.to_h

    User(nick).monitor

    m.action_reply 'rolls the letter up and breathes flame onto it'
  end

  def means_plan(m)
    return if Config.ignore? m.user
    return if /\bkeikaku\s+means\s+plan\b/i.match?(m.message)

    m.reply "(Translator's note: keikaku means plan)"
  end

  def ping(m, s)
    return if Config.ignore? m.user

    m.reply "pong#{s}!"
  end

  def rimshot(m)
    return if Config.ignore? m.user

    m.reply 'https://www.youtube.com/watch?v=uXILNncQwH4'
  end

  def scream(m, shout)
    return if m.user.authname != 'RepentantAnon'
    return if rand(8) > 0

    m.reply shout.tr('A-Z', 'B-ZA')
  end

  def triggered(m)
    return if Config.ignore? m.user

    m.reply 'Nopony ever invites me to any parties'
  end

  private

  def pluralise(quantity, singular, plural = nil)
    plural ||= singular + 's'

    "#{quantity} #{quantity == 1 ? singular : plural}"
  end

  def time_distance(from, to)
    return 'right now!' if from == to

    seconds = (to - from).abs
    minutes = hours = days = weeks = 0

    if seconds >= 1.week
      weeks = (seconds / 1.week).floor
      seconds -= weeks * 1.week
    end

    if seconds >= 1.day
      days = (seconds / 1.day).floor
      seconds -= days * 1.day
    end

    if seconds >= 1.hour
      hours = (seconds / 1.hour).floor
      seconds -= hours * 1.hour
    end

    if seconds >= 1.minute
      minutes = (seconds / 1.minute).floor
      seconds -= minutes * 1.minute
    end

    seconds = seconds.round

    distance = "#{pluralise(weeks, 'week')}, #{pluralise(days, 'day')}, #{pluralise(hours, 'hour')}, #{pluralise(minutes, 'minute')}, and #{pluralise(seconds, 'second')}"
    from < to ? "in #{distance}" : "#{distance} ago"
  end

  def mentioned_in?(nicks)
    nicks.downcase
         .tr(',', ' ')
         .gsub(/\s+/, ' ')
         .strip
         .split(' ')
         .include? bot.nick.downcase
  end
end
