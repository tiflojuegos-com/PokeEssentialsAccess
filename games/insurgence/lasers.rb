module PokeAccess
  # The Erebus Gym mirror rooms (maps 542 and 543; pbDrawLasers and pbChangeMirror, 179_ChallengeChampionship.rb): a
  # beam leaves a fixed point heading down and runs over the "laser" events, each mirror (an event named "c") joining
  # two of its sides; holding the action button against a mirror and saying yes turns it a quarter clockwise. The game
  # keeps each mirror's turn in variable 144 and the tiles the beam reached in variable 145, both by event id, and the
  # receiver it reaches opens a door. That state is read here as the lit sprites show it; nothing is solved.
  module InsurgenceLasers
    # Per room: where each beam starts (the tile before its first), and each receiver's event with the switch it sets.
    ROOMS = {
      542 => { :emitters => [[12, 10], [14, 26]], :receivers => { 100 => 517, 99 => 516 } },
      543 => { :emitters => [[12, 14]], :receivers => { 211 => 515 } }
    }
    # The sides a mirror joins by its turn, as the game's own note on the table has them: 0 top and left, then
    # clockwise.
    SIDES = [:ins_mirror_tl, :ins_mirror_tr, :ins_mirror_br, :ins_mirror_bl]

    # The room the player is in, or nil.
    def self.room
      ROOMS[($game_map.map_id rescue 0)]
    end

    # True for a mirror: the game reflects the beam on an event named with a "c", and names its mirrors just that.
    def self.mirror?(ev)
      (ev.name.to_s rescue "") == "c"
    end

    # True for a tile of the beam's track (a lit one wears a beam sprite), receivers aside.
    def self.track?(ev, r = room)
      r && (ev.name.to_s rescue "") == "laser" && !r[:receivers].has_key?((ev.id rescue nil)) ? true : false
    end

    # A mirror's turn, 0 to 3, from variable 144.
    def self.turn(id)
      (($game_variables[144][id] rescue 0) || 0).to_i % 4
    end

    # True while the beam passes an event, by variable 145.
    def self.lit?(id)
      ($game_variables[145][id] rescue false) == true
    end

    # The room's mirrors in reading order, row by row.
    def self.mirrors
      ($game_map.events.values rescue []).select { |ev| mirror?(ev) }.sort_by { |ev| [ev.y, ev.x] }
    end

    # A mirror as it is said: its number in reading order, the sides it joins and whether the beam passes it.
    def self.mirror_line(ev)
      n = mirrors.index(ev).to_i + 1
      line = PokeAccess::I18n.t(:ins_mirror, :n => n, :sides => PokeAccess::I18n.t(SIDES[turn(ev.id)]))
      lit?(ev.id) ? "#{line}, #{PokeAccess::I18n.t(:ins_mirror_lit)}" : line
    end

    # The room as the beam leaves it: how many mirrors it passes and how many receivers it reaches.
    def self.status_line(r)
      list = mirrors
      lit = list.select { |ev| lit?(ev.id) }.length
      got = r[:receivers].keys.select { |id| lit?(id) }.length
      PokeAccess.sentences([PokeAccess::I18n.t(:ins_laser_mirrors, :n => list.length, :lit => lit),
                            PokeAccess::I18n.t(:ins_laser_receivers, :n => r[:receivers].length, :lit => got)])
    end

    # After a mirror is turned (its beam already redrawn): the mirror and the room.
    def self.rotated(id)
      r = room
      ev = r && ($game_map.events[id.to_i] rescue nil)
      return unless ev && mirror?(ev)
      PokeAccess.speak(PokeAccess.sentences([mirror_line(ev), status_line(r)]), true)
    rescue StandardError
      nil
    end

    # What the info key says: the mirror in front of the player, else the room.
    def self.info_line
      r = room
      return "" unless r
      fx, fy = PokeAccess::Spatial.front_tile
      ev = mirrors.find { |m| m.x == fx && m.y == fy }
      ev ? mirror_line(ev) : status_line(r)
    rescue StandardError
      ""
    end

    # The puzzle category's spots: where each beam starts and each receiver (the mirrors are the room's objects).
    def self.spots(mid)
      r = ROOMS[mid]
      out = r[:emitters].map { |xy| { :at => xy, :label => :ins_laser_emitter } }
      r[:receivers].each_key { |id| out.push(:event => id, :label => :ins_laser_receiver) }
      out
    end

    # True once every receiver of the room has opened its door.
    def self.solved?
      r = room
      r ? r[:receivers].values.all? { |sw| $game_switches[sw] ? true : false } : false
    end
  end
end

PokeAccess::Game.define("insurgence") do
  kernel("pbChangeMirror", :after) { |a, _r| PokeAccess::InsurgenceLasers.rotated(a[0]) }

  # In the mirror rooms a mirror is named as it stands and filed as an object, and the beam's tiles, lit ones wearing a
  # sprite, stay out of the lists: the room's line and each turned mirror say where the beam goes.
  override("PokeAccess::Locator", :target_name) do |_mod, original, args|
    ev = args[0]
    tag = (PokeAccess::Tags.get($game_map.map_id, ev.id) rescue nil)
    own = tag.nil? && PokeAccess::InsurgenceLasers.room && PokeAccess::InsurgenceLasers.mirror?(ev)
    own ? PokeAccess::InsurgenceLasers.mirror_line(ev) : original.call
  end
  override("PokeAccess::Locator", :event_category) do |_mod, original, args|
    l = PokeAccess::InsurgenceLasers
    l.room && l.mirror?(args[0]) ? :objects : original.call
  end
  override("PokeAccess::Locator", :in_category?) do |_mod, original, args|
    PokeAccess::InsurgenceLasers.track?(args[0]) ? false : original.call
  end

  PokeAccess::InsurgenceLasers::ROOMS.each_key do |mid|
    puzzle(mid, :kind => :stages, :solved => lambda { PokeAccess::InsurgenceLasers.solved? },
                :spots => PokeAccess::InsurgenceLasers.spots(mid),
                :stages => [{ :when => lambda { true }, :title => lambda { PokeAccess::InsurgenceLasers.info_line } }])
  end
end
