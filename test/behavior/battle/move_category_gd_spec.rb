# The damage category on the modern screens, which paint it as an icon beside the type. Runs only in the
# gamedata pass, against GameData::Move (whose stub answers category 0, physical).

Suite.define("move category (modern): summary detail and reminder rows say it after the type") do
  t = PokeAccess::I18n
  after_type = "#{t.t(:mv_type, :t => "TypeTYPE1")}. #{t.t(:cat_physical)}. "

  pk = Poke.build(:name => "Pika")
  move = Struct.new(:id, :name, :pp, :total_pp).new(:THUNDERBOLT, "Rayo", 15, 15)
  truthy "the summary's move detail", PokeAccess::SummaryGameData.move_detail(pk, move).to_s.index(after_type)
  truthy "a reminder row", PokeAccess::UIV21.move_from_entry([:THUNDERBOLT, "Nv. 12"]).to_s.index(after_type)
  truthy "a move looked up by id", PokeAccess::MoveInfo.by_id(:THUNDERBOLT).to_s.index(after_type)
end
