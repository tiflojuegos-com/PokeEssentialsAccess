module PokeAccess
  module Puzzles
    # What a declaration says as an event's page gets to a point of its own (on_reach): a menu's branch as it starts, or a
    # Show Text right after it is read.
    module Reach
      # Forgets the message last read: the player has used an event again.
      def self.forget; @read = nil; end

      # The interpreter is about to run a menu's When: what the option it took says.
      def self.before_when(int)
        list = PokeAccess.ivar(int, :@list)
        c = list.is_a?(Array) ? list[PokeAccess.ivar(int, :@index)] : nil
        branch = PokeAccess.ivar(int, :@branch)
        return unless c && branch.is_a?(Hash) && branch[c.indent] == c.parameters[0]
        say_points(int, :choice, c.parameters[0], c.parameters[1], false)
      end

      # The interpreter is about to run a Show Text, once however many times the engine tries it while another message is up: what
      # comes right after it is read.
      def self.before_text(int)
        return if PokeAccess::World::Mechanics.instances.empty?
        list = PokeAccess.ivar(int, :@list)
        i = PokeAccess.ivar(int, :@index)
        return unless list.is_a?(Array) && i.is_a?(Integer)
        return if @read == [list.object_id, i]
        @read = [list.object_id, i]
        place = list[0...i].select { |c| c.code == 101 }.length
        say_points(int, :text, place, Answers.message_text(list, i), true)
      end

      # Says what the declarations of the map have for a point of the event an interpreter runs: at its place among those of
      # its page, or with those words.
      def self.say_points(int, key, place, words, after_text)
        ev = ($game_map.events[PokeAccess.ivar(int, :@event_id)] rescue nil)
        return unless ev
        PokeAccess::World::Mechanics.entries_for(:reaches, ev).each do |e|
          next unless e.key?(key) && (e[key].is_a?(Regexp) ? !(words.to_s =~ e[key]).nil? : e[key] == place)
          say(e, ev, after_text) if !e[:assist] || PokeAccess::Puzzles.assist?
        end
      end

      # Says a point's line, queued or after the message being opened; nothing for an empty one.
      def self.say(e, ev, after_text)
        line = PokeAccess::Puzzles.label_of(PokeAccess::World::Mechanics.label_now(e[:label], ev))
        return if line.empty?
        after_text ? PokeAccess.also_after_next_line(line) : PokeAccess.speak(line, false)
      end
    end
  end
end

PokeAccess::Hooks.before_hook("Interpreter", :command_101, :optional => true) { |i, _a| PokeAccess::Puzzles::Reach.before_text(i) }
PokeAccess::Hooks.before_hook("Interpreter", :command_402, :optional => true) { |i, _a| PokeAccess::Puzzles::Reach.before_when(i) }
