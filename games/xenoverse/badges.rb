module PokeAccess
  # The trainer card's back (0117_PScreen_TrainerCard, @retro): one picture per earned badge, @obtBadge long, the cursor
  # at @index. Its loop moves @index before update wraps it, so for a frame it can stand one past either end: only a
  # place inside the row is read. The name is the one renderBadgeAnimation paints for that place (FANCY_BADGE_NAMES).
  module XenoverseBadges
    # Starts reading a card that opens.
    def self.watch(scene)
      @scene, @view = scene, nil
      PokeAccess::Cursor.reset(scene, :xenoverse_badges)
    end

    # Forgets the card as it closes.
    def self.unwatch
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(@scene, :xenoverse_badges) if @scene
      @scene, @view = nil, nil
    end

    # Says the card's title on turning back to the front, and the badge count and the badge under the cursor on the back.
    def self.poll
      scene = @scene
      return unless scene
      medals = PokeAccess.sprite(scene, "medals")
      fade = PokeAccess.sprite(scene, "sfade")
      return unless medals && !(medals.disposed? rescue false)
      return if fade && fade.opacity > 0
      if PokeAccess.ivar(scene, :@retro) && medals.visible
        back(scene)
      else
        front(scene)
      end
    end

    # The front: its title, once, after the back.
    def self.front(scene)
      if @view == :back
        PokeAccess::Info.set_info(:trainer, nil)
        PokeAccess.speak(PokeAccess::I18n.t(:tc_title), true)
        PokeAccess::Cursor.reset(scene, :xenoverse_badges)
      end
      @view = :front
    end

    # The back: how many badges, and the one at the cursor with its place among them.
    def self.back(scene)
      earned = PokeAccess.ivar(scene, :@obtBadge)
      return unless earned.is_a?(Array)
      count = earned.length
      index = PokeAccess.ivar(scene, :@index)
      inside = index.is_a?(Integer) && index >= 0 && index < count
      return if count > 0 && !inside
      @view = :back
      text = PokeAccess::I18n.t(:tr_badges, :n => count)
      name = inside ? badge_name(index) : nil
      text = PokeAccess.sentences([text, PokeAccess::I18n.t(:list_entry, :name => name, :n => index + 1, :tot => count)]) if name
      PokeAccess::Cursor.announce(scene, :xenoverse_badges, [count, inside ? index : nil], true, false) do
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end

    # The badge's name at that place, if the trainer has that badge.
    def self.badge_name(index)
      trainer = PokeAccess::Info.player_object
      badges = trainer && trainer.badges
      return nil unless badges.is_a?(Array) && badges[index] == true
      names = PokeAccess.const_at("FANCY_BADGE_NAMES")
      name = names.is_a?(Array) ? names[index] : nil
      name && !name.to_s.empty? ? PokeAccess.clean(name.to_s) : nil
    end
  end
end

PokeAccess::SceneWatcher.wire("PokemonTrainerCardScene", :pbTrainerCard, PokeAccess::XenoverseBadges)
