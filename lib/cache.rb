# frozen_string_literal: true

require 'fileutils'
require 'json'

class Cache
  def initialize(name, default = {})
    @file = File.expand_path("../var/cache/#{name}.json", __dir__).freeze
    @data = if File.file?(@file)
              load || default
            else
              dir = File.dirname @file
              FileUtils.mkpath dir if !File.directory?(dir)
              FileUtils.rmtree @file if File.exist?(@file)
              save default
              default
            end
    @time = File.mtime @file
  end

  def data
    if File.mtime(@file) > @time
      @data = load
      @time = File.mtime @file
    end
    @data
  end

  def data=(new_data)
    save new_data
  end

  private

  def load
    JSON.parse File.read(@file)
  end

  def save(new_data)
    temp = "#{@file}{new}"
    FileUtils.rmtree temp if File.exist?(temp)
    File.write temp, new_data.to_json
    File.rename temp, @file
  end
end
