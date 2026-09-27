# The Battle Tower's entry screen annotates the member just picked ("not entered" turns into "first") with the
# cursor still on it, where no cursor move would say it: the annotation's change is said on its own.
Suite.define("party (modern): an annotation changing under the cursor is said, and only then") do
  pk = Poke.build(:name => "Pika", :level => 20)
  panel = PokemonPartyPanel.new(pk)
  panel.text = "NO INSCRITO"
  panel.selected = true
  SpeakCapture.clear
  panel.text = "PRIMERO"
  eq "the member again, with its new annotation", SpeakCapture.lines, [PokeAccess::UIV21.party_member(pk, "PRIMERO")]
  SpeakCapture.clear
  panel.text = "PRIMERO"
  silent "set again to the same, nothing"
  other = PokemonPartyPanel.new(Poke.build(:name => "Otro"))
  other.text = "SEGUNDO"
  silent "and a panel the cursor is not on says nothing"
end
