# A reader that breaks degrades gracefully and leaves a marker line: a raising extractor falls back to the generic
# read, and a raising modal-loop block and an unregistered capability are logged once.
Suite.define("failure paths: a reader that breaks degrades visibly, not silently") do
  logged = lambda { |key| !!(PokeAccess.instance_variable_get(:@logged_once) || {})[key] }

  klass = Class.new { attr_accessor :index }
  begin
    Object.const_set(:PaSpecBrokenWindow, klass) unless Object.const_defined?(:PaSpecBrokenWindow)
    PokeAccess::Menus.def_extractor("PaSpecBrokenWindow") { |_w, _i| raise "este extractor revienta" }
    win = PaSpecBrokenWindow.new
    win.index = 1
    win.instance_variable_set(:@commands, ["Curar", "Luchar"])
    eq "the window still reads, through the generic path",
       PokeAccess::Menus.focused_text(win), "Luchar"
    truthy "and the broken extractor is named in the marker, once",
           (PokeAccess::Menus.instance_variable_get(:@ext_logged) || []).include?("PaSpecBrokenWindow")
  ensure
    Object.send(:remove_const, :PaSpecBrokenWindow) if Object.const_defined?(:PaSpecBrokenWindow)
  end

  boom =PokeAccess::SceneWatcher.reader("PaSpecNoSuchLoop", :main, :spec_boom) { |_s| raise "bloque roto" }
  boom.watch(Object.new)
  SpeakCapture.clear
  boom.poll
  silent "a raising block does not speak and does not take the loop down with it"
  truthy "but it is recorded", logged.call("scene_watcher_spec_boom")
  boom.unwatch

  falsy"an unregistered capability is still false", PokeAccess::Engine.has?(:pa_spec_no_such_cap)
  truthy "but it says so once", logged.call("cap_pa_spec_no_such_cap")
  falsy "a class name that is simply absent stays a plain false, with no noise",
        PokeAccess::Engine.has?("PaSpecAbsentClass")
  falsy "and is NOT reported as a typo", logged.call("cap_PaSpecAbsentClass")
end

# An unloadable MapInfos is tried once and kept as an empty table: a map name resolves to nil without a retry.
Suite.define("failure paths: an unloadable MapInfos is given up on once, not retried forever") do
  loc = PokeAccess::Locator
  saved = loc.instance_variable_get(:@mapinfos)
  $pa_spec_mapinfos_tries = 0
  begin
    loc.instance_variable_set(:@mapinfos, nil)
    Object.send(:alias_method, :pa_spec_real_load, :pbLoadRxData)
    Object.send(:define_method, :pbLoadRxData) do |_path|
      $pa_spec_mapinfos_tries += 1
      raise "no se puede cargar"
    end

    eq "a name cannot be resolved, and that is reported as nil rather than invented",
       loc.map_name(35), nil
    5.times { loc.map_name(35) }
    eq "and the file was attempted exactly once, not once per call", $pa_spec_mapinfos_tries, 1
    eq "the failure is remembered as an empty table", loc.instance_variable_get(:@mapinfos), {}
  ensure
    Object.send(:alias_method, :pbLoadRxData, :pa_spec_real_load)
    Object.send(:remove_method, :pa_spec_real_load)
    loc.instance_variable_set(:@mapinfos, saved)
  end
end

# A menu option's help line reaches the info key and leaves with its menu.
Suite.define("failure paths: the menu help line leaves with its menu") do
  ch = PokeAccess::CommandHelp
  win = Object.new
  begin
    ch.enter(:plain)
    ch.note(win, :plain, "Sube o baja el volumen.")
    eq "the help reaches the info key while the menu is up",
       PokeAccess::Info.info_text, "Sube o baja el volumen."
    ch.leave
    eq "and is gone once the menu closes", PokeAccess::Info.info_text, nil
  ensure
    PokeAccess::Info.set_info(:text, nil)
  end
end
