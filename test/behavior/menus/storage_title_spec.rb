# The item-storage title, on the gen-6 spelling of the class (ItemStorageScene). Its twin
# storage_title_gd_spec.rb covers the modern one (ItemStorage_Scene), which is the name eight of the
# fourteen surveyed games use and which the capture hook did not carry: an :optional hook that binds
# nowhere fails silently, so "Withdraw item" and "Toss item" -- the ONLY difference between the two modes,
# same class, same window, same list -- had never been spoken in any of them.
#
# Driven through the real chain: the scene paints with drawTextEx, PaintCapture's wrapper notes it, and the
# hook takes the FIRST row only, since the same opening paints the focused item's description after it.
Suite.define("storage: opening the item store speaks its title, and only the title") do
  SpeakCapture.clear
  WithdrawItemScene.new("Guardar\nobjeto").pbStartScene
  eq "the title is spoken, its line break flattened", SpeakCapture.lines, ["Guardar objeto"]
  falsy "and the item description that follows it is not part of that line",
        SpeakCapture.lines.first.include?("pocion")
  falsy "nor the item LIST the screen refreshes BEFORE it, which is what used to be read instead",
        SpeakCapture.lines.first.include?("Pocion")

  SpeakCapture.clear
  ItemStorageScene.new("Tirar\nobjeto").pbStartScene
  eq "the other mode says its own title, which is all that tells them apart",
     SpeakCapture.lines, ["Tirar objeto"]
end
