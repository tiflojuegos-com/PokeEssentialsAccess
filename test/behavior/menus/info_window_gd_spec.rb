# The modern half of info_window_spec.rb. The modern dex header is painted from pbRefresh, with no windows: read on
# open and when a total changes, not on every step of the list.
Suite.define("info window: the modern dex header is read on OPEN, without the row the cursor moves") do
  scene = PokemonPokedex_Scene.new

  SpeakCapture.clear
  scene.pbStartScene
  eq "opening the screen speaks the header, which reaches pbRefresh through pbRefreshDexList",
     SpeakCapture.lines, ["Pokedex, Seen:, 42"]
  falsy "and the opener is not guarding the reader that does the talking",
        PokeAccess::Hooks.suppressed.any? { |p| p =~ /pbRefresh/ }

  SpeakCapture.clear
  scene.focus_species = 4
  scene.pbRefresh
  silent "stepping down the list does NOT repeat the header, though the batch it is painted in changed"

  scene.seen_total = 43
  SpeakCapture.clear
  scene.pbRefresh
  eq "but a total that really changed is spoken again", SpeakCapture.lines, ["Pokedex, Seen:, 43"]

  eq "and none of the three windows this era lacks is reported as a fault",
     PokeAccess::InfoWindow.silent.select { |t| t =~ /Pokedex/ }, []
end

Suite.define("info window: a declared window the scene does not have is reported, not silently skipped") do
  iw = PokeAccess::InfoWindow
  prev_live = iw.live
  before = iw.silent.dup
  begin
    iw.watch("PokemonPhone_Scene", "no_such_window", :spec_absent)
    scene = PokemonPhone_Scene.new
    iw.enter(scene)
    SpeakCapture.clear
    iw.tick
    silent "an absent window says nothing, as it must"
    truthy "but it is named, so a reader that can never speak is visible",
           iw.silent.include?("PokemonPhone_Scene.no_such_window")
  ensure
    iw.watches.reject! { |w| w[2] == :spec_absent }
    iw.silent.replace(before)
    iw.enter(prev_live)
  end
end

# The watch is driven by the frame poller.
Suite.define("info window: the frame poller is what drives the watch") do
  iw = PokeAccess::InfoWindow
  prev_live = iw.live
  begin
    scene = PokemonPhone_Scene.new
    iw.enter(scene)
    scene.sprites["bottom"].text = "<ac>Ruta 3"
    SpeakCapture.clear
    PokeAccess::Keys.run_frame_pollers
    eq "one frame of the game speaks the window without anyone calling tick",
       SpeakCapture.lines, ["Ruta 3"]
  ensure
    iw.enter(prev_live)
  end
end

# A hidden window is not read and its dedup is left alone, so a value written while hidden is said once shown.
Suite.define("info window: a hidden window is not read, and is read the moment it is shown") do
  iw = PokeAccess::InfoWindow
  prev_live = iw.live
  begin
    scene = PokemonPhone_Scene.new
    iw.enter(scene)
    scene.sprites["bottom"].visible = false
    scene.sprites["bottom"].text = "<ac>Ruta 9"
    SpeakCapture.clear
    iw.tick
    silent "a window the scene has hidden says nothing"

    scene.sprites["bottom"].visible = true
    SpeakCapture.clear
    iw.tick
    eq "and showing it says what it was holding all along", SpeakCapture.lines, ["Ruta 9"]

    SpeakCapture.clear
    iw.tick
    silent "then it deduplicates like any other"
  ensure
    iw.enter(prev_live)
  end
end
