# The EV allocator, a mode of the summary's stats page up while $evalloc is set: read from pbUpdate through the
# selector sprite's index, which the plugin mirrors the cursor onto; silent outside the mode.
class PokemonSummary_Scene
  def ev_rig(pokemon, index)
    @pokemon = pokemon
    sel = Object.new
    sel.instance_variable_set(:@i, index)
    def sel.index; @i; end
    def sel.index=(v); @i = v; end
    @sprites = { "EVsel" => sel }
    sel
  end
end
Suite.define("ev allocator: the focused stat and its value are read, and only while the mode is up") do
  pk = Poke.build(:name => "Chispa")
  def pk.ev; { :HP => 84, :ATTACK => 12, :DEFENSE => 0, :SPECIAL_DEFENSE => 4, :SPEED => 252,
               :SPECIAL_ATTACK => 8 }; end
  scene = PokemonSummary_Scene.new
  sel = scene.ev_rig(pk, 0)
  had = defined?($evalloc)
  begin
    $evalloc = false
    SpeakCapture.clear
    scene.pbUpdate
    silent "outside the allocator the summary is not narrated on every frame"

    $evalloc = true
    SpeakCapture.clear
    scene.pbUpdate
    match "the focused stat is named with its effort points", SpeakCapture.lines.join(" "), /84/

    SpeakCapture.clear
    scene.pbUpdate
    silent "and a frame where nothing moved says nothing"

    sel.index = 1
    SpeakCapture.clear
    scene.pbUpdate
    match "moving to the next stat reads that one", SpeakCapture.lines.join(" "), /12/
    atk = PokeAccess::I18n.t(:ev_shared, :stat => PokeAccess::Data.stat_name(:ATTACK),
                             :with => PokeAccess::Data.stat_name(:SPECIAL_ATTACK))
    eq "Attack, which the mixed mode lights with the Sp. Atk row, names it", SpeakCapture.lines,
       [PokeAccess::I18n.t(:ev_row, :stat => atk, :n => 12)]

    sel.index = 3
    SpeakCapture.clear
    scene.pbUpdate
    match "the fourth row of the mixed mode shows Attack's EVs", SpeakCapture.lines.join(" "), /12/
    shared = PokeAccess::I18n.t(:ev_shared, :stat => PokeAccess::Data.stat_name(:SPECIAL_ATTACK),
                                :with => PokeAccess::Data.stat_name(:ATTACK))
    eq "under the Sp. Atk label it paints, shared with Attack", SpeakCapture.lines,
       [PokeAccess::I18n.t(:ev_row, :stat => shared, :n => 12)]
    sel.index = 2
    SpeakCapture.clear
    scene.pbUpdate
    eq "a row the mode does not share is said alone", SpeakCapture.lines,
       [PokeAccess::I18n.t(:ev_row, :stat => PokeAccess::Data.stat_name(:DEFENSE), :n => 0)]
    sel.index = 5
    SpeakCapture.clear
    scene.pbUpdate
    match "and the sixth is Speed", SpeakCapture.lines.join(" "), /252/
  ensure
    $evalloc = false
  end
end

# pbFullAbilityWindow, the plugin's modal panel with an ability's or a move's full description, is declared to
# ModalPanel and read on the way in (the engine stub defines it, so the declaration binds at load).
Suite.define("ev allocator: the full-description panel is read on the way in") do
  SpeakCapture.clear
  pbFullAbilityWindow("Levitate: Gives full immunity to all Ground-type moves.")
  spoke "the panel says what it holds", /full immunity to all Ground-type moves/

  SpeakCapture.clear
  pbFullAbilityWindow("")
  silent "and an empty one says nothing"
end

# While allocating, the block painted where the ability goes (pool, reset key, arrows) is said once, then each change
# with the pool; each step is pbUpdate then the repaint, in the plugin loop's order.
Suite.define("ev allocator: the mode's block is said once, and each change with the pool the page shows") do
  t = PokeAccess::I18n
  evs = { :HP => 84, :ATTACK => 12, :DEFENSE => 0, :SPECIAL_DEFENSE => 4, :SPEED => 252, :SPECIAL_ATTACK => 8 }
  pk = Poke.build(:name => "Chispa")
  pk.instance_variable_set(:@evs, evs)
  def pk.ev; @evs; end
  scene = PokemonSummary_Scene.new
  sel = scene.ev_rig(pk, 0)
  row = lambda { |stat, n| t.t(:ev_row, :stat => PokeAccess::Data.stat_name(stat), :n => n) }
  paint = lambda do |pool|
    PokeAccess::PaintCapture.arm(:summary_egg)
    drawTextEx(nil, 224, 322, 282, 2, "When EV is 0: [<-] to max.")
    pbDrawTextPositions(nil, [["STATS", 0, 0], ["EV Pool:", 224, 290], [pool, 344, 290], ["[S] resets EVs", 362, 290]])
    PokeAccess::SummaryV21.speak_page(scene, 3)
  end
  begin
    $evalloc = false
    scene.pbUpdate
    $evalloc = true
    SpeakCapture.clear
    paint.call("108")
    eq "opening: the block painted where the ability goes, queued, and nothing else of the page", SpeakCapture.log,
       [["EV Pool: 108, [S] resets EVs, When EV is 0: [<-] to max.", false]]
    SpeakCapture.clear
    scene.pbUpdate
    eq "then the focused stat, queued behind it", SpeakCapture.log, [[row.call(:HP, 84), false]]

    evs[:HP] = 88
    SpeakCapture.clear
    scene.pbUpdate
    silent "a point moved: the update before the repaint says nothing yet"
    paint.call("104")
    eq "the repaint says the stat's new value and the pool it now shows, interrupting", SpeakCapture.log,
       [["#{row.call(:HP, 88)}, #{t.t(:ev_pool_left, :n => "104")}", true]]
    SpeakCapture.clear
    paint.call("104")
    silent "a repaint that changed nothing says nothing"

    sel.index = 2
    SpeakCapture.clear
    scene.pbUpdate
    eq "moving to another stat says that stat alone", SpeakCapture.log, [[row.call(:DEFENSE, 0), true]]
    paint.call("104")

    evs.keys.each { |k| evs[k] = 0 }
    SpeakCapture.clear
    scene.pbUpdate
    paint.call("512")
    eq "the reset key on a stat already at 0, the cursor where it was, still says the pool it gave back",
       SpeakCapture.log, [["#{row.call(:DEFENSE, 0)}, #{t.t(:ev_pool_left, :n => "512")}", true]]

    sel.index = 0
    SpeakCapture.clear
    scene.pbUpdate
    $evalloc = false
    scene.pbUpdate
    SpeakCapture.clear
    PokeAccess::PaintCapture.arm(:summary_egg)
    drawTextEx(nil, 0, 0, 200, 1, "Page 3")
    PokeAccess::SummaryV21.speak_page(scene, 3)
    truthy "leaving the mode reads the page it gives back", !SpeakCapture.lines.empty?

    $evalloc = true
    SpeakCapture.clear
    paint.call("512")
    scene.pbUpdate
    eq "opening the mode again says its block, then the stat the selector starts on, queued, though the " \
       "mode was left on that same stat", SpeakCapture.log,
       [["EV Pool: 512, [S] resets EVs, When EV is 0: [<-] to max.", false], [row.call(:HP, 0), false]]

    $evalloc = false
    scene.pbUpdate
    PokeAccess::Config.verbosity = :brief
    $evalloc = true
    SpeakCapture.clear
    paint.call("512")
    eq "brief: the pool without the reset key's hint", SpeakCapture.log.first, ["EV Pool: 512", false]
  ensure
    PokeAccess::Config.verbosity = :full
    $evalloc = false
  end
end
