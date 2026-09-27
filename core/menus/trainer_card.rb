module PokeAccess
  # The trainer card, read as it paints itself (pbDrawTrainerCardFront), then the count of badge icons it drew (the
  # region's own); the composed summary where it paints no words.
  module TrainerCard
    # The composed trainer summary, then the day the save was started (the card prints it last).
    def self.text
      t = PokeAccess::Info.trainer_info
      started = PokeAccess::Util.started_line
      t && started ? "#{t}. #{started}" : t
    rescue StandardError
      nil
    end

    # The scene class to hook, or "" where this reader does not apply: with both names present (a fork declaring
    # PokemonTrainerCard_Scene as an empty subclass), it binds only on a gen-6 engine.
    SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonTrainerCardScene", "PokemonTrainerCard_Scene")

    # Reads a card face as the block paints it, key hints gated, then the front's badge icons; queued on open,
    # interrupting when the card is turned.
    # param front whether this is the front, the face with the badges
    # param fallback a callable giving the text for a face that painted no words
    def self.read_face(scene, front, fallback = nil)
      ret = nil
      icons = []
      pairs = PokeAccess::PaintCapture.sample { icons = PokeAccess::PaintCapture.icons { ret = yield } }
      lines = PokeAccess::KeyHints.gate(PokeAccess::PaintCapture.lines(pairs))
      n = (icons || []).count { |p| p =~ /badge/i }
      badges = (front && n > 0) ? badge_line(scene, n) : nil
      lines.push(badges) if badges && !lines.empty?
      lines = [fallback.call] if lines.empty? && fallback
      turned = PokeAccess.ivar(scene, :@access_card_read)
      scene.instance_variable_set(:@access_card_read, true)
      t = PokeAccess.sentences(lines.compact.map { |l| PokeAccess::KeyHints.localize(l, nil, true) })
      PokeAccess.speak(t, turned ? true : false) unless t.empty?
      ret
    end

    # The line for the badge icons of the front; a card that paints its own count as text drops it.
    def self.badge_line(_scene, n)
      PokeAccess::I18n.t(:tr_badges, :n => n)
    end
  end

  # The composed trainer-card read (name, ID, money, pokedex tally, badges, play time) from Engine.player, shared by
  # the v21 and v22 cards.
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
      hm = PokeAccess::Util.playtime_parts(PokeAccess::Util.playtime_seconds)
      parts.push(PokeAccess::I18n.t(:tr_playtime, :h => hm[0], :m => hm[1])) if hm
      started = PokeAccess::Util.started_line
      parts.push(started) if started
      parts.join(". ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook(PokeAccess::TrainerCard::SCENE, :pbDrawTrainerCardFront, :optional => true) do |scene, nxt, _a|
  PokeAccess::TrainerCard.read_face(scene, true, lambda { PokeAccess::TrainerCard.text }) { nxt.call }
end
