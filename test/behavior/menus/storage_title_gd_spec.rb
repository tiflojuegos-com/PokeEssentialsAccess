# The modern half of storage_title_spec.rb: the class name every v18-and-later game gives the item store,
# ItemStorage_Scene. This is the spelling the capture hook was missing -- anil, awakening, emerald, Fire Ash,
# both Infinite Fusions, Relict and Royal all declare it -- so this file is the one that would have failed.
Suite.define("storage: the modern item store speaks its title too") do
  SpeakCapture.clear
  WithdrawItemScene.new("Withdraw\nItem").pbStartScene
  eq "the title is spoken, its line break flattened", SpeakCapture.lines, ["Withdraw Item"]
  falsy "and not the item list refreshed before it, which is what used to be read instead",
        SpeakCapture.lines.first.include?("Potion")

  SpeakCapture.clear
  ItemStorage_Scene.new("Toss\nItem").pbStartScene
  eq "and the other mode says its own", SpeakCapture.lines, ["Toss Item"]
end
