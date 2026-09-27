# The item store's title, all that tells its modes apart (gen-6 ItemStorageScene; storage_title_gd_spec.rb covers
# ItemStorage_Scene): the first row drawTextEx paints on opening, taken through PaintCapture, and only that row.
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
