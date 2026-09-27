# Opalo's new-game look (Map001): three portraits in a row (hombre/mujer + Ario, Mulato, Negro), chosen with the
# options Izquierda, Medio and Derecha; the one chosen is shown again alone and pbChangePlayer puts it on. The
# portraits and the player's trainer types (POKEMONTRAINER_HombreArio...) name the skin the same way.
module PokeAccess
  module OpaloLooks
    # Name ending => the skin it shows.
    SKINS = [[/Ari[oa]\z/, :op_skin_light], [/Mulat[oa]\z/, :op_skin_medium], [/Negr[oa]\z/, :op_skin_dark]]

    # The y the portraits stand at while they are the choice.
    ROW_Y = 70

    @row = {}
    @picked = false
    @before = nil

    # The skin key a portrait or trainer type name shows, or nil.
    def self.skin(name)
      pair = SKINS.find { |re, _key| name.to_s =~ re }
      pair ? pair[1] : nil
    end

    # Speaks a look as its sex word and its skin, leaving out whichever is unknown.
    def self.say(sex_word, skin_key)
      parts = [sex_word, skin_key ? PokeAccess::I18n.t(skin_key) : nil].compact
      PokeAccess.speak(parts.join(", "), true) unless parts.empty?
    end

    # Keeps the portraits by x while they stand in a row; the one shown alone afterwards is the pick, said as the
    # sex and skin it shows.
    # param x, y where the picture is shown
    def self.on_picture(name, x, y)
      return unless name.to_s =~ /\A(hombre|mujer)/
      key = skin(name)
      return unless key
      if y.to_i == ROW_Y
        @row[x.to_i] = key
      elsif !@row.empty?
        @row = {}
        @picked = true
        say(PokeAccess::I18n.t(PokeAccess::Appearance.gender_for_picture(name)), key)
      end
    end

    # An option of the look choice with the skin its portrait shows ("Izquierda, piel clara"), or the text as it is.
    def self.option(win, text)
      return text unless @row.length == 3 && text.is_a?(String)
      cmds = PokeAccess.ivar(win, :@commands)
      i = (win.index rescue nil)
      return text unless cmds.is_a?(Array) && cmds.length == 3 && i && i >= 0 && i < 3
      "#{text}, #{PokeAccess::I18n.t(@row[@row.keys.sort[i]])}"
    end

    # Remembers the look in use as pbChangePlayer starts: -1 while a new game has put none on.
    def self.note_before
      @before = PokeAccess::Appearance.current_id
    end

    # The skin of an appearance id, by the name of its trainer type.
    def self.skin_of(id)
      tt = PokeAccess::Appearance.trainer_type(id)
      return nil if tt.nil? || !defined?(PBTrainers)
      const = PBTrainers.constants.find { |c| (PBTrainers.const_get(c) rescue nil) == tt }
      const ? skin(const) : nil
    end

    # Says, as its sex and skin, a look pbChangePlayer puts on in play; not a new game's first one nor the one just
    # picked, which its portrait said.
    def self.announce(id)
      picked = @picked
      @picked = false
      return nil if picked || @before.nil? || @before.to_i < 0
      say(PokeAccess::Appearance.gender_word(id), skin_of(id))
    end

    # Drops the row, the pick and the look before on a map change (Caches).
    def self.reset
      @row = {}
      @picked = false
      @before = nil
    end
  end
end

PokeAccess::Caches.register(:opalo_looks) { PokeAccess::OpaloLooks.reset }

PokeAccess::Game.define("opalo") do
  on_picture { |name, args| PokeAccess::OpaloLooks.on_picture(name, args[2], args[3]) }

  kernel("pbChangePlayer", :before) { |_args, _r| PokeAccess::OpaloLooks.note_before }

  override(PokeAccess::Appearance, :announce) { |_mod, _original, args| PokeAccess::OpaloLooks.announce(args[0]) }

  override(PokeAccess::Menus, :focused_text) do |_mod, original, args|
    PokeAccess::OpaloLooks.option(args[0], original.call)
  end
end
