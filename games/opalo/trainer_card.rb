module PokeAccess
  # Opalo's trainer card (OpaloCard): a data page and a badges page, each blocking in its own loop and so read
  # on entry (read_on_open, :timing => :before). C or right turns to the badges, C or left back.
  module OpaloCard
    STARS_VAR = 250
    # The star pictures the card has (estrellas_1..4); estrellas_0 is blank.
    STARS_SHOWN = 1..4

    # The key that plays each badge's anthem, in badge order (Q W E R T Y U I as virtual keys), said with the word
    # for a key, since a synthesizer reads a lone E, U or Y as a word.
    KEYS = [0x51, 0x57, 0x45, 0x52, 0x54, 0x59, 0x55, 0x49]

    # The anthem keys Opalo reads through a standard button (Input::R, Input::Y), which follow a rebind of it.
    KEY_BUTTONS = { 0x52 => :r, 0x59 => :y }

    # The name of the key that plays an anthem now.
    def self.anthem_key(vk)
      name = PokeAccess::ConfigMenu.keyname(vk)
      KEY_BUTTONS[vk] ? PokeAccess::KeyHints.key(KEY_BUTTONS[vk], name) : name
    end

    # Badge i's name as the game's badge ceremony paints it (FANCY_BADGE_NAMES), without the word "Medalla"; nil
    # when the game has no such table.
    def self.badge_name(i)
      names = PokeAccess.const_at("FANCY_BADGE_NAMES")
      n = names.is_a?(Array) ? names[i] : nil
      n ? n.to_s.sub(/\AMedalla\s+/, "") : nil
    end

    # The data page: name, money, Pokedex, play time and the stars drawn, and the key to the badges while key hints
    # are said. Or nil.
    def self.main_text
      return nil unless $Trainer
      parts = [PokeAccess::I18n.t(:tc_title), PokeAccess::I18n.t(:tc_name, :name => $Trainer.name)]
      mn = ($Trainer.money rescue nil)
      parts.push(PokeAccess::I18n.t(:tc_money, :n => mn)) if mn
      owned = ($Trainer.pokedexOwned rescue nil); seen = ($Trainer.pokedexSeen rescue nil)
      parts.push(PokeAccess::I18n.t(:tc_pokedex, :owned => owned, :seen => seen)) if owned && seen
      hm = PokeAccess::Util.playtime_parts((Graphics.frame_count / Graphics.frame_rate rescue nil))
      parts.push(PokeAccess::I18n.t(:tr_playtime, :h => hm[0], :m => hm[1])) if hm
      stars = ($game_variables[STARS_VAR] rescue nil).to_i
      parts.push(PokeAccess::I18n.t(:tcard_stars, :n => stars)) if STARS_SHOWN.include?(stars)
      started = PokeAccess::Util.started_line
      parts.push(started) if started
      parts.push(PokeAccess::I18n.t(:tcard_to_badges, :key => PokeAccess::KeyHints.key(:c, "C"))) if PokeAccess::Verbosity.hints?
      parts.join(", ")
    rescue StandardError
      nil
    end

    # The badges page: the badges earned, by name, the keys that play their anthems, and the way back while key
    # hints are said.
    def self.badges_text
      return nil unless $Trainer
      got = (0...8).select { |i| ($Trainer.badges[i] rescue false) }
      names = got.map { |i| badge_name(i) }.compact
      parts = []
      if got.empty?
        parts.push(PokeAccess::I18n.t(:tr_badges, :n => 0))
      else
        if names.length == got.length
          parts.push(PokeAccess::I18n.t(:tcard_badge_list, :list => names.join(", ")))
        else
          parts.push(PokeAccess::I18n.t(:tr_badges, :n => got.length))
        end
        keys = got.map { |i| PokeAccess::I18n.t(:key_other, :n => anthem_key(KEYS[i])) }
        parts.push(PokeAccess::I18n.t(:tcard_anthem_keys, :keys => keys.join(", "))) if PokeAccess::Verbosity.hints?
      end
      parts.push(PokeAccess::I18n.t(:tcard_to_main, :key => PokeAccess::KeyHints.key(:c, "C"))) if PokeAccess::Verbosity.hints?
      parts.join(". ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("opalo") do
  read_on_open("OpaloCard", :pbStartScene, :timing => :before) { |_s| PokeAccess::OpaloCard.main_text }
  read_on_open("OpaloCard", :badgeScene, :timing => :before) { |_s| PokeAccess::OpaloCard.badges_text }
end
