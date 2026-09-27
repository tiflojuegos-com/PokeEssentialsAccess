# The older Pokedex search (gen-6) writes each row's and sub-list option's help into a message box: the row carries
# its help, and a sub-list's help is watched while it is open.
Suite.define("dex search: the older screen's help line follows the row, and a sub-list's is watched while open") do
  ds = PokeAccess::DexSearch
  box = Struct.new(:text).new("Listar por tipo.\r\nSolamente atrapados.")
  list = Object.new
  list.instance_variable_set(:@commands, ["Tipo: ----", "Buscar"])
  def list.index; 0; end
  def list.active; true; end
  scene = World.stub_scene(:@sprites => { "searchlist" => list, "messagebox" => box })
  SpeakCapture.clear
  ds.list(scene)
  eq "the focused row, then the help the box shows for it", SpeakCapture.lines,
     ["Tipo: ----. Listar por tipo. Solamente atrapados."]

  box.text = "Los Pokémon se listan según su número."
  ds.aux_open(scene)
  begin
    SpeakCapture.clear
    ds.aux_poll
    silent "the first frame is the generic reader's, which says the first option"
    ds.aux_poll
    eq "a sub-list's help is said once it is written", SpeakCapture.lines, ["Los Pokémon se listan según su número."]
    eq "queued behind the option the generic reader says", SpeakCapture.log.last[1], false
    SpeakCapture.clear
    ds.aux_poll
    silent "and not again while it stays the same"
    box.text = "Los Pokémon capturados se listan del más pesado al más ligero."
    ds.aux_poll
    eq "a new option's help is said", SpeakCapture.lines, ["Los Pokémon capturados se listan del más pesado al más ligero."]
  ensure
    ds.aux_close
  end
  box.text = "Otra cosa"
  SpeakCapture.clear
  ds.aux_poll
  silent "and once the sub-list closes nothing is watched"
end
