module PokeAccess
  # Pokedex data entry: reads the page (category and description) the battle opens when a newly-caught
  # species is registered. Name/category/description come from the engine's data provider.
  module Pokedex
    # Formats a tenth-units integer (decimetres/hectograms) as one decimal, with the separator the active
    # language declares (lang key decimal_sep: comma in Spanish, point in English) rather than one fixed per
    # engine. Shared by every dex height/weight reader.
    def self.fmt_dec(v)
      fmt_float(v / 10.0)
    rescue StandardError
      v.to_s
    end

    # One decimal place with the language's separator (see fmt_dec), for values already in real units.
    def self.fmt_float(f)
      s = format("%.1f", f.to_f)
      (PokeAccess::I18n.t(:decimal_sep).to_s == ",") ? s.gsub(".", ",") : s
    rescue StandardError
      f.to_s
    end

    # Builds the spoken pokedex entry for a species (name, category, description), via PokeAccess::Data
    # so it reads on either engine.
    #
    # A Pokemon is accepted as well as a species id, because one game hands over the Pokemon:
    # infinitefusion_hoenn calls pbShowPokedex(pkmn) from 001_PokeBattle_BattleCommon and unwraps it inside
    # the screen, while the other twelve pass an id. Fed a Pokemon,
    # GameData::Species.get raises, this rescued to nil, and the dex page shown on a new capture was silent
    # in that game alone. Unwrapped here rather than at each hook so every caller gets it.
    def self.entry_text(species)
      return nil unless species
      species = species.species if species.respond_to?(:species)
      parts = PokeAccess::Data.species_entry(species)
      return nil unless parts
      name, kind, desc = parts
      name = species.to_s if name.nil? || name.to_s.empty?
      return nil if name.to_s.empty? && (kind.nil? || kind.to_s.empty?) && (desc.nil? || desc.to_s.empty?)
      t = PokeAccess::I18n.t(:pdx_entry_name, :name => name)
      t += " " + PokeAccess::I18n.t(:pdx_entry_kind, :kind => kind) if kind && !kind.to_s.empty?
      t += " #{desc}" if desc && !desc.to_s.empty?
      (PokeAccess.clean(t) rescue t)
    rescue StandardError
      nil
    end
  end
end

# Read the pokedex page shown when a new species is registered after capture, on either engine.
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbShowPokedex) do |_s, args|
  PokeAccess.speak(PokeAccess::Pokedex.entry_text(args[0]), false)
end
PokeAccess::Hooks.before_hook("Battle::Scene", :pbShowPokedex) do |_s, args|
  PokeAccess.speak(PokeAccess::Pokedex.entry_text(args[0]), false)
end
