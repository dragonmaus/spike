# frozen_string_literal: true

require 'json'
require 'patch'

class Pinklestia
  include Cinch::Plugin

  FACTS = JSON.parse File.read(File.expand_path('data/pinklestia.json', __dir__))

  match /\bpinklestia\b/i, method: :fact, use_prefix: false
  match /\A(\s*B+[[:blank:][:punct:]]*)\z/, method: :scream, use_prefix: false
  match /trigger(?:ed)?/i, method: :triggered

  def fact(m)
    return if Config.ignore? m.user

    fact = FACTS.sample
    m.action_reply fact['action'] if fact['action'].present?
    m.reply fact['text'] if fact['text'].present?
  end

  def scream(m, shout)
    return if m.user.authname != 'MechaSpike'

    m.reply shout.gsub(/B/, 'C')
  end

  def triggered(m)
    return if Config.ignore? m.user

    m.reply 'I AM A PRETTY PRETTY PRINCESS'
  end
end
