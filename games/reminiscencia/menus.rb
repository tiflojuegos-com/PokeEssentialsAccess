module PokeAccess
  # Reminiscencia's image-only title, pause and world-map menus: the active one is kept on a stack (the world map
  # opens over the pause menu) and its focused index read each frame; the button words come from lang/.
  module ReminMenu
    # The title's three buttons (Titulo/Continuar.png says "Jugar").
    LOAD_MAIN  = [:rem_title_play, :rem_title_options, :rem_title_quit]
    # The load screen's six bubbles by index (3 loads Endless.rxdata, 4 DatingSim.rxdata); the sixth paints "???",
    # said as a word, since a screen reader drops a run of question marks.
    LOAD_MODES = [:rem_mode_story, :rem_mode_extra, :rem_mode_dungeon,
                  :rem_mode_infinite, :rem_mode_simulator, :rem_mode_unknown]
    @stack = []

    # Pushes a menu as active and announces its focused option, and the panel for the pause menu; suspends the 3D
    # audio, which nothing else silences in these menus.
    # param kind which menu: :load_main, :load_modes, :pause or :worldmap
    def self.open(scene, kind)
      PokeAccess::MenuReturn.reset_nesting if @stack.empty?
      @stack.push({ :scene => scene, :kind => kind, :last => nil })
      (PokeAccess::Audio3D.suspend rescue nil)
      poll
      PokeAccess::PausePanel.say(pause_panel(scene)) if kind == :pause
    end

    # Pops the top menu; the one underneath re-announces its option on the next poll.
    def self.close
      @stack.pop
      @stack.last[:last] = nil if @stack.last
    end

    # Forgets the top menu's focus without popping, so the next poll re-announces it.
    def self.refocus
      @stack.last[:last] = nil if @stack.last
    end

    # Marks the top menu as off screen while its loop still runs (the pause menu ends its scene before running the
    # chosen entry), so the end of each of that entry's messages does not bring its option back.
    def self.ended
      @stack.last[:ended] = true if @stack.last
    end

    # True while any of these menus is open; Spatial.busy? reads it to pause the field cues under these overlays.
    def self.active?; !@stack.empty?; end

    # Reads the top menu's focused option when it changes and holds the menu lock; nothing while the bag is in front.
    def self.poll
      top = @stack.last
      return if top.nil? || top[:ended]
      return if (defined?(PokeAccess::ReminBag) && PokeAccess::ReminBag.watching? rescue false)
      (PokeAccess::Keys.menu_lock! rescue nil)
      st = (state(top) rescue nil)
      return if st.nil?
      key, label = st
      return if key.nil? || key == top[:last]
      top[:last] = key
      PokeAccess.speak(label, true)
    end

    # The [change-key, spoken label] of a menu entry: the key drives change detection, the label is spoken.
    def self.state(top)
      s = top[:scene]
      case top[:kind]
      when :pause      then i = s.instance_variable_get(:@index); [i, pause_label(i)]
      when :load_main  then i = s.instance_variable_get(:@index); [i, word(LOAD_MAIN[i])]
      when :load_modes then i = s.instance_variable_get(:@bubbleIndex); [i, word(LOAD_MODES[i])]
      when :worldmap   then worldmap_state(s)
      end
    end

    def self.word(key)
      key ? PokeAccess::I18n.t(key) : nil
    end

    # World map: the island by the game's own name for it (getIslaName), else its number; at map level an unlabelled
    # key, the place being drawInfo's, so backing out to the islands still counts as a change.
    def self.worldmap_state(s)
      return [[:mapa], nil] unless (s.instance_variable_get(:@menu) rescue 0) == 0
      isla = s.instance_variable_get(:@currentisla)
      [[:isla, isla], island_name(isla)]
    end

    # The first map the world map's getIsla lists for each island (Anthony's house, the village and the two cities),
    # which getIslaName names.
    ISLAND_MAPS = { 1 => 8, 2 => 67, 3 => 69, 4 => 82 }

    # The island's name as getIslaName gives it for one of its maps, or "Island n" where the game has none.
    def self.island_name(isla)
      map = ISLAND_MAPS[isla]
      name = map ? (getIslaName(map) rescue nil) : nil
      (name.nil? || name.to_s.strip.empty?) ? PokeAccess::I18n.t(:rem_island, :n => isla) : PokeAccess.clean(name.to_s)
    end

    # Pause options (Main Menu/0..4.png), two of them drawn from another picture in the mode the player is
    # in: "Abandonar" on a dungeon map, "Descansar" in the dating sim.
    def self.pause_label(idx)
      word(case idx
           when 0 then :rem_menu_pokemon
           when 1 then :rem_menu_bag
           when 2 then (in_dungeon? ? :rem_menu_quit : :rem_menu_save)
           when 3 then :rem_menu_options
           when 4 then (dating_sim? ? :rem_menu_rest : :rem_menu_achievements)
           end)
    end

    # The pause panel: the top key boxes while key hints are said, and in the dating sim the day's objectives.
    def self.pause_panel(scene)
      lines = PokeAccess::Verbosity.hints? ? key_boxes(scene) : []
      lines.concat(objectives(scene))
    end

    # The pause panel's key boxes: fast travel (or the endless mode's upgrades) on T, help on S.
    def self.key_boxes(scene)
      lines = []
      lines.push(PokeAccess::I18n.t(:rem_key_travel)) if PokeAccess.sprite(scene, "viaje")
      lines.push(PokeAccess::I18n.t(:rem_key_boosts)) if PokeAccess.sprite(scene, "scroll")
      lines.push(PokeAccess::I18n.t(:rem_key_help)) if PokeAccess.sprite(scene, "ayuda")
      lines
    end

    # The colours the objectives window writes a task in: green when done, red when not.
    TASK_STATES = { "008000" => :rem_task_done, "d00606" => :rem_task_pending }

    # The objectives window's lines: its title, then each task with the state its colour shows.
    def self.objectives(scene)
      raw = (PokeAccess.sprite(scene, "objective").text rescue nil)
      return [] if raw.nil?
      raw.to_s.split("\n").map do |line|
        t = PokeAccess.clean(line)
        key = TASK_STATES[(line[/<c3=([0-9A-Fa-f]{6})/, 1] || "").downcase]
        if t.empty?
          nil
        else
          key ? PokeAccess::I18n.t(key, :task => t) : t
        end
      end.compact
    end

    # True in the dating-sim mode, where option 4 is resting (the day's end) instead of the achievements.
    def self.dating_sim?
      (isDatingSim? rescue false) ? true : false
    end

    # True while the player is on a dungeon map (option 2 becomes an exit then).
    def self.in_dungeon?
      d = ($dungeon_maps rescue nil)
      d && $game_map && d.include?($game_map.map_id)
    rescue StandardError
      false
    end
  end
end

# Every raw key the game reads itself (Input.triggerex?/pressex?) as a rebindable extra named by all its uses, so the
# remap menu refuses them to other actions until moved: T and S in the pause menu and several screens, F the map's
# text log, A the blessings' odds and the dating-sim tabs, V the message skip, 1 to 4 the summary's moves.
PokeAccess::Game.define("reminiscencia") do
  remap_extra(:fast_travel, 0x54, :rem_ext_key_t)
  remap_extra(:help, 0x53, :rem_ext_key_s)
  remap_extra(:text_log, 0x46, :rem_ext_key_f)
  remap_extra(:game_a, 0x41, :rem_ext_key_a)
  remap_extra(:skip_text, 0x56, :rem_ext_key_v)
  remap_extra(:key_1, 0x31, :rem_ext_key_1)
  remap_extra(:key_2, 0x32, :rem_ext_key_2)
  remap_extra(:key_3, 0x33, :rem_ext_key_3)
  remap_extra(:key_4, 0x34, :rem_ext_key_4)
end

# Each image menu held during its blocking loop.
PokeAccess::Game.define("reminiscencia") do
  [["PokemonLoadScene",  :pbChoose,       :load_main],
   ["PokemonLoadScene",  :pbChooseBubble, :load_modes],
   ["PokemonMenuNuevo",  :pbUpdate,       :pause],
   ["OpenWorldMap",      :update,         :worldmap]].each do |cname, meth, kind|
    around(cname, meth) do |inst, call_next, _args|
      PokeAccess::ReminMenu.open(inst, kind)
      begin
        call_next.call
      ensure
        PokeAccess::ReminMenu.close
      end
    end
  end

  # Per-frame poll for the active menu.
  poll_each_frame { PokeAccess::ReminMenu.poll }

  before("PokemonMenuNuevo", :pbEndScene) { |_s, _a| PokeAccess::ReminMenu.ended }
end

# On the shared return signal (a message box or fade over the menu closing), the top menu re-announces once.
PokeAccess::MenuReturn.on_return { PokeAccess::ReminMenu.refocus }

# The pause menu opens every entry bare (pbEndScene, then the screen's method, no fade): each is declared a nesting
# level, so a message box inside it is not taken for the return.
[["PokemonScreen", :pbPokemonScreen], ["PokemonBagScreen", :pbStartScreen], ["PokemonSave", :pbSaveScreen],
 ["PokemonOption", :pbStartScreen], ["Logros_Scene", :initialize]].each do |cname, meth|
  PokeAccess::MenuReturn.bare(cname, meth)
end
