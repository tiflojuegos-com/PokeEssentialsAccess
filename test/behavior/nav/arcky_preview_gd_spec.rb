# Royal's Arcky map: the mode once when it changes, and the location preview (description, then each exit after its
# direction) once per opening.

# The plugin's PreviewState, as far as the reader asks it.
ArckyPreviewState = Struct.new(:state) do
  def isHidden; state == :hidden; end
end

Suite.define("arcky map: the mode when it changes, and the preview with its directions") do
  t = PokeAccess::I18n
  am = PokeAccess::ArckyRegionMap
  modes = { :normal => { :text => "Normal" }, :fly => { :text => "Vuelo" } }
  scene = World.stub_scene(:@modeInfo => modes, :@previewBox => ArckyPreviewState.new(:hidden))
  SpeakCapture.clear
  am.mode(scene, ["[Z] Cambiar", "Vuelo"])
  am.mode(scene, ["[Z] Cambiar", "Vuelo"])
  eq "the mode, once", SpeakCapture.lines, [t.t(:arm_mode, :m => "Vuelo")]

  SpeakCapture.clear
  fly = World.stub_scene
  am.mode(fly, ["X: Vuelo Rapido"])
  eq "the fly map paints no mode, and a button hint is not one", SpeakCapture.lines, []

  SpeakCapture.clear
  am.preview_start(scene)
  am.preview_note("<c2=7FFF0000>Un pueblo tranquilo.")
  am.preview_note("<c2=7FFF0000>Un pueblo tranquilo.")
  am.preview_note("<icon=north>Ruta 1   <icon=southWest>Lago")
  am.preview_end(scene)
  line = "Un pueblo tranquilo. #{t.t(:dir_n)}: Ruta 1. #{t.t(:dir_so)}: Lago."
  eq "the description once, then each exit after its direction", SpeakCapture.lines, [line]

  scene.instance_variable_get(:@previewBox).state = :shown
  SpeakCapture.clear
  am.preview_start(scene)
  am.preview_note("<c2=7FFF0000>Un pueblo tranquilo.")
  am.preview_note("<icon=north>Ruta 1   <icon=southWest>Lago")
  am.preview_end(scene)
  eq "rebuilt unchanged while open, it is not said again", SpeakCapture.lines, []

  scene.instance_variable_get(:@previewBox).state = :hidden
  SpeakCapture.clear
  am.preview_start(scene)
  am.preview_note("<c2=7FFF0000>Un pueblo tranquilo.")
  am.preview_note("<icon=north>Ruta 1   <icon=southWest>Lago")
  am.preview_end(scene)
  eq "closed and opened again on the same place, it is said again", SpeakCapture.lines, [line]
end
