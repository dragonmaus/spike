# frozen_string_literal: true

# Shamelessly ripped from Rails.

class Array
  alias blank? empty?
end

class FalseClass
  def blank?
    true
  end
end

class Hash
  alias blank? empty?
end

class NilClass
  def blank?
    true
  end
end

class Numeric
  def blank?
    false
  end
end

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def present?
    !blank?
  end

  def presence
    self if present?
  end
end

class String
  BLANK_RE = /\A[[:space:]]*\z/

  def blank?
    empty? || BLANK_RE.match?(self)
  end
end

class Time
  def blank?
    false
  end
end

class TrueClass
  def blank?
    false
  end
end
