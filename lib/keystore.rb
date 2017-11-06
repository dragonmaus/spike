# frozen_string_literal: true

require 'English'
require 'cdb'

class Keystore
  def initialize(name)
    @file = File.expand_path("../var/cache/#{name}.cdb", __dir__).freeze
  end

  def get(key)
    CDB.open(@file) { |db| db.find(key) } if File.file?(@file)
  end

  def set(key, data)
    if File.file?(@file)
      CDB.update(@file, "#{@file}.#{$PROCESS_ID}.#{Time.now.to_i}.new") do |old, new|
        old.each { |k, d| new.add(k, d) }
        new.add(key, data)
      end
    else
      CDB.create(@file, "#{@file}.#{$PROCESS_ID}.#{Time.now.to_i}.new") { |new| new.add(key, data) }
    end
  end
end
