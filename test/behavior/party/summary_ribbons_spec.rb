# The gen-6 ribbon cursor, Awakening's: the focused ribbon from PBRibbons through drawSelectedRibbon.
Suite.define("summary: the focused ribbon is read on the gen-6 game that keeps a ribbon cursor") do
  scene = PokemonSummaryScene.new

  SpeakCapture.clear
  scene.drawSelectedRibbon(2)
  eq "name and description, from PBRibbons", SpeakCapture.lines, ["Cinta2. Descripcion2"]

  SpeakCapture.clear
  scene.drawSelectedRibbon(nil)
  eq "an empty cell says it is empty, where it used to say nothing", SpeakCapture.lines, [PokeAccess::I18n.t(:rb_empty)]

  scene.instance_variable_set(:@sprites, { "ribbonsel" => Struct.new(:index).new(5) })
  scene.instance_variable_set(:@ribbonOffset, 2)
  SpeakCapture.clear
  scene.drawSelectedRibbon(2)
  eq "and a cell says where it is, the rows scrolled included", SpeakCapture.lines,
     ["Cinta2. Descripcion2" + PokeAccess::I18n.t(:pc_pos, :row => 4, :col => 2)]

  pos = PokeAccess::I18n.t(:pc_pos, :row => 4, :col => 2)
  rows = vb_levels do
    SpeakCapture.clear
    scene.drawSelectedRibbon(2)
    SpeakCapture.last
  end
  eq "brief: the ribbon alone", rows[0], "Cinta2"
  eq "medium: and where the cell is", rows[1], "Cinta2" + pos
  eq "full: the description as well", rows[2], "Cinta2. Descripcion2" + pos
  PokeAccess::Config.verbosity = :brief
  scene.drawSelectedRibbon(2)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole cell at any level", PokeAccess::Info.info_text, "Cinta2. Descripcion2" + pos

  eq "the modern lookup is tried first and the gen-6 one answers where it is absent",
     PokeAccess::Summary.ribbon_parts(7), ["Cinta7", "Descripcion7"]
end

# Picking a ribbon up in the grid and putting it down, or back with the back button, is said.
Suite.define("summary: carrying a ribbon in the grid is said, placed or put back") do
  t = PokeAccess::I18n
  cur = Struct.new(:index, :visible)
  scene = PokemonSummaryScene.new
  sel = cur.new(0, true)
  pre = cur.new(0, false)
  scene.instance_variable_set(:@sprites, { "ribbonsel" => sel, "ribbonpresel" => pre })
  PokeAccess::Summary.ribbon_poll(scene)
  SpeakCapture.clear
  pre.visible = true
  PokeAccess::Summary.ribbon_poll(scene)
  pre.visible = false
  PokeAccess::Summary.ribbon_poll(scene)
  picked = PokeAccess::Verbosity.with_hint(t.t(:rb_picked), t.t(:rb_picked_hint))
  eq "picked up with the keys that place it, then placed behind the cell the drop reads", SpeakCapture.log,
     [[picked, true], [t.t(:rb_placed), false]]
  SpeakCapture.clear
  pre.visible = true
  PokeAccess::Summary.ribbon_poll(scene)
  trig = Input.method(:trigger?)
  Input.define_singleton_method(:trigger?) { |k| k == Input::B }
  begin
    PokeAccess::Summary.ribbon_poll(scene)
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end
  pre.visible = false
  PokeAccess::Summary.ribbon_poll(scene)
  eq "picked up, then put back with the back button, said at once", SpeakCapture.log,
     [[picked, true], [t.t(:rb_cancel), true]]
  sel.visible = false
  PokeAccess::Summary.ribbon_poll(scene)
  sel.visible = true
  PokeAccess::Summary.ribbon_poll(scene)
  SpeakCapture.clear
  PokeAccess::Summary.ribbon_poll(scene)
  silent "leaving the grid and coming back starts clean"
  pre.visible = true
  PokeAccess::Summary.ribbon_poll(scene)
  sel.visible = false
  PokeAccess::Summary.ribbon_poll(scene)
  sel.visible = true
  pre.visible = false
  SpeakCapture.clear
  PokeAccess::Summary.ribbon_poll(scene)
  silent "even when it was left holding a ribbon: coming back empty-handed is not a placing"
end
