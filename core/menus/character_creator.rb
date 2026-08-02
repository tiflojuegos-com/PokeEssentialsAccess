# Character creator (CharacterSelectMenuPresenter, 050_Outfits/UI/): the first screen a new game shows --
# name, gender, age, skin, hair, confirm. The games that bundle it ship the very same class, so this
# registers globally and simply never binds where the class is absent.
#
# Two things made it unreadable. The view paints the VALUES with pbDrawTextPositions onto a bare
# BitmapSprite -- only the "Confirm" caption goes through Kernel.pbDisplayText -- so the HUD text reader
# (core/field/hud_text) never saw the chosen name, gender, age, skin or hair. And a reader keyed on the row
# index alone stays silent through the whole left/right axis, which is where four of the six rows are
# actually edited: the row does not change, only its value does. Keying the dedup on [row, value] fixes
# both, and the value is read from the presenter's own ivars rather than scraped off the sprites.
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

    # The opening read. main sets @current_index = 0 right after entering, and the rival-select variant swaps
    # @options before calling it, so row 0 of the CURRENT options is what the player is about to be shown.
    def self.open(pres)
      announce_row(pres, 0)
    end

    # Speaks "row: value, n of total" (or just the row where there is nothing to edit, as with Confirm).
    def self.announce_row(pres, idx)
      opts = PokeAccess.ivar(pres, :@options)
      return unless opts.is_a?(Array) && idx >= 0 && idx < opts.length
      kind = ROWS[opts[idx].to_s]
      value = value_of(pres, kind)
      PokeAccess::Cursor.announce(pres, :charcreate, [idx, value], true) do
        name = row_label(opts[idx], kind)
        if value.nil?
          PokeAccess::I18n.t(:chr_row_plain, :name => name, :n => idx + 1, :tot => opts.length)
        else
          PokeAccess::I18n.t(:chr_row, :name => name, :value => value, :n => idx + 1, :tot => opts.length)
        end
      end
    rescue StandardError
      nil
    end

    # The translated row name, falling back to the game's own English caption for a row we do not know.
    def self.row_label(raw, kind)
      return PokeAccess.clean(raw.to_s).to_s.strip if kind.nil?
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

    # The name typed so far; the creator starts blank and only fills a default in on confirm.
    def self.name_value(pres)
      n = PokeAccess.clean(PokeAccess.ivar(pres, :@name).to_s).to_s.strip
      n.empty? ? PokeAccess::I18n.t(:chr_no_name) : n
    end

    # Skin tone as the letter the screen shows ("Type C" -> "C"), taken from the game's own list so a build
    # with more or fewer tones still reads right; the raw number if that list is not where we expect it.
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

PokeAccess::Hooks.before_hook("CharacterSelectMenuPresenter", :main) do |pres, _a|
  PokeAccess::CharacterCreator.open(pres)
end

["update_cursor", "move_menu_vertical", "move_menu_horizontal"].each do |meth|
  PokeAccess::Hooks.after_hook("CharacterSelectMenuPresenter", meth.to_sym) do |pres, _r, _a|
    PokeAccess::CharacterCreator.focus(pres)
  end
end
