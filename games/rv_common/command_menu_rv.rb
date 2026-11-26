module PokeAccess
  # The command menu of the engine Reborn, Rejuvenation and Desolation share (pbCommandMenuEx): in a double battle its
  # opening line, the "What will X do?" the game paints above the commands, says whose turn they are for.
  module CommandRV
    # Says the painted opening line, queued ahead of the focused command, when more than one battler takes commands.
    def self.prompt(scene, texts)
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle && PokeAccess::Battle.doubles?(battle)
      line = texts.is_a?(Array) ? texts[0] : nil
      return unless line.is_a?(String) && !line.strip.empty?
      PokeAccess.speak_clean(line.gsub("\n", " "), false, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Hooks the menu's opening.
    def self.bind
      PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbCommandMenuEx, :optional => true) do |scene, args|
        PokeAccess::CommandRV.prompt(scene, args[1])
      end
    end
  end
end

PokeAccess::CommandRV.bind if PokeAccess::DataRV.engine?
