module PokeAccess
  module Sound
    # Every sound of the mod in one table. The families, in the order of the menu and of the ini, carry the settings
    # their sounds share (Config builds their rows from it, see rows); the sounds, in the order of the glossary, carry
    # their file, what they do and what plays instead without the positional engine.
    module Catalog
      # A family: vol, freq and tone are its setting rows as [key, default, label, help] (nil for none); on, its sound
      # switch as [key, default, label] (its help is what its first listed sound marks), off playing nothing and taking
      # no turn; from takes the settings it has none of from another family, as kind => family id; shown says when its
      # rows show (:sonar, :nav_on, :nav_full, or nil for always); extra, rows of its own after its frequency row, as
      # Config.define takes them.
      Family = Struct.new(:id, :vol, :freq, :tone, :on, :from, :shown, :extra)

      # A sound: its family; file, what the positional engine loads (nil for a sound only played flat); role, :ping (an
      # emitter the sonar pings, rank its place among them), :loop, :cue (a one-shot its caller places) or :earcon
      # (always flat); place, where a cue or a held loop plays through the engine (:side, guide_distance tiles to the
      # left or right and flat ahead and behind; :heading, to the side or on the player; :front, the tile pushed into;
      # :player); flat, what plays without the engine, as direction => [file, pitch] (:any for every direction, nil for
      # silence); clamp, the [low, high] pitches its tone keeps inside the flat channel's range; glossary, its row
      # there as [name, help, file, pitch] (nil: not listed); side, a wind's [direction, dx, dy].
      Entry = Struct.new(:id, :family, :file, :role, :rank, :place, :flat, :clamp, :glossary, :side)

      # The puzzle grid's cell tone: the file by the cell's column and the pitch by its row.
      GRID_COLUMNS = ["pa_guide_l", "pa_guide_c", "pa_guide_r"]
      GRID_ROWS = [140, 110, 85]

      # The pre-panned flat files of the wall bump, the guide's chime, the jump and the ledge's tick, by direction, with
      # their pitches: ahead high and behind low.
      WALL_FLAT = { 4 => ["pa3d_wall_l", 100], 6 => ["pa3d_wall_r", 100], 8 => ["pa3d_wall_c", 120],
                    2 => ["pa3d_wall_c", 80] }
      GUIDE_FLAT = { 4 => ["pa_guide_l", 100], 6 => ["pa_guide_r", 100], 8 => ["pa_guide_c", 140],
                     2 => ["pa_guide_c", 70] }
      JUMP_FLAT = { 4 => ["pa_jump_l", 100], 6 => ["pa_jump_r", 100], 8 => ["pa_jump_c", 140], 2 => ["pa_jump_c", 70] }
      LEDGE_FLAT = { 4 => ["pa_ledge_l", 100], 6 => ["pa_ledge_r", 100], 8 => ["pa_ledge_c", 120],
                     2 => ["pa_ledge_c", 80] }
      # The bump into something to interact with, flat: its own sound (one file, not panned) so it stays apart from the
      # wall's, pitched by direction as the wall's.
      INTERACT_FLAT = { 4 => ["pa3d_interact", 100], 6 => ["pa3d_interact", 100], 8 => ["pa3d_interact", 120],
                        2 => ["pa3d_interact", 80] }
      # The radar's tick (the guide's centre file) at its tone 50: under the guide's chime ahead at any guide tone (100
      # at least) and over the one behind (75 at most), so the two never sound alike.
      RADAR_PITCH = 88

      @families = []
      @entries = []
      @memo = {}

      # Declares a family (see Family); opts :vol, :freq, :tone, :on, :from, :shown and :extra.
      def self.family(id, opts = {})
        @memo = {}
        @families.push(Family.new(id, opts[:vol], opts[:freq], opts[:tone], opts[:on], opts[:from] || {},
                                  opts[:shown], opts[:extra] || []))
      end

      # Declares a sound (see Entry); opts :file, :role (:cue unless given), :rank, :place, :flat, :clamp, :glossary and
      # :side.
      def self.sound(id, family, opts = {})
        @memo = {}
        @entries.push(Entry.new(id, family, opts[:file], opts[:role] || :cue, opts[:rank], opts[:place], opts[:flat],
                                opts[:clamp], opts[:glossary], opts[:side]))
      end

      # What a name works out to from the table, worked out once until a family or a sound is declared.
      def self.memo(name)
        return @memo[name] if @memo.key?(name)
        @memo[name] = yield
      end

      # Every family, in menu order.
      def self.families; @families; end

      # Every sound, in glossary order.
      def self.entries; @entries; end

      # The family with an id, or nil.
      def self.family_of(id); @families.find { |f| f.id == id }; end

      # The sound with an id, or nil.
      def self.entry(id)
        memo(:by_id) { @entries.inject({}) { |h, e| h[e.id] = e; h } }[id]
      end

      # The setting key, of kind :vol, :freq, :tone or :on, a sound plays at: its family's, or that of the family it
      # takes it from; nil when none has one.
      def self.key(id, kind)
        keys = memo(kind) { @entries.inject({}) { |h, e| h[e.id] = family_key(e.family, kind); h } }
        keys[id]
      end

      # The setting key of a kind a family plays at, its own or borrowed (see key).
      def self.family_key(fid, kind)
        f = family_of(fid)
        return nil unless f
        own = f.send(kind)
        return own[0] if own
        src = f.from[kind]
        src ? family_key(src, kind) : nil
      end

      # The sounds the sonar pings, in the order they break a tie.
      def self.pings
        memo(:pings) { @entries.select { |e| e.role == :ping }.sort_by { |e| e.rank } }
      end

      # The winds, a sound for each side a wall is felt on.
      def self.winds
        memo(:winds) { @entries.select { |e| e.side } }
      end

      # The sounds the positional engine loads, as [id, file, 1 when it loops].
      def self.channels
        memo(:channels) { @entries.select { |e| e.file }.map { |e| [e.id, "#{e.file}.wav", e.role == :loop ? 1 : 0] } }
      end

      # The setting rows of a kind (:vol, :freq, :tone or :on) of every family, as [key, default, kind, group, label,
      # help, shown], each family's extra rows after its frequency row (shown nil for them).
      def self.rows(kind)
        group = { :vol => :audio3d_vol, :freq => :audio3d_freq, :tone => :audio3d_tone, :on => :audio3d_on }[kind]
        setting = { :tone => :tone, :on => :flag }[kind] || :vol
        out = []
        @families.each do |f|
          r = f.send(kind)
          out.push([r[0], r[1], setting, group, r[2], r[3] || switch_help(f.id), f.shown]) if r
          f.extra.each { |x| out.push(x + [nil]) } if kind == :freq
        end
        out
      end

      # A family's switch help: the glossary help of its first listed sound, what that sound marks; nil for none.
      def self.switch_help(fid)
        e = @entries.find { |x| x.family == fid && x.glossary }
        e ? e.glossary[1] : nil
      end

      family(:people, :on => [:sound_people, true, :lbl_on_people], :shown => :sonar,
             :vol => [:audio3d_npc, 85, :lbl_pos_people, :help_pos_people],
             :freq => [:audio3d_freq_npc, 90, :lbl_freq_people, :help_freq_people],
             :tone => [:audio3d_tone_npc, 50, :lbl_tone_people, :help_tone_people])
      family(:objects, :on => [:sound_objects, true, :lbl_on_objects], :shown => :sonar,
             :vol => [:audio3d_object, 85, :lbl_pos_objects, :help_pos_objects],
             :freq => [:audio3d_freq_object, 10, :lbl_freq_objects, :help_freq_objects],
             :tone => [:audio3d_tone_object, 50, :lbl_tone_objects, :help_tone_objects])
      family(:hazards, :on => [:sound_hazards, true, :lbl_on_hazards], :shown => :sonar,
             :vol => [:audio3d_hazard, 85, :lbl_pos_hazards, :help_pos_hazards],
             :freq => [:audio3d_freq_hazard, 10, :lbl_freq_hazards, :help_freq_hazards],
             :tone => [:audio3d_tone_hazard, 50, :lbl_tone_hazards, :help_tone_hazards])
      family(:traps, :on => [:sound_traps, true, :lbl_on_traps], :shown => :sonar,
             :vol => [:audio3d_trap, 85, :lbl_pos_traps, :help_pos_traps],
             :freq => [:audio3d_freq_trap, 10, :lbl_freq_traps, :help_freq_traps],
             :tone => [:audio3d_tone_trap, 50, :lbl_tone_traps, :help_tone_traps])
      family(:controls, :on => [:sound_controls, true, :lbl_on_controls], :shown => :sonar,
             :vol => [:audio3d_control, 85, :lbl_pos_controls, :help_pos_controls],
             :freq => [:audio3d_freq_control, 10, :lbl_freq_controls, :help_freq_controls],
             :tone => [:audio3d_tone_control, 50, :lbl_tone_controls, :help_tone_controls])
      family(:pushes, :on => [:sound_pushes, true, :lbl_on_pushes], :shown => :sonar,
             :vol => [:audio3d_push, 85, :lbl_pos_pushes, :help_pos_pushes],
             :freq => [:audio3d_freq_push, 10, :lbl_freq_pushes, :help_freq_pushes],
             :tone => [:audio3d_tone_push, 50, :lbl_tone_pushes, :help_tone_pushes])
      family(:belts, :on => [:sound_belts, true, :lbl_on_belts], :shown => :sonar,
             :vol => [:audio3d_belt, 85, :lbl_pos_belts, :help_pos_belts],
             :freq => [:audio3d_freq_belt, 10, :lbl_freq_belts, :help_freq_belts],
             :tone => [:audio3d_tone_belt, 50, :lbl_tone_belts, :help_tone_belts])
      family(:doors, :on => [:sound_doors, true, :lbl_on_doors], :shown => :sonar,
             :vol => [:audio3d_door, 85, :lbl_pos_doors, :help_pos_doors],
             :freq => [:audio3d_freq_door, 70, :lbl_freq_doors, :help_freq_doors],
             :tone => [:audio3d_tone_door, 50, :lbl_tone_doors, :help_tone_doors])
      family(:exits, :on => [:sound_exits, true, :lbl_on_exits], :shown => :sonar,
             :vol => [:audio3d_exit, 85, :lbl_pos_exits, :help_pos_exits],
             :freq => [:audio3d_freq_exit, 70, :lbl_freq_exits, :help_freq_exits],
             :tone => [:audio3d_tone_exit, 50, :lbl_tone_exits, :help_tone_exits])
      family(:teleporters, :on => [:sound_teleporters, true, :lbl_on_teleporters], :shown => :sonar,
             :vol => [:audio3d_teleporter, 90, :lbl_pos_teleporter, :help_pos_teleporter],
             :freq => [:audio3d_freq_teleporter, 70, :lbl_freq_teleporter, :help_freq_teleporter],
             :tone => [:audio3d_tone_teleporter, 50, :lbl_tone_teleporter, :help_tone_teleporter])
      family(:marks, :on => [:sound_marks, true, :lbl_on_marks], :shown => :sonar,
             :vol => [:audio3d_mark, 85, :lbl_pos_marks, :help_pos_marks],
             :freq => [:audio3d_freq_mark, 80, :lbl_freq_marks, :help_freq_marks],
             :tone => [:audio3d_tone_mark, 50, :lbl_tone_marks, :help_tone_marks])
      family(:water, :on => [:sound_water, true, :lbl_on_water], :shown => :sonar,
             :vol => [:audio3d_water, 70, :lbl_pos_water, :help_pos_water],
             :tone => [:audio3d_tone_water, 50, :lbl_tone_water, :help_tone_water])
      family(:shore, :shown => :sonar, :from => { :tone => :steps },
             :vol => [:audio3d_shore, 40, :lbl_pos_shore, :help_pos_shore])
      family(:wind, :on => [:sound_wind, true, :lbl_on_wind], :shown => :sonar,
             :vol => [:audio3d_wind, 55, :lbl_pos_wind, :help_pos_wind],
             :tone => [:audio3d_tone_wind, 50, :lbl_tone_wind, :help_tone_wind])
      family(:steps, :on => [:sound_steps, true, :lbl_on_steps], :shown => :nav_on,
             :vol => [:footstep_volume, 80, :lbl_footstep_vol, :help_footstep_vol],
             :tone => [:footstep_tone, 50, :lbl_footstep_tone, :help_footstep_tone])
      family(:wall, :on => [:sound_wall, true, :lbl_on_wall], :shown => :nav_on,
             :vol => [:wall_volume, 80, :lbl_wall_vol, :help_wall_vol],
             :tone => [:wall_tone, 50, :lbl_wall_tone, :help_wall_tone])
      family(:guide,
             :vol => [:event_volume, 70, :lbl_guide_vol, :help_guide_vol],
             :freq => [:guide_freq, 75, :lbl_guide_freq, :help_guide_freq],
             :tone => [:guide_tone, 50, :lbl_guide_tone, :help_guide_tone],
             :extra => [[:guide_rhythm, :distance, :grhythm, :audio3d_freq, :lbl_guide_rhythm, :help_guide_rhythm]])
      family(:jumps, :on => [:sound_jumps, true, :lbl_on_jumps],
             :vol => [:jump_volume, 70, :lbl_jump_vol, :help_jump_vol],
             :tone => [:jump_tone, 50, :lbl_jump_tone, :help_jump_tone])
      family(:ledges, :on => [:sound_ledges, true, :lbl_on_ledges], :shown => :nav_on,
             :from => { :vol => :jumps, :tone => :jumps })
      family(:radar, :on => [:proximity_radar, true, :lbl_on_radar], :shown => :nav_full,
             :vol => [:radar_volume, 31, :lbl_radar_vol, :help_radar_vol],
             :tone => [:radar_tone, 50, :lbl_radar_tone, :help_radar_tone])
      family(:grid, :on => [:sound_grid, true, :lbl_on_grid],
             :vol => [:puzzle_volume, 70, :lbl_puzzle_vol, :help_puzzle_vol],
             :tone => [:grid_tone, 50, :lbl_grid_tone, :help_grid_tone])
      family(:minigame, :on => [:sound_minigame, true, :lbl_on_minigame],
             :vol => [:minigame_volume, 60, :lbl_minigame_vol, :help_minigame_vol])

      sound(:npc, :people, :file => "pa3d_npc", :role => :ping, :rank => 1,
            :glossary => [:snd_npc, :snd_npc_help, "pa3d_npc", 100])
      sound(:object, :objects, :file => "pa3d_object", :role => :ping, :rank => 2,
            :glossary => [:snd_object, :snd_object_help, "pa3d_object", 100])
      sound(:door, :doors, :file => "pa3d_door", :role => :ping, :rank => 3,
            :glossary => [:snd_door, :snd_door_help, "pa3d_door", 100])
      sound(:teleporter, :teleporters, :file => "pa3d_teleporter", :role => :ping, :rank => 8,
            :glossary => [:snd_teleporter, :snd_teleporter_help, "pa3d_teleporter", 100])
      sound(:mark, :marks, :file => "pa3d_mark", :role => :ping, :rank => 9,
            :glossary => [:snd_mark, :snd_mark_help, "pa3d_mark", 100])
      sound(:control, :controls, :file => "pa3d_control", :role => :ping, :rank => 6,
            :glossary => [:snd_control, :snd_control_help, "pa3d_control", 100])
      sound(:belt, :belts, :file => "pa3d_boing", :role => :ping, :rank => 7,
            :glossary => [:snd_belt, :snd_belt_help, "pa3d_boing", 100])
      sound(:push, :pushes, :file => "pa3d_push", :role => :ping, :rank => 10,
            :glossary => [:snd_push, :snd_push_help, "pa3d_push", 100])
      sound(:exit, :exits, :file => "pa3d_exit", :role => :ping, :rank => 11,
            :glossary => [:snd_exit, :snd_exit_help, "pa3d_exit", 100])
      sound(:trap, :traps, :file => "pa3d_boop", :role => :ping, :rank => 5,
            :glossary => [:snd_trap, :snd_trap_help, "pa3d_boop", 100])
      sound(:hazard, :hazards, :file => "pa3d_hazard", :role => :ping, :rank => 4,
            :glossary => [:snd_hazard, :snd_hazard_help, "pa3d_hazard", 100])
      sound(:water, :water, :file => "pa3d_water", :role => :loop,
            :glossary => [:snd_water, :snd_water_help, "pa3d_water", 100])
      sound(:shore, :shore, :file => "pa_grass", :glossary => [:snd_shore, :snd_shore_help, "pa_grass", 100])
      sound(:wind_n, :wind, :file => "pa3d_wind_n", :role => :loop, :side => [8, 0, -1],
            :glossary => [:snd_wind_n, :snd_wind_help, "pa3d_wind_n", 100])
      sound(:wind_e, :wind, :file => "pa3d_wind_e", :role => :loop, :side => [6, 1, 0],
            :glossary => [:snd_wind_e, :snd_wind_help, "pa3d_wind_e", 100])
      sound(:wind_s, :wind, :file => "pa3d_wind_s", :role => :loop, :side => [2, 0, 1],
            :glossary => [:snd_wind_s, :snd_wind_help, "pa3d_wind_s", 100])
      sound(:wind_w, :wind, :file => "pa3d_wind_w", :role => :loop, :side => [4, -1, 0],
            :glossary => [:snd_wind_w, :snd_wind_help, "pa3d_wind_w", 100])
      sound(:wall, :wall, :file => "pa3d_wall", :place => :front, :flat => WALL_FLAT, :clamp => [80, 120],
            :glossary => [:snd_wall, :snd_wall_help, "pa3d_wall", 100])
      sound(:interact, :wall, :file => "pa3d_interact", :place => :front, :flat => INTERACT_FLAT, :clamp => [80, 120],
            :glossary => [:snd_interact, :snd_interact_help, "pa3d_interact", 100])
      sound(:bump, :wall, :glossary => [:snd_bump, :snd_bump_help, "pa3d_wall_c", 100])
      sound(:step, :steps, :file => "pa_step", :place => :player, :flat => { :any => ["pa_step", 100] },
            :clamp => [90, 100],
            :glossary => [:snd_step, :snd_step_help, "pa_step", 100])
      sound(:grass, :steps, :file => "pa_grass", :place => :player, :flat => { :any => ["pa_grass", 100] },
            :clamp => [90, 100],
            :glossary => [:snd_grass, :snd_grass_help, "pa_grass", 100])
      sound(:fstep_water, :steps, :file => "pa_water", :place => :player, :flat => { :any => ["pa_water", 100] },
            :clamp => [90, 100],
            :glossary => [:snd_swim, :snd_swim_help, "pa_water", 100])
      sound(:guide, :guide, :file => "pa3d_guide", :place => :side, :flat => GUIDE_FLAT, :clamp => [70, 140],
            :glossary => [:snd_guide, :snd_guide_help, "pa3d_guide", 100])
      sound(:guide_hold, :guide, :file => "pa3d_guide_hold", :role => :loop, :place => :heading,
            :glossary => [:snd_guide_hold, :snd_guide_hold_help, "pa3d_guide_hold", 100])
      sound(:jump, :jumps, :file => "pa3d_jump", :place => :side, :flat => JUMP_FLAT, :clamp => [70, 140],
            :glossary => [:snd_jump, :snd_jump_help, "pa3d_jump", 100])
      sound(:ledge, :ledges, :file => "pa3d_ledge", :place => :front, :flat => LEDGE_FLAT, :clamp => [80, 120],
            :glossary => [:snd_ledge, :snd_ledge_help, "pa3d_ledge", 100])
      sound(:radar, :radar, :role => :earcon, :flat => { :any => ["pa_guide_c", RADAR_PITCH] },
            :clamp => [RADAR_PITCH, RADAR_PITCH], :glossary => [:snd_radar, :snd_radar_help, "pa_guide_c", RADAR_PITCH])
      sound(:minigame, :minigame, :role => :earcon, :flat => { :any => ["pa_mg_tick", 100] },
            :glossary => [:snd_minigame, :snd_minigame_help, "pa_mg_tick", 100])
      sound(:grid, :grid, :role => :earcon, :clamp => [85, 140],
            :glossary => [:snd_grid, :snd_grid_help, "pa_guide_c", 110])
    end
  end
end
