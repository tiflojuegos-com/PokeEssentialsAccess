module PokeAccess
  # Pathfinder, what assisted routes share (Routes::Planner.assisted and Routes::Pushes): the cost of an assisted step,
  # whether anything could assist on the map, the search frame with the obstacles set aside, and the cut at the first
  # assisted step. Each assisted step carries a gate:
  #   { :kind => :field, :label, :move, :x, :y }  an obstacle at (x,y), cleared with a field move (nil: pushed, by
  #                                               walking into it, or with :act by holding the way toward it and
  #                                               pressing the action button); a pushed one carries its event (:ev),
  #                                               named as the locator names it
  #   { :kind => :pull, :label, :ev, :face, :x, :y } a pushable at (x,y), pulled with the action button facing :face
  #   { :kind => :act, :face, :x, :y }            the action button, pressed at (x,y) facing :face
  #   { :kind => :dismount, :face, :x, :y }       off the bike at (x,y), then on toward :face
  #   { :kind => :control, :label, :ev, :step, :x, :y } a puzzle's control at (x,y), stepped onto (:step) or faced
  #                                               and pressed with the action button (Routes::Controls)
  module Pathfinder
    # What an assisted step costs a route beyond its own press, in steps: a detour this long is preferred to
    # stopping to clear something, and one obstacle to two.
    GATE_COST = 8

    # True when anything could open a route walking cannot: an obstacle to clear, a boulder to push, an event to act
    # at, a registered assist, a waterfall while surfing or the bike to get off.
    def self.assist_possible?
      fx = Routes::Effects
      return true unless fx.gate_index.empty? && fx.boulder_index.empty? && fx.act_index.empty?
      return true if Routes::Moves.assist_registered?
      (($PokemonGlobal.surfing rescue false) || ($PokemonGlobal.bicycle rescue false)) ? true : false
    end

    # The part of a route walkable now, up to (not into) its first assisted step, with a copy of that step's gate (the
    # gate is shared by the plans kept).
    def self.cut_at_gate(path)
      pts = with_gates_open { Routes::Moves.trace($game_player.x, $game_player.y, bridge_level, path, replay_mode) }
      pts.each_with_index { |p, i| return [head_of(path, i), p.gate.dup] if p.gate }
      nil
    end

    # The first n presses of a route as a Route with the transfers among them: a slice is a plain Array from Ruby 3 on,
    # and in 1.8.7 it keeps the class but not the transfers.
    def self.head_of(path, n)
      head = Route.new.concat(path[0, n])
      kept = (path.respond_to?(:warps) ? path.warps : []).select { |w| w < n }
      head.warps = kept
      head.rooms = kept.length
      head
    end

    # Runs a block as an assisted search: assisted steps allowed and each cuttable or smashable obstacle lent through
    # (World::Probe.lend_through), put back afterwards whatever happens. The event indexes are read first, from the
    # world as it stands, since nothing read while events are lent is kept.
    def self.with_gates_open
      in_context do |c|
        was = c.assisting
        begin
          c.assisting = true
          fx = Routes::Effects
          fx.touch_index
          fx.act_index
          fx.ramp_map?
          PokeAccess::World::Probe.lend_through(fx.gate_index.values.map { |g| g[2] }) { yield }
        ensure
          c.assisting = was
        end
      end
    end
  end
end
