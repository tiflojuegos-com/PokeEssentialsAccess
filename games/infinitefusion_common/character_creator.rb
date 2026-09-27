# Infinite Fusion's character creator (CharacterSelectMenuPresenter): name, gender, age, skin, hair and confirm rows. The values are
# painted on a bitmap and four rows change on left/right, so each read is deduped on [row, value], the value taken
# from the presenter's ivars.
module PokeAccess
  module CharacterCreator
    ROWS = { "Name" => :name, "Gender" => :gender, "Age" => :age,
             "Skin" => :skin, "Hair" => :hair, "Confirm" => :confirm }
    GENDER_KEYS = [:chr_female, :chr_male]
    HAIR_KEYS   = [:chr_hair_blonde, :chr_hair_light_brown, :chr_hair_dark_brown, :chr_hair_black]

    # Voices the row the cursor sits on, with its current value, once per change of either.
    def self.focus(pres)
      idx = PokeAccess.ivar(pres, :@current_index)
      announce_row(pres, idx) if idx.is_a?(Integer)
    end

    # The opening read: row 0, where main starts, of the current @options (a rival-select variant swaps them first).
    def self.open(pres)
      PokeAccess::Cursor.store(pres, :charcreate_name, name_value(pres))
      announce_row(pres, 0)
    end

    # Says the name row, queued, when the screen repaints it with another name: one typed, or the default the confirm
    # fills in before its question; the row's own read, if the cursor is on it, is kept from repeating it.
    def self.name_shown(pres)
      value = name_value(pres)
      return unless PokeAccess::Cursor.changed?(pres, :charcreate_name, value)
      opts = PokeAccess.ivar(pres, :@options)
      idx = opts.is_a?(Array) ? opts.index { |o| ROWS[o.to_s] == :name } : nil
      PokeAccess::Cursor.store(pres, :charcreate, [idx, value]) if idx && idx == PokeAccess.ivar(pres, :@current_index)
      PokeAccess.speak(PokeAccess::I18n.t(:chr_value, :name => PokeAccess::I18n.t(:chr_name), :value => value), false)
    rescue StandardError
      nil
    end

    # Speaks "row: value", or just the row for one without a value (Confirm), with its place when positions are on.
    def self.announce_row(pres, idx)
      opts = PokeAccess.ivar(pres, :@options)
      return unless opts.is_a?(Array) && idx >= 0 && idx < opts.length
      kind = ROWS[opts[idx].to_s]
      value = value_of(pres, kind)
      PokeAccess::Cursor.announce(pres, :charcreate, [idx, value], true) do
        name = row_label(opts[idx], kind)
        row = value.nil? ? name : PokeAccess::I18n.t(:chr_value, :name => name, :value => value)
        PokeAccess::Verbosity.list_entry(row, idx + 1, opts.length)
      end
    rescue StandardError
      nil
    end

    # The translated row name; the game's own caption for an unknown row.
    def self.row_label(raw, kind)
      return PokeAccess.clean(raw.to_s) if kind.nil?
      PokeAccess::I18n.t(:"chr_#{kind}")
    end

    # The row's current value as a spoken string, or nil for a row that holds none.
    def self.value_of(pres, kind)
      case kind
      when :name   then name_value(pres)
      when :gender then from_keys(GENDER_KEYS, PokeAccess.ivar(pres, :@gender))
      when :age    then PokeAccess.ivar(pres, :@age).to_s
      when :skin   then skin_value(pres)
      when :hair   then from_keys(HAIR_KEYS, PokeAccess.ivar(pres, :@hairColor))
      end
    end

    # The name typed so far, or the no-name word while blank (the default is only filled in on confirm).
    def self.name_value(pres)
      n = PokeAccess.clean(PokeAccess.ivar(pres, :@name).to_s)
      n.empty? ? PokeAccess::I18n.t(:chr_no_name) : n
    end

    # Skin tone as the letter the screen shows ("Type C" -> "C") from the class's SKIN_COLOR_IDS, else the raw number.
    def self.skin_value(pres)
      tone = PokeAccess.ivar(pres, :@skinTone).to_i
      ids = class_const(:SKIN_COLOR_IDS)
      label = (ids.is_a?(Array) && tone >= 1 && tone <= ids.length) ? ids[tone - 1].to_s.split(" ").last : nil
      PokeAccess::I18n.t(:chr_skin_type, :n => (label && !label.empty?) ? label : tone.to_s)
    end

    # Translated entry of a fixed list, or nil when the index falls outside it.
    def self.from_keys(keys, idx)
      return nil unless idx.is_a?(Integer) && idx >= 0 && idx < keys.length
      PokeAccess::I18n.t(keys[idx])
    end

    # A constant off the presenter class, or nil if this build does not define it.
    def self.class_const(name)
      k = PokeAccess.const_at("CharacterSelectMenuPresenter")
      (k && k.const_defined?(name)) ? k.const_get(name) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  before("CharacterSelectMenuPresenter", :main, :optional => true) do |pres, _a|
    PokeAccess::CharacterCreator.open(pres)
  end
  [:update_cursor, :move_menu_vertical, :move_menu_horizontal].each do |meth|
    after("CharacterSelectMenuPresenter", meth, :optional => true) do |pres, _r, _a|
      PokeAccess::CharacterCreator.focus(pres)
    end
  end
  after("CharacterSelectMenuPresenter", :updateDisplayedName, :optional => true) do |pres, _r, _a|
    PokeAccess::CharacterCreator.name_shown(pres)
  end
end
