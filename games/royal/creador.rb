# The creator's card at the quick-start intro (CreadorEventScene, "008_Pantallas inicio.rb", opened by one
# map event through pbMostrarPantallaCreador): a single picture faded in over a loop that waits for the
# use key, with no text. Said as the picture goes up, so the wait has a reason.
PokeAccess::Game.define("royal") do
  after("CreadorEventScene", :pbStartScene, :optional => true) do |_s, _r, _a|
    PokeAccess.speak("Pantalla del creador. Pulsa Intro para continuar", true)
  end
end
