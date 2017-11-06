# frozen_string_literal: true

class String
  def superstrip
    split(/\s/).delete_if(&:empty?).join(' ')
  end
end
