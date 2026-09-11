# Tectonic's Party Showcase: the whole team on one page -- each member with its types, stats and moves, and
# a footer with the trainer, the chapter and the difficulty. No cursor, no list, no window: seven draw calls
# per member straight onto an overlay, and a loop that waits for a key.
#
# Read the way a painted page is read: capture what it draws and say it once. Composing it instead would
# mean choosing which of the member's numbers to say, in what order, in a layout the plugin owns. The real
# constructor paints and then loops until the page is closed, calling Input.update every frame; the stand-in
# runs one frame of the mod's pollers in its place, which is where the opening read has to come from --
# after the constructor returned, the page is already gone.
class PokemonPartyShowcase_Scene
  attr_accessor :footer
  def initialize(_party, _snapshot = false, _name = nil)
    @footer = "Chapter 4"
    paint
    PokeAccess::Keys.run_frame_pollers
  end
  def updateShowcaseInfo(_update = false); paint; end
  def paint
    pbDrawTextPositions(nil, [["Chispa", 0, 0], ["Nv. 25", 0, 20]])
    drawFormattedTextEx(nil, 0, 40, 200, @footer)
  end
end

# The reader registered before this class existed, so nothing bound. Replaying the file is how the rest of
# the plugins layer is driven too (see plugins_smoke_spec): eval is the harness's own loading mechanism,
# on this repo's file, by absolute path.
eval(File.read(File.join(Harness::ROOT, "plugins", "party_showcase.rb")),
     TOPLEVEL_BINDING, File.join(Harness::ROOT, "plugins", "party_showcase.rb"))

Suite.define("party showcase: the page is read as painted, and a repaint that changed nothing is quiet") do
  SpeakCapture.clear
  scene = PokemonPartyShowcase_Scene.new([])
  line = SpeakCapture.lines.join(" ")
  match "the member painted is read, while the page is still up", line, /Chispa/
  falsy "and the screen is let go once the constructor's loop returns", PokeAccess::PartyShowcase.instance_variable_get(:@scene)
  match "with what the page says about it", line, /Nv. 25/
  match "and the footer too", line, /Chapter 4/

  SpeakCapture.clear
  scene.updateShowcaseInfo(true)
  silent "a repaint of the same page says nothing"

  scene.footer = "Chapter 5"
  SpeakCapture.clear
  scene.updateShowcaseInfo(true)
  match "and one that changed is read again", SpeakCapture.lines.join(" "), /Chapter 5/
end
