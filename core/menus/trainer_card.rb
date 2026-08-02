module PokeAccess
  # The gen-6 trainer card: a static panel (name, ID, money, badges, pokedex, play time) drawn once on
  # open, so reading the trainer summary on pbStartScene covers it. Covers the standard Essentials scene
  # (PokemonTrainerCardScene); a game that replaces the card ships its own reader in its profile.
  module TrainerCard
    # The spoken trainer summary (name, money, badges, pokedex, play time).
    def self.text
      PokeAccess::Info.trainer_info
    rescue StandardError
      nil
    end

    # The scene class to hook, or "" off the gen-6 era. A gen-6 fork can declare PokemonTrainerCard_Scene as
    # an empty subclass alias and build only that one, so hooking the v16 name read nothing and the v21 card
    # bound instead -- reading a gen-6 trainer through the modern accessors, which drops the ID, the Pokedex
    # tally and the play time. scene_class answers with the ancestral name; the era decides WHOSE content.
    SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonTrainerCardScene", "PokemonTrainerCard_Scene")
  end

  # The full trainer-card panel read (name, ID, money, pokedex tally, badges, play time), engine-independent
  # (it reads Engine.player). Lives at the module root so both the classic card (v21) and the v22 UI card
  # delegate here instead of one version depending on another's file.
  module TrainerCardData
    # The spoken trainer-card summary, or nil.
    def self.text
      p = PokeAccess::Engine.player
      return nil unless p
      parts = [PokeAccess::I18n.t(:tc_title)]
      parts.push(PokeAccess::I18n.t(:tc_name, :name => p.name)) if (p.name rescue nil)
      id = (sprintf("%05d", p.public_ID) rescue nil); parts.push(PokeAccess::I18n.t(:tc_id, :id => id)) if id
      parts.push(PokeAccess::I18n.t(:tc_money, :n => (p.money rescue 0)))
      dex = (p.pokedex rescue nil)
      parts.push(PokeAccess::I18n.t(:tc_pokedex, :owned => dex.owned_count, :seen => dex.seen_count)) if dex && (dex.respond_to?(:owned_count) rescue false)
      badges = PokeAccess::Util.badge_count(p); parts.push(PokeAccess::I18n.t(:tr_badges, :n => badges)) if badges
      hm = PokeAccess::Util.playtime_parts(($stats.play_time.to_i rescue nil))
      parts.push(PokeAccess::I18n.t(:tr_playtime, :h => hm[0], :m => hm[1])) if hm
      parts.join(". ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.read_on_open(PokeAccess::TrainerCard::SCENE) { |_s| PokeAccess::TrainerCard.text }
