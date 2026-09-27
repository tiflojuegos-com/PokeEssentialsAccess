module PokeAccess
  # Field-move and registered-item selection (Advanced Items - Field Moves plugin, SelectMoveMenu_Scene): a button
  # menu with no command window: @commands rows [id, name, party slot, idx] under @index, read on open and on moves.
  module FieldMovesV21
    # Speaks the focused option with its party member, deduped by index: the rows usually share one move name (which
    # Pokemon should use Surf?).
    def self.read(scene)
      cmds = PokeAccess.ivar(scene, :@commands)
      idx  = PokeAccess.ivar(scene, :@index)
      return unless cmds.is_a?(Array) && idx && cmds[idx]
      name = (cmds[idx][1] rescue nil).to_s
      return if name.empty?
      who = holder_name(cmds[idx])
      PokeAccess::Cursor.announce(scene, :advanced_items, idx) { who ? "#{name}, #{who}" : name }
    rescue StandardError
      nil
    end

    # The party member a row belongs to. Field 2 is the party slot: the plugin's own button builds its icon
    # with $player.party[command[2]], even though the comment beside the field misnames it as the mode.
    def self.holder_name(cmd)
      i = (cmd[2] rescue nil)
      return nil unless i.is_a?(Integer)
      party = (PokeAccess::Engine.player.party rescue nil)
      pk = (party.is_a?(Array) ? party[i] : nil)
      n = (pk.name rescue nil)
      (n && !n.to_s.empty?) ? n : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.before_hook("SelectMoveMenu_Scene", :pbShowCommands, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :advanced_items)
  PokeAccess::FieldMovesV21.read(scene)
end

PokeAccess::Hooks.after_hook("SelectMoveMenu_Scene", :refresh_buttons, :optional => true) do |scene, _r, _a|
  PokeAccess::FieldMovesV21.read(scene)
end

module PokeAccess
  # Rock Climb, from the same plugin: facing rockclimb rock, the action button carries the player along it (sideways
  # climbs follow a bend a row up or down) and sets them down one tile past its end; one assisted route step.
  module RockClimbAIFM
    # True if (x,y) is climbable rock.
    def self.rock?(x, y)
      PokeAccess::Terrain.flag_at?(x, y, :rockclimb)
    end

    # Where a climb begun from (x,y) facing d sets the player down, as [x, y], or nil.
    def self.climb(x, y, d)
      pf = PokeAccess::Pathfinder
      dd = PokeAccess::DIR_DELTA[d]
      cx = x + dd[0]; cy = y + dd[1]
      return nil unless rock?(cx, cy)
      steps = 0
      while (hold = next_hold(cx, cy, d))
        cx, cy = hold
        steps += 1
        return nil if steps > pf::ARRIVAL_CAP
      end
      pf.landing(cx + dd[0], cy + dd[1])
    end

    # The next tile of rock the plugin moves a climber to from (x,y) facing d, or nil at the end of it.
    def self.next_hold(x, y, d)
      if d == 2 || d == 8
        ny = y + (d == 2 ? 1 : -1)
        return rock?(x, ny) ? [x, ny] : nil
      end
      nx = x + (d == 6 ? 1 : -1)
      [[nx, y], [nx, y - 1], [nx, y + 1]].find { |tx, ty| rock?(tx, ty) }
    end
  end
end

PokeAccess::Pathfinder.assist_source do |x, y, dir, lvl|
  l = PokeAccess::RockClimbAIFM.climb(x, y, dir[2])
  next nil if l.nil?
  PokeAccess::Pathfinder::Step.new(l[0], l[1], lvl, 1, { :kind => :field, :label => :loc_rock_climb, :move => :ROCKCLIMB, :x => x + dir[0], :y => y + dir[1] })
end
