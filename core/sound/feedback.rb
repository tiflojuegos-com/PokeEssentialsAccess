module PokeAccess
  module Sound
    # The sounds of the player's own moves, each map frame with control free (Frame's :feedback step, after the
    # listener): a step on each new tile (in water, on grass or on the ground), a bump toward a wall pushed into (the
    # game's own bump muted while it answers), and the radar's tick when something to interact with lines up in front.
    module Feedback
      # The game's own bump by file name, lowercased: "bump" in the gen-6 era, "Player bump" from v18 on. Every era
      # plays it through pbSEPlay, whose param is the name or an RPG::AudioFile carrying it.
      GAME_BUMP_NAMES = ["bump", "player bump"]
      # Seconds past the cue's cooldown, and past releasing the arrow, during which a game bump still counts as the same
      # push: a touch event on a solid tile bumps one frame after the push.
      SAME_PUSH = 0.25

      # Drops what the cues remember of the last map.
      def self.reset_map_state
        @radar_key = nil
        @radar_pos = nil
        @last_x = nil
        @last_y = nil
        @was_blocked = false
        @ledge_pos = nil
      end
      reset_map_state

      # One map frame: the step, the bump, the radar and the ledge's tick.
      def self.tick
        return unless $game_map && $game_player
        return unless PokeAccess::Control.free?
        footstep
        wall_cue
        radar
        ledge
      end

      # A step when the player's tile changes, none while an ice slide carries them: water-flavoured afloat or diving,
      # grass on grass, else the ground.
      def self.footstep
        x = $game_player.x; y = $game_player.y
        if @last_x && (x != @last_x || y != @last_y)
          (PokeAccess::Keys.mark_focused rescue nil)
          unless Scheduler.nav_off? || sliding?
            water = ($PokemonGlobal && ($PokemonGlobal.surfing || $PokemonGlobal.diving)) rescue false
            Sound.cue(water ? :fstep_water : (on_grass?(x, y) ? :grass : :step))
          end
        end
        @last_x = x; @last_y = y
      end

      # Whether the engine slides the player on ice (sliding up to v20, ice_sliding in v21): the step onto the ice is
      # the player's, the tiles slid are not.
      def self.sliding?
        g = $PokemonGlobal
        PokeAccess::Control.flag(g, :sliding) || PokeAccess::Control.flag(g, :ice_sliding)
      end

      # Forgets the player's tile, so a move the game makes while it holds control gives no step when control returns.
      def self.forget_tile
        @last_x = nil
        @last_y = nil
      end

      # True on tall grass or grass.
      def self.on_grass?(x, y)
        PokeAccess::World::Terrain.grass?(x, y)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # A bump toward the wall the player pushes into: on the push, on turning to another wall and once per cooldown;
      # what it records tells just_cued? whether a bump the game plays now repeats it.
      def self.wall_cue
        return if Scheduler.nav_off?
        return if (Mixer.volume(:wall) || 0) <= 0
        if (Input.dir4 rescue 0) == 0 || walking?
          @was_blocked = false
          return
        end
        dir = $game_player.direction
        blocked = !PokeAccess::World::Probe.step?($game_player.x, $game_player.y, dir, true)
        @push_seen = PokeAccess.clock if blocked
        cooled = @bump_time.nil? || (PokeAccess.clock - @bump_time) >= cooldown
        if blocked && (@was_blocked != dir || cooled)
          played = Sound.cue(interact_ahead? ? :interact : :wall, :dir => dir)
          @bump_time = PokeAccess.clock
          @bump_dir = dir
          @bump_heard = played == :flat || (played == :engine && (PokeAccess::Config.audio3d_volume rescue 80).to_i > 0)
        end
        @was_blocked = blocked ? dir : false
      end

      # Whether the player faces something to interact with (facing), which bumps apart from a wall.
      def self.interact_ahead?
        ev = facing[0]
        !ev.nil? && (PokeAccess::Locator.interactable?(ev) rescue false)
      end

      # The event the player faces and its tile, as [event, x, y]: on the tile ahead or, that tile a counter with none
      # on it, on the one past it, as the engine reaches across a counter; the event nil for none.
      def self.facing
        fx, fy = PokeAccess::Control.front_tile
        ev = PokeAccess::Control.event_at(fx, fy)
        if ev.nil? && ($game_map.counter?(fx, fy) rescue false)
          dx, dy = PokeAccess::DIR_DELTA[$game_player.direction] || [0, 0]
          fx += dx
          fy += dy
          ev = PokeAccess::Control.event_at(fx, fy)
        end
        [ev, fx, fy]
      end

      # Whether the player is really taking a step; a v21 bump's one-step animation (@bumping) does not count.
      def self.walking?
        return false unless ($game_player.moving? rescue false)
        !($game_player.instance_variable_get(:@bumping) rescue false)
      end

      # The bump's cooldown in seconds: a held push repeats it at this pace.
      def self.cooldown
        (PokeAccess::Config.bump_cooldown rescue 16).to_f / PokeAccess::FPS
      end

      # The optional radar: a tick when something to interact with lines up right in front of the player (facing), by
      # their turning or moving or by its coming in front of them standing still, once until it changes.
      def self.radar
        unless PokeAccess::Config.proximity_radar && Scheduler.nav_full?
          @radar_key = nil; @radar_pos = nil
          return
        end
        ev, fx, fy = facing
        pos = [$game_player.x, $game_player.y, $game_player.direction, ev]
        return if pos == @radar_pos
        @radar_pos = pos
        hit = ev && (PokeAccess::Locator.interactable?(ev) rescue false)
        key = hit ? [fx, fy] : nil
        Sound.earcon(:radar) if key && key != @radar_key
        @radar_key = key
      end

      # The tick of a ledge the player can jump right in front (Routes::Moves takes it as a jump), once each time they
      # come to face one; off by default.
      def self.ledge
        pos = [$game_player.x, $game_player.y, $game_player.direction]
        return if pos == @ledge_pos
        @ledge_pos = pos
        return unless Mixer.on?(:ledge) && !Scheduler.nav_off?
        dir = PokeAccess::Routes::DIRS.find { |d| d[2] == pos[2] }
        return unless dir
        lvl = PokeAccess::Pathfinder.bridge_level.to_i > 0 ? 1 : 0
        t = PokeAccess::Routes::Moves.step(pos[0], pos[1], lvl, dir, PokeAccess::Routes::Moves::LEDGE)
        Sound.cue(:ledge, :dir => pos[2]) if t && t.kind == :jump
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Whether a sound the game plays is its own bump: the file's name, or that of the RPG::AudioFile carrying it.
      def self.game_bump?(param)
        name = param.is_a?(String) ? param : (param.name rescue nil)
        return false if name.nil?
        GAME_BUMP_NAMES.include?(File.basename(name.to_s, ".*").downcase.strip)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Whether the mod's bump answers for this one: wall_cue's test (a held push into a wall, not walking), without
      # the cooldown on purpose, so only bumps against a wall are muted.
      def self.takes_over?
        return false if (Input.dir4 rescue 0) == 0
        return false if walking?
        return false if PokeAccess::World::Probe.step?($game_player.x, $game_player.y, $game_player.direction, true)
        Sound.bump_audible?(interact_ahead?)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Whether the game's bump is muted: game_bump off, on the map, the bump's file, and the mod's bump just answered
      # this push or is about to (it plays only while Locator.polling? and control is free). One bump, never none or
      # two.
      def self.mute_game_bump?(param)
        return false if (PokeAccess::Config.game_bump rescue true)
        return false unless ($scene.is_a?(Scene_Map) rescue false)
        return false unless game_bump?(param)
        return true if just_cued?
        return false unless (PokeAccess::Locator.polling? rescue false)
        return false unless PokeAccess::Control.free?
        takes_over?
      end

      # Whether a game bump now repeats a push the mod answered audibly, toward the wall still faced, within the
      # cooldown plus SAME_PUSH, with the arrow held or let go less than SAME_PUSH ago.
      def self.just_cued?
        return false if @bump_time.nil? || !@bump_heard
        return false if @bump_dir && @bump_dir != ($game_player.direction rescue nil)
        held = (Input.dir4 rescue 0) != 0 || (!@push_seen.nil? && PokeAccess.clock - @push_seen < SAME_PUSH)
        held && (PokeAccess.clock - @bump_time) < cooldown + SAME_PUSH
      end
    end
  end
end

# Mutes the game's own bump at pbSEPlay (the around body skips nxt); every other sound goes through.
PokeAccess::Hooks.wrap_kernel("pbSEPlay", "game_bump", :around) do |args, nxt|
  PokeAccess::Sound::Feedback.mute_game_bump?(args[0]) ? nil : nxt.call
end

# Drops the last map's memos on a map change or a load (Caches.reset_all).
PokeAccess::Caches.register(:feedback) { PokeAccess::Sound::Feedback.reset_map_state }

# Losing control forgets the player's tile: a slide, a scene's move or a warp meanwhile gives no step on return.
PokeAccess::Events.on(:control_lost) { |_reason| PokeAccess::Sound::Feedback.forget_tile }
