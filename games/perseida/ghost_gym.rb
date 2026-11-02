# Perseida's ghost gym (map 107, a Phasmophobia of its own): the player looks for the ghost's room, finds its evidence and
# marks it on a checklist (Phasmophobia in 0312_PMinigame_Phasmo), then names the ghost at the door. The checklist's rows are
# pictures of a tick beside painted names, the tick's frame telling the state. On the map the evidence is sprites and
# animations in the ghost's room, the sanity a bar and the lights a circle of darkness; each is said from the switches the
# events show them by (System: 233-239, room in 127 and 132, sanity in 128, hunt in 133). Sounds it plays go unsaid.
module PokeAccess
  module PerseidaGhostGym
    MAP = 107
    RUNNING = 230
    LIGHTS = 238
    MUSIC_BOX = 239
    ROOM_OF_GHOST = 127
    SANITY = 128
    ROOM_OF_PLAYER = 132
    HUNT = 133

    # The rows as initialize paints them: evidences first, then ghosts.
    EVIDENCES = ["Territorial", "Orbes Espectrales", "Huellas de Ectoplasma", "Temperaturas heladas", "Reacciona a caja de música"]
    GHOSTS = ["Frosslass", "Houndstone", "Spiritomb", "Mismagius", "Gengar"]

    # The three evidence icons on each ghost's row (evidenceList), by their place in EVIDENCES.
    GHOST_EVIDENCES = [[1, 3, 4], [0, 1, 2], [0, 1, 3], [0, 2, 4], [2, 3, 4]]

    # The frames of a row's tick: an evidence's marked, a ghost's ruled out and chosen.
    TICKED = 20
    RULED_OUT = 40
    CHOSEN = 60

    # The evidences the ghost's room can show, by their place in EVIDENCES, with the switch that says the ghost has them.
    # Territorial goes unlisted: it shows in how often the ghost haunts, by sounds.
    SHOWN = [[1, 234], [2, 235], [3, 236], [4, 237]]
    ORBS = 1
    MUSIC = 4

    # The state word of a row, from its tick's frame.
    def self.state_of(scene, row)
      if row < EVIDENCES.length
        return frame(scene, "ch#{row}") == TICKED ? :perseida_ghost_marked : :perseida_ghost_unmarked
      end
      { RULED_OUT => :perseida_ghost_out, CHOSEN => :perseida_ghost_chosen }[frame(scene, "fan#{row}")] || :perseida_ghost_open
    end

    # A tick's frame as src_rect paints it.
    def self.frame(scene, key)
      PokeAccess.sprite(scene, key).src_rect.x
    end

    # A row of the checklist: its name and state, and a ghost's evidence as its icons show it.
    def self.row(scene, row)
      state = PokeAccess::I18n.t(state_of(scene, row))
      return "#{_INTL(EVIDENCES[row])}, #{state}" if row < EVIDENCES.length
      ghost = row - EVIDENCES.length
      list = GHOST_EVIDENCES[ghost].map { |e| _INTL(EVIDENCES[e]) }.join(", ")
      PokeAccess::I18n.t(:perseida_ghost_row, :name => _INTL(GHOSTS[ghost]), :state => state, :list => list)
    end

    # The checklist as it opens: what it asks and, while key hints are said, its keys.
    def self.intro
      hint = PokeAccess::I18n.t(:perseida_ghost_keys, :key => PokeAccess::KeyHints.key(:c, "C"),
                                                      :back => PokeAccess::KeyHints.key(:b, "X"))
      asks = _INTL("Usando la evidencia obtenida, selecciona a uno de los posibles fantasmas.")
      PokeAccess::Verbosity.with_hint(asks, hint, " ")
    end

    # The evidences the player's room shows now, as indexes; none outside the ghost's room.
    def self.shown_here
      return [] unless $game_variables[ROOM_OF_PLAYER] == $game_variables[ROOM_OF_GHOST]
      SHOWN.select { |e, switch| $game_switches[switch] && visible?(e) }.map { |e, _switch| e }
    end

    # Orbs only show in the dark, and the reaction to the music box only with the box playing.
    def self.visible?(evidence)
      return !$game_switches[LIGHTS] if evidence == ORBS
      evidence != MUSIC || $game_switches[MUSIC_BOX]
    end

    # The sanity while its bar is up, for the info key.
    def self.sanity
      running? ? PokeAccess::I18n.t(:perseida_ghost_sanity, :n => $game_variables[SANITY]) : nil
    end

    def self.running?
      !$game_map.nil? && $game_map.map_id == MAP && $game_switches[RUNNING] ? true : false
    end

    # Each frame of the gym, and once when it ends.
    def self.poll
      if running?
        @running = true
        frame_of_gym
      elsif @running
        forget
      end
    end

    # The gym over: another attempt starts from its own state, unsaid.
    def self.forget
      @running = false
      PokeAccess::Cursor.reset(nil, :perseida_ghost_shown)
      PokeAccess::Cursor.reset(nil, :perseida_ghost_sanity_said)
      PokeAccess::Cursor.reset(nil, :perseida_ghost_lights_said)
      PokeAccess::Cursor.reset(nil, :perseida_ghost_hunt_said)
    end

    # What the room shows as it changes, the lights and the hunt when they do, and the sanity each time it reaches a ten:
    # it loses a point every second or two (common event 57), and the info key has the figure in between.
    def self.frame_of_gym
      evidence
      changed(:perseida_ghost_sanity_said, ($game_variables[SANITY] + 9) / 10) { sanity }
      changed(:perseida_ghost_lights_said, $game_switches[LIGHTS] ? true : false) do |on|
        PokeAccess::I18n.t(on ? :perseida_ghost_lights_on : :perseida_ghost_lights_off)
      end
      changed(:perseida_ghost_hunt_said, $game_variables[HUNT] > 0) do |on|
        PokeAccess::I18n.t(on ? :perseida_ghost_hunt_on : :perseida_ghost_hunt_off)
      end
    end

    # Says the evidence of the room when it changes; leaving it says nothing.
    def self.evidence
      list = shown_here
      return unless PokeAccess::Cursor.changed?(nil, :perseida_ghost_shown, list) && !list.empty?
      names = list.map { |e| _INTL(EVIDENCES[e]) }.join(", ")
      PokeAccess.speak(PokeAccess::I18n.t(:perseida_ghost_shown, :list => names), false)
    end

    # Says a value's line, queued, when it changes after the first time it is seen, which is the state the gym starts in.
    def self.changed(slot, value)
      first = PokeAccess::Cursor.current(nil, slot).nil?
      return unless PokeAccess::Cursor.changed?(nil, slot, value) && !first
      PokeAccess.speak(yield(value), false)
    end

    READER = PokeAccess::SceneWatcher.reader("Phasmophobia", :show, :perseida_ghost_row, :optional => true) do |scene|
      row = PokeAccess.ivar(scene, :@selected)
      if row.is_a?(Integer)
        line = PokeAccess::PerseidaGhostGym.row(scene, row)
        PokeAccess::Info.set_info(:text, line)
        [[row, line], line]
      end
    end
  end
end

PokeAccess::Game.define("perseida") do
  read_on_open("Phasmophobia", :initialize, :optional => true) { |_scene| PokeAccess::PerseidaGhostGym.intro }
  after("Phasmophobia", :show, :optional => true, :hook_container => true) { |_scene, _r, _a| PokeAccess::Info.clear_text }
  trainer_part(:sanity) { |_trainer| PokeAccess::PerseidaGhostGym.sanity }
  poll_each_frame { PokeAccess::PerseidaGhostGym.poll }
end
