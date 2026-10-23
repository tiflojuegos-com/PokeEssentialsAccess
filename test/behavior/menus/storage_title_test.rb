# The item store's title, all that tells its modes apart (gen-6 ItemStorageScene; storage_title_gd_test.rb covers
# ItemStorage_Scene): the first caption drawTextEx paints on opening, queued, and nothing else the screen paints.
class StorageTitleTest < PokeAccessTest
  test "says each mode's title as it opens, queued, its line break flattened" do
    { WithdrawItemScene => ["Guardar\nobjeto", "Guardar objeto"],
      ItemStorageScene => ["Tirar\nobjeto", "Tirar objeto"] }.each do |scene, (painted, said)|
      SpeakCapture.clear
      scene.new(painted).pbStartScene
      assert_equal [[said, false]], SpeakCapture.log, "#{scene}: the title alone, not the list painted before it"
    end
  end
end
