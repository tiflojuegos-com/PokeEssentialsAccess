module PokeAccess
  module XenoverseBadges
    def self.watch(scene)
      @scene, @view = scene, nil
      PokeAccess::Cursor.reset(scene, :xenoverse_badges)
    end

    def self.unwatch
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(@scene, :xenoverse_badges) if @scene
      @scene, @view = nil, nil
    end

    def self.poll
      scene = @scene
      return unless scene
      medals = PokeAccess.sprite(scene, "medals")
      fade = PokeAccess.sprite(scene, "sfade")
      return unless medals && !(medals.disposed? rescue false)
      return if fade && fade.opacity > 0
      back = !!PokeAccess.ivar(scene, :@retro) && medals.visible
      if !back
        if @view == :back
          PokeAccess::Info.set_info(:trainer, nil)
          PokeAccess.speak(PokeAccess::I18n.t(:tc_title), true)
          PokeAccess::Cursor.reset(scene, :xenoverse_badges)
        end
        @view = :front
        return
      end
      trainer = PokeAccess::Info.player_object
      badges = trainer && trainer.badges
      return unless badges.is_a?(Array)
      count = badges.count { |earned| earned == true }
      index = PokeAccess.ivar(scene, :@index)
      names = PokeAccess.const_at("FANCY_BADGE_NAMES")
      name = nil
      if count > 0 && index.is_a?(Integer) && index >= 0 && badges[index] == true
        name = names[index] if names.is_a?(Array)
      end
      text = PokeAccess::I18n.t(:tr_badges, :n => count)
      if name && !name.to_s.empty?
        text += ". " + PokeAccess::I18n.t(:list_entry, :name => name, :n => index + 1, :tot => count)
      end
      @view = :back
      PokeAccess::Cursor.announce(scene, :xenoverse_badges, [count, name && index, name], true, false) do
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end
  end
end

PokeAccess::SceneWatcher.wire("PokemonTrainerCardScene", :pbTrainerCard, PokeAccess::XenoverseBadges)
