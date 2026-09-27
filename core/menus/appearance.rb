module PokeAccess
  # Character selection: speaks the appearance pbChangePlayer previews (number and gender) and a portrait's gender.
  module Appearance
    # True where appearance ids start at 1: GameData::PlayerMetadata exists (v21+). Gen-6 and both Infinite Fusions
    # are 0-based; the class decides, not a version number.
    def self.one_based?
      defined?(GameData) && GameData.const_defined?(:PlayerMetadata)
    rescue StandardError
      false
    end

    # The appearance in use: the player's character_ID (v19+) or $PokemonGlobal.playerID (gen-6); nil if unreadable.
    def self.current_id
      id = (PokeAccess::Engine.player.character_ID rescue nil)
      id = ($PokemonGlobal.playerID rescue nil) if id.nil?
      id
    end

    # Remembers the appearance in use before pbChangePlayer runs.
    def self.note_before
      @before = current_id
    end

    # Speaks the appearance pbChangePlayer put on unless it is unchanged (a refused id, a re-apply on map transfer);
    # the requested id when the current one is unreadable.
    def self.changed(id)
      now = current_id
      return announce(id) if now.nil?
      announce(now) unless now == @before
    end

    # Speaks the appearance number and gender after a preview change.
    def self.announce(id)
      g = gender_word(id)
      base = PokeAccess::I18n.t(:ap_number, :n => one_based? ? id : id + 1)
      PokeAccess.speak("#{base}#{g ? ', ' + g : ''}", true)
    rescue StandardError
      nil
    end

    # An appearance's gender word or nil, by its trainer type (readable before the player exists), else the player's.
    def self.gender_word(id)
      gv = trainertype_gender(id)
      gv = (PokeAccess::Engine.player.gender rescue nil) if gv.nil?
      case gv
      when 0 then PokeAccess::I18n.t(:ap_boy)
      when 1 then PokeAccess::I18n.t(:ap_girl)
      end
    end

    # The trainer type of an appearance id: GameData::PlayerMetadata on v21+, the MetadataPlayerA block on gen-6.
    def self.trainer_type(id)
      return (GameData::PlayerMetadata.get(id).trainer_type rescue nil) if one_based?
      return nil unless defined?(pbGetMetadata) && defined?(MetadataPlayerA)
      meta = (pbGetMetadata(0, MetadataPlayerA + id) rescue nil)
      meta ? meta[0] : nil
    rescue StandardError
      nil
    end

    # Gender of the trainer type bound to an appearance id, via the engine helper, or nil.
    def self.trainertype_gender(id)
      tt = trainer_type(id)
      return nil if tt.nil?
      return nil unless defined?(pbGetTrainerTypeGender)
      g = (pbGetTrainerTypeGender(tt) rescue nil)
      g == 2 ? nil : g
    rescue StandardError
      nil
    end

    @last_picture_gender = nil

    # Option-number => gender key for screens that encode the choice as a number in the picture name
    # (e.g. "pantallaGenero1"/"...2"); 0 is the neutral screen. Overridable via Config.gender_numbers.
    GENDER_NUMBERS = { 1 => :ap_boy, 2 => :ap_girl }

    # True while choosing a character at new game: neither $Trainer (gen-6) nor $player (modern) exists yet, or
    # playerID is negative.
    def self.selecting?
      return true if ($Trainer rescue nil).nil? && ($player rescue nil).nil?
      ($PokemonGlobal.playerID rescue 0).to_i < 0
    rescue StandardError
      false
    end

    # Speaks the gender of a selection portrait just shown, once per change, for games that pick gender by portrait.
    def self.on_picture(name)
      return unless selecting?
      g = gender_for_picture(name)
      return unless g
      return if g == @last_picture_gender
      @last_picture_gender = g
      PokeAccess.speak(PokeAccess::I18n.t(g), true)
    rescue StandardError
      nil
    end

    # Forgets the last spoken portrait gender on map change, so a second new game speaks its first portrait.
    def self.forget_picture_gender
      @last_picture_gender = nil
    end

    # Maps a selection-screen picture name to a gender key (:ap_boy/:ap_girl), or nil. Handles word names
    # (introBoy/introGirl) and numbered ones (pantallaGenero2).
    def self.gender_for_picture(name)
      s = name.to_s.downcase
      return :ap_girl if s =~ /girl|chica|mujer|femen/
      return :ap_boy if s =~ /boy|chico|hombre|masc/
      if s =~ /(?:gener[oa]|gender|sexo)\s*0*(\d+)/
        map = (PokeAccess::Config.gender_numbers rescue nil)
        map = GENDER_NUMBERS if map.nil? || map.empty?
        return map[$1.to_i]
      end
      nil
    end
  end
end

# pbChangePlayer is a global function: note the appearance before it, speak the new one after.
PokeAccess::Hooks.wrap_global("pbChangePlayer", "hook_pbChangePlayer_before", :before) { |_args, _r| PokeAccess::Appearance.note_before }
PokeAccess::Hooks.wrap_global("pbChangePlayer", "hook_pbChangePlayer", :after) { |args, _r| PokeAccess::Appearance.changed(args[0]) }

PokeAccess::Caches.register(:appearance_gender) { PokeAccess::Appearance.forget_picture_gender }
