# Infinite Fusion's quest log (Marin's Quest plugin, its data the game's own): a quest's name is painted in its
# branch's colour, gold for the hotels and the legendaries, purple for the field, dark red for Team Rocket, and each
# quest keeps that branch where the plugin keeps a giver ("Hotel Quests"), so the row says it from medium.
PokeAccess::Game.define("infinitefusion") do
  override("PokeAccess::Quests", :quest_row) do |_mod, original, args|
    q = args[0]
    nm = (q.name rescue nil)
    branch = PokeAccess.clean((q.npc rescue nil).to_s)
    if nm.nil? || nm.to_s.empty? || branch.empty?
      original.call
    else
      st = PokeAccess::I18n.t((q.completed rescue false) ? :qu_status_done : :qu_status_pending)
      PokeAccess::Verbosity.line(:quest, [[nm, :brief], [branch, :medium], [st, :medium]])
    end
  end
end
