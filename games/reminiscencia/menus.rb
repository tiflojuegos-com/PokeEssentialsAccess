module PokeAccess
  # Reminiscencia's title, pause and world-map menus are fully image-based (no text windows), each
  # navigated by index in its own blocking loop, so the generic command-window hook never sees them. Those
  # loops call Input.update every frame, so the active menu is registered (a stack, since the world map
  # opens over the pause menu) and its focused index read from the per-frame poll. Labels are fixed per
  # menu except the world map, whose destination resolves to the real map name.
  module ReminMenu
    LOAD_MAIN  = ["Continuar", "Opciones", "Salir"]
    # The six bubbles of the load screen. Their captions are painted into Titulo/Bubbles.png, so the names
    # come from the game's own prose instead. Each bubble index maps to a $game_mode and a save file in
    # 2090 PScreen_Load_NEW, and 0500 Messages describes each $game_mode by name: index 3 loads
    # Endless.rxdata ($game_mode 4), which Messages lists among the menu entries as "Modo Refraccion" --
    # the game says "Modo Infinito" only once, in an options help text about a mechanic. Index 4 loads
    # DatingSim.rxdata ($game_mode 3), named "Modo Recuerdo" in the superseded command list of
    # PScreen_Load_NEW, whose help line ("Conoce mejor a los personajes") matches Messages' dating-sim
    # entry exactly; it never says "Modo Simulacion" anywhere.
    LOAD_MODES = ["Modo historia", "Capítulo extra", "Modo Mazmorra",
                  "Modo Refracción", "Modo Recuerdo", "Modo???"]
    @stack = []

    # Pushes a menu as active and announces its focused option. param kind which menu: :load_main,
    # :load_modes, :pause or :worldmap
    def self.open(scene, kind)
      @stack.push({ :scene => scene, :kind => kind, :last => nil })
      poll
    end

    # Pops the top menu; the one underneath re-announces its option on the next poll.
    def self.close
      @stack.pop
      @stack.last[:last] = nil if @stack.last
    end

    # True while any custom menu is open. These are Scene_Map overlays (the map keeps updating underneath),
    # so the field audio/cues must pause during them or they process every frame and lag. Read by Spatial.busy?.
    def self.active?; !@stack.empty?; end

    # Reads the focused option of the top menu when it changes, and keeps the mod's overworld keys quiet so
    # they don't clash with the game's own menu keys.
    def self.poll
      top = @stack.last
      return unless top
      return if (defined?(PokeAccess::ReminBag) && PokeAccess::ReminBag.watching? rescue false)
      (PokeAccess::Keys.menu_lock! rescue nil)
      st = (state(top) rescue nil)
      return if st.nil?
      key, label = st
      return if key.nil? || key == top[:last]
      top[:last] = key
      PokeAccess.speak(label, true) if label && !label.to_s.empty?
    end

    # The [change-key, spoken label] of a menu entry: the key drives change detection, the label is spoken.
    def self.state(top)
      s = top[:scene]
      case top[:kind]
      when :pause      then i = s.instance_variable_get(:@index); [i, pause_label(i)]
      when :load_main  then i = s.instance_variable_get(:@index); [i, LOAD_MAIN[i]]
      when :load_modes then i = s.instance_variable_get(:@bubbleIndex); [i, LOAD_MODES[i]]
      when :worldmap   then worldmap_state(s)
      end
    end

    # World map: at island level read the island number. At MAP level this deliberately says nothing and
    # leaves it to the drawInfo capture in extras, which reads what the screen actually paints.
    #
    # @id is NOT resolved through Locator.map_name: the screen only shows a place name for somewhere the
    # player has been (`name = ($PokemonGlobal.visitedMaps[@id] || $DEBUG) ? placename : "???"`), so reading
    # the id straight would hand over the real name of an island the game then refuses to travel to.
    #
    # Map level returns a key with no label rather than nothing at all. nil would leave the last key at the
    # island the player came from, so backing out to the island level -- which redraws nothing the drawInfo
    # capture would see -- would match that key and stay silent. A key that cannot collide with an island
    # records that the level changed without speaking over the capture that owns this level.
    def self.worldmap_state(s)
      return [[:mapa], nil] unless (s.instance_variable_get(:@menu) rescue 0) == 0
      isla = s.instance_variable_get(:@currentisla)
      [[:isla, isla], "Isla #{isla}"]
    end

    # Pause options; two of them change with the mode the player is in. The menu is icons only, with no text
    # anywhere on screen, so these labels are the only naming there is -- which is why a wrong one here is
    # invisible to everyone but the person relying on it.
    def self.pause_label(idx)
      case idx
      when 0 then "Pokemon"
      when 1 then "Bolsa"
      when 2 then (in_dungeon? ? "Salir de la mazmorra" : "Guardar")
      when 3 then "Opciones"
      when 4 then (dating_sim? ? "Dormir" : "Logros")
      end
    end

    # True in the dating-sim mode, where option 4 stops opening the achievements screen. Outside a dungeon it
    # runs common event 56, named "GoSleep", which gates on allKyleTasksDone? and answers "No puedo ir a
    # dormir aun" when tasks remain; inside one it only shows a line of Kyle's. Either way the entry is the
    # day's end, not the achievements it was being called.
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

# Reminiscencia reads these from the pause menu by raw key (Input.triggerex?), so they clash with movement/
# info; register them as remapper extras so they can be reassigned. Then wrap each blocking menu loop:
# announce the focused option on entry, read changes through the per-frame poll, clear on exit.
PokeAccess::Game.define("reminiscencia") do
  remap_extra(:fast_travel, 0x54, :ext_fast_travel)
  remap_extra(:help, 0x53, :ext_help)

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

  # Per-frame poll for the active custom menu, via the adapter API (the core runs it from its single
  # Input.update wrapper).
  poll_each_frame { PokeAccess::ReminMenu.poll }
end
