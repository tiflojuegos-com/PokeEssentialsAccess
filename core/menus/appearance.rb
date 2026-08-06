module PokeAccess
  # Character appearance selection. pbChangePlayer(id) previews an appearance sprite (visual-only), so
  # this announces its number and gender to choose blind.
  module Appearance
    # True where appearance ids start at 1 rather than 0. v21+ replaced the MetadataPlayerA block with
    # GameData::PlayerMetadata and moved the first appearance to id 1 -- its pbChangePlayer rejects id < 1 --
    # so the +1 that makes a 0-based id readable turns a v21+ id into the NEXT one along: the screen previews
    # character 1 and the reader says "number 2". The gen-6 games and both Infinite Fusions stay 0-based, and
    # the presence of the class is what separates them, not a version number.
    def self.one_based?
      defined?(GameData) && GameData.const_defined?(:PlayerMetadata)
    rescue StandardError
      false
    end

    # Speaks the appearance number and gender after a preview change.
    def self.announce(id)
      g = gender_word(id)
      base = PokeAccess::I18n.t(:ap_number, :n => one_based? ? id : id + 1)
      PokeAccess.speak("#{base}#{g ? ', ' + g : ''}", true)
    rescue StandardError
      nil
    end

    # The gender word of an appearance (0 male, 1 female, else nil). Reads the trainer type from the
    # appearance metadata so it works before the trainer exists, falling back to the player's own gender.
    def self.gender_word(id)
      gv = trainertype_gender(id)
      gv = (PokeAccess::Engine.player.gender rescue nil) if gv.nil?
      case gv
      when 0 then PokeAccess::I18n.t(:ap_boy)
      when 1 then PokeAccess::I18n.t(:ap_girl)
      end
    end

    # The trainer type bound to an appearance id. v21+ keeps it on GameData::PlayerMetadata and the gen-6
    # games in the MetadataPlayerA block; only the second was consulted, so the four v21+ games never named
    # a gender here and fell through to the player's own -- which on the character-choice screen is exactly
    # the thing not decided yet.
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

    # True only while choosing a character at new game (no trainer yet); both $Trainer (gen-6) and
    # $player (modern) must be absent, or busy? would always be true on modern games.
    def self.selecting?
      return true if ($Trainer rescue nil).nil? && ($player rescue nil).nil?
      ($PokemonGlobal.playerID rescue 0).to_i < 0
    rescue StandardError
      false
    end

    # Announces the gender of a just-shown selection picture (these games pick gender by swapping a
    # portrait, with no text or pbChangePlayer).
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

# pbChangePlayer is a global function out of reach of the class hook; announce the new appearance after it.
PokeAccess::Hooks.wrap_global("pbChangePlayer", "hook_pbChangePlayer", :after) { |args, _r| PokeAccess::Appearance.announce(args[0]) }
