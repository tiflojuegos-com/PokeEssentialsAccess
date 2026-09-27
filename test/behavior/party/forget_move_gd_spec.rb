# The modern forget-a-move screen draws the move being learned as a fifth row under the four: opening it names
# that move first, as the gen-6 reader does, then the prompt.
Suite.define("summary (modern): the forget screen names the move being learned before the four") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Pika")
  scene = PokemonSummary_Scene.new(pk)
  SpeakCapture.clear
  scene.pbChooseMoveToForget(:THUNDERBOLT)
  learn = PokeAccess::Data.move_name(:THUNDERBOLT)
  match "the new move first, then the prompt", SpeakCapture.lines.first.to_s,
        /\A#{Regexp.escape(t.t(:sm_learn, :move => learn))}\. #{Regexp.escape(t.t(:sm_choose_forget))}\./
end
