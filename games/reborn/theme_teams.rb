# Reborn's Theme Teams pick in the Nightclub (pbShowThemeTeams): the trainers on offer drawn as their overworld sprites,
# six to a row, with an arrow over the one picked and no text at all. The names, the pick and the arrow are locals of
# the function: a line trace bound to it alone (TracePoint with a target, Ruby 2.6 on; Reborn runs 3.1) keeps the
# frame of its first line, and each frame of its loop the trainer under the arrow is read from there, said as the arrow
# is drawn and each time it moves.
module PokeAccess
  module RebornThemeTeams
    # The pick as the game defines it, taken before the profile wraps it: the trace binds to its own lines.
    ORIGINAL = (Object.instance_method(:pbShowThemeTeams) rescue nil)

    # The trainer the arrow is over, as [index, name, trainers on offer]; nil before the arrow is drawn and once it
    # has gone.
    # param frame the binding of the running pick
    def self.pointed(frame)
      sprites = frame.local_variable_get(:sprites)
      return nil unless sprites.is_a?(Hash)
      arrow = sprites["arrow"]
      return nil if arrow.nil? || (arrow.disposed? rescue true)
      names = frame.local_variable_get(:trainernames)
      i = sprites["index"]
      return nil unless names.is_a?(Array) && i.is_a?(Integer) && i >= 0 && i < names.length
      [i, names[i].to_s, names.length]
    end

    # Says the trainer under the arrow once per move while a pick runs: the first queued, the moves cutting in.
    def self.poll
      return unless @frame
      at = pointed(@frame)
      return if at.nil? || at[0] == @said
      first = @said.nil?
      @said = at[0]
      PokeAccess.speak(PokeAccess::Verbosity.list_entry(at[1], at[0] + 1, at[2]), !first)
    rescue StandardError
      nil
    end

    # Keeps the frame the trace first stops in: the pick's own, whose locals the poll reads as they change.
    def self.catch_frame(tp)
      @frame ||= tp.binding
    end

    # A line trace over the pick's own code, enabled; nil where the running Ruby cannot bind one to a method.
    def self.start_trace
      return nil unless ORIGINAL && defined?(TracePoint)
      trace = TracePoint.new(:line) { |tp| PokeAccess::RebornThemeTeams.catch_frame(tp) }
      trace.enable(:target => ORIGINAL)
      trace
    rescue StandardError
      nil
    end

    # Runs the pick with its frame in the poll's reach, from a fresh start, and lets both go however it ends.
    def self.traced
      @frame = nil
      @said = nil
      trace = start_trace
      begin
        yield
      ensure
        trace.disable if trace
        @frame = nil
      end
    end
  end
end

PokeAccess::Game.define("reborn") do
  kernel("pbShowThemeTeams", :around) do |_args, nxt|
    PokeAccess::RebornThemeTeams.traced { nxt.call }
  end

  poll_each_frame { PokeAccess::RebornThemeTeams.poll }
end
