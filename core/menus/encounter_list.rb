module PokeAccess
  # What encounter screens share (the Encounter List UI and Simple Encounter List plugins, profiles): each species as
  # its icon shows it, with its Pokedex status, and a type's summary at the Pokedex reading's level.
  module EncounterList
    MAX = 15

    # One species of the list as [name, Pokedex status key], from the live game.
    # param repeated true when the list shows this species in another form too
    def self.entry(sp, repeated = false)
      dex = (PokeAccess::Engine.player.pokedex rescue nil)
      st = (dex.owned?(sp) rescue false) ? :dex_caught : ((dex.seen?(sp) rescue false) ? :dex_seen : :dex_unknown)
      [species_label(sp, repeated), st]
    end

    # A species as its icon shows it: the name, and its form's name for a form other than the first (a regional one,
    # a flower colour) or for any form while the list shows the species in several; the form's name alone where it
    # already holds the species'. An engine without forms by id, or a form with no name, keeps the name alone.
    def self.species_label(sp, repeated = false)
      name = (PokeAccess::Data.species_name(sp) || sp.to_s).to_s
      data = (GameData::Species.get(sp) rescue nil)
      return name unless (data.form rescue 0).to_i > 0 || repeated
      form = PokeAccess.clean((data.form_name rescue nil).to_s)
      return name if form.empty?
      form.include?(name) ? form : PokeAccess::I18n.t(:enc_form, :name => name, :form => form)
    end

    # The species a form belongs to (:FLABEBE for :FLABEBE_1), or the id itself where the engine has no forms by id.
    def self.base_species(sp)
      (GameData::Species.get(sp).species rescue nil) || sp
    end

    # One species as it is said in the list: its name and its Pokedex status.
    # param whole true for the info key, which says the status at any level
    def self.entry_text(sp, whole = false)
      nm, st = entry(sp)
      phrase(nm, st, whole)
    end

    # A species in the list: its name, plus its caught or seen state from the Pokedex reading's medium level; an
    # unseen one only as unknown, since the screen hides it. A nil status, for a list that marks none, is the name.
    # param whole true for the info key, which says the state at any level
    def self.phrase(name, status, whole = false)
      return name.to_s if status.nil?
      return PokeAccess::I18n.t(:dex_unknown) if status == :dex_unknown
      return name.to_s unless whole || PokeAccess::Verbosity.keep?(:dex_entry, :medium)
      "#{name} #{PokeAccess::I18n.t(status)}"
    end

    # The type header and up to MAX species at the Pokedex reading's level: states from medium, the count from full
    # (and always for an empty type). Pure (no engine calls).
    # param whole true for the info key, which says all of it at any level
    def self.summary(type_name, entries, whole = false)
      return nil if entries.nil?
      counted = whole || entries.empty? || PokeAccess::Verbosity.keep?(:dex_entry, :full)
      head = counted ? PokeAccess::I18n.t(:enc_type, :type => type_name, :n => entries.length) : type_name.to_s
      return head if entries.empty?
      shown = entries[0, MAX].map { |nm, st| phrase(nm, st, whole) }
      more = entries.length > MAX ? ", " + PokeAccess::I18n.t(:enc_more, :n => entries.length - MAX) : ""
      "#{head}: #{shown.join(', ')}#{more}"
    end
  end
end
