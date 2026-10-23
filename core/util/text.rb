module PokeAccess
  module Util
    # Joins parts into one spoken line (". " by default), dropping nils and blanks.
    def self.join_parts(parts, sep = ". ")
      parts.reject { |s| s.nil? || s.to_s.strip.empty? }.join(sep)
    end

    # A "type1/type2" phrase from two type names, one name when they match, blanks dropped; for a Pokemon
    # object use Data.pokemon_types.
    def self.types_phrase(t1, t2)
      types = [t1, t2].reject { |t| t.nil? || t.to_s.empty? }
      types.uniq.join("/")
    end

    # text with its first letter up and the rest down, as Ruby's own capitalize: nine games replace
    # String#capitalize with one that leaves the rest as it is and fails on an empty string.
    def self.capitalized(text)
      text.to_s.downcase.sub(/\A./mu) { |c| c.upcase }
    end
  end
end
