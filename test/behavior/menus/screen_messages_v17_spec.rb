# The item storage screen as v17 names it (ItemStorage_Scene, as in Soulstones and Awakening) on the gen-6 engine: its
# prompts are said, through the Toss subclass too, which inherits them.
Suite.define("screen messages: the v17 item storage on the gen-6 engine says its prompts") do
  SpeakCapture.clear
  TossItemScene.new.pbDisplay("Tiraste 2 Pociones.")
  eq "a result the Toss subclass shows through its parent", SpeakCapture.lines, ["Tiraste 2 Pociones."]
  SpeakCapture.clear
  ItemStorage_Scene.new.pbConfirm("Tirar 2 Pociones?")
  eq "and a question", SpeakCapture.lines, ["Tirar 2 Pociones?"]
end
