# The modern half of storage_title_spec.rb: ItemStorage_Scene, the item store's class in the v18-and-later games,
# speaks its title too.
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
