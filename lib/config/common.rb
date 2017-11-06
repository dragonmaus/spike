# frozen_string_literal: true

module Config
  attr_reader :channels, :server
  module_function :channels, :server

  @ignore = %w[
    MechaSpike
    Pinklestia
    ScienceSpike
    Sonata_Dusk
    Sweetie-Bot
    Taz
  ]

  @channels = %w[
    #derpibooru
    #dragon-test
  ]

  @server = 'irc.ponychat.net'

  @super = %w[
    DragonWraith
  ]

  def ignore?(user)
    @ignore.include? user.authname
  end

  def super?(user)
    user.authed? && @super.include?(user.authname)
  end

  module_function :ignore?, :super?
end
