# The item store's title under its v18-and-later class, ItemStorage_Scene (storage_title_test.rb covers gen-6's
# ItemStorageScene): the first caption drawTextEx paints on opening, queued, and nothing else the screen paints.
class StorageTitleGdTest < PokeAccessTest
  test "says each mode's title as it opens, queued, its line break flattened" do
    { WithdrawItemScene => ["Withdraw\nItem", "Withdraw Item"],
      ItemStorage_Scene => ["Toss\nItem", "Toss Item"] }.each do |scene, (painted, said)|
      SpeakCapture.clear
      scene.new(painted).pbStartScene
      assert_equal [[said, false]], SpeakCapture.log, "#{scene}: the title alone, not the list painted before it"
    end
  end
end
