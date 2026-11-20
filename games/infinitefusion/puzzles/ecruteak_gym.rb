# Ecruteak Gym (map 648): the floor is the platforms, events named skull1, skull2 or skull drawn as tiles that the map's
# parallel event (14) shows and hides by group. They are listed while drawn. Stepping on the tile beside Morty (event 217)
# sets switch 520 and leaves the shortcut platforms fixed. Beating Morty sets switch 43.
# The parallel event hides one group for 20 waits (a second), shows it, and hides the other, so the groups take turns and
# the platform under the player stays. Every platform is reachable from the door to Morty, so the assist gives the way
# over all of them, whichever is drawn.
# The checkpoints (events named Checkpoint, fixed platforms off the way) keep the tile in var 336, set switch 1132 and send
# the player to the tile left of the entrance (event 219, 16,22), which takes them back to the kept tile once stepped on
# again. Walks keep off them, and the assist's way takes that return when it is shorter.
module PokeAccess
  module IFEcruteak
    unless const_defined?(:BLINKING)
      BLINKING = /\Askull[12]\z/
      FIXED = "skull"
      CHECKPOINT = "Checkpoint"
      RETURN_TILE = [16, 22]
      START_BOX = [17, 20, 22, 24]
      MORTY_BOX = [6, 8, 26, 28]
      LEGS_SPOKEN = 6
      ORDER = [8, 2, 4, 6]
      STEPS = { 8 => [0, -1], 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0] }
      DIR_KEYS = { 8 => :dir_up, 2 => :dir_down, 4 => :dir_left, 6 => :dir_right }
    end

    # True if the tile lies in a box of [x0, x1, y0, y1].
    def self.inside?(box, x, y)
      x >= box[0] && x <= box[1] && y >= box[2] && y <= box[3]
    end

    # The tiles to stand on, each marked true when it is a blinking platform: the platforms, the fixed ones once the
    # shortcut is on, the open floor at the door and at Morty and the checkpoint the player stands on, less what a
    # person or trainer fills.
    def self.floor
      tiles = {}
      blocked = {}
      here = [$game_player.x, $game_player.y]
      $game_map.events.values.each do |ev|
        name = ev.name.to_s
        if name =~ BLINKING
          tiles[[ev.x, ev.y]] = true
        elsif name == FIXED
          tiles[[ev.x, ev.y]] = false if $game_switches[520]
        elsif name == CHECKPOINT
          tiles[here] = false if [ev.x, ev.y] == here
        elsif !ev.character_name.to_s.empty?
          blocked[[ev.x, ev.y]] = true
        end
      end
      [START_BOX, MORTY_BOX].each do |b|
        (b[0]..b[1]).each { |x| (b[2]..b[3]).each { |y| tiles[[x, y]] = false unless tiles.key?([x, y]) } }
      end
      blocked.keys.each { |k| tiles.delete(k) }
      tiles
    end

    # The checkpoint the tile left of the entrance takes the player back to, [x, y]; nil while none is kept.
    def self.kept
      pos = $game_variables[336]
      $game_switches[1132] && pos.is_a?(Array) && pos.length == 2 ? pos : nil
    end

    # The shortest way from the player to Morty's area over the floor, as a list of tiles, where stepping on the tile
    # left of the entrance lands on the kept checkpoint; nil if there is none or the player is already there.
    def self.route(tiles)
      start = [$game_player.x, $game_player.y]
      return nil if !tiles.key?(start) || inside?(MORTY_BOX, start[0], start[1])
      back = kept
      parent = { start => nil }
      queue = [start]
      until queue.empty?
        cur = queue.shift
        return trace(parent, cur) if inside?(MORTY_BOX, cur[0], cur[1])
        ORDER.each do |dir|
          nxt = [cur[0] + STEPS[dir][0], cur[1] + STEPS[dir][1]]
          via = nil
          if back && nxt == RETURN_TILE
            via = RETURN_TILE
            nxt = back
          elsif !tiles.key?(nxt)
            next
          end
          next if parent.key?(nxt)
          parent[nxt] = [cur, via]
          queue.push(nxt)
        end
      end
      nil
    end

    # The tiles from the start to the end of a search, in order, the tile left of the entrance before the checkpoint it
    # lands on.
    def self.trace(parent, tile)
      out = [tile]
      while (link = parent[out.first])
        out.unshift(link[1]) if link[1]
        out.unshift(link[0])
      end
      out
    end

    # The path as runs of one direction, [[direction, steps], ...], with [:back, 0] where the tile left of the entrance
    # lands on the checkpoint.
    def self.legs(path)
      out = []
      (1...path.length).each do |i|
        dx = path[i][0] - path[i - 1][0]
        dy = path[i][1] - path[i - 1][1]
        dir = ORDER.find { |d| STEPS[d] == [dx, dy] } || :back
        if dir != :back && out.last && out.last[0] == dir
          out.last[1] += 1
        else
          out.push([dir, dir == :back ? 0 : 1])
        end
      end
      out
    end

    # The assist's hint: the first legs of the way to Morty from where the player stands, and the rhythm of the platforms
    # when the way crosses any that blink; nil when there is no way to say.
    def self.hint
      tiles = floor
      path = route(tiles)
      return nil unless path
      all = legs(path)
      words = all[0, LEGS_SPOKEN].map do |dir, n|
        dir == :back ? PokeAccess::I18n.t(:if_jo_checkpoint_leg) : "#{n} #{PokeAccess::I18n.t(DIR_KEYS[dir])}"
      end.join(", ")
      more = all.length > LEGS_SPOKEN ? PokeAccess::I18n.t(:ifx2_more) : ""
      parts = [PokeAccess::I18n.t(:ifx2_route, :legs => words, :more => more)]
      parts.push(PokeAccess::I18n.t(:ifx2_rhythm)) if path.any? { |p| tiles[p] }
      PokeAccess.sentences(parts)
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 648) do
    auto
    name(/\Askull/, :if_jo_skull)
    name [218, 220, 221, 222, 223, 224, 225, 226], :if_jo_checkpoint
    name 219, :if_jo_checkpoint_return
    avoid(/\ACheckpoint\z/)
    sent_back :if_jo_checkpoint_saved, :to => PokeAccess::IFEcruteak::RETURN_TILE, :events => /\ACheckpoint\z/
    sent_back :if_jo_checkpoint_back, :events => 219
    watch :switch => 520, :label => :if_jo_shortcut, :on => :if_jo_shortcut_on, :off => :if_jo_shortcut_off
    arrival_hint :if_jo_ecruteak_rule
    phase lambda { PokeAccess::Puzzles.assist? && !$game_switches[43] }, :quiet => true, :hint => lambda { PokeAccess::IFEcruteak.hint }
    solved { $game_switches[43] }
  end
end
