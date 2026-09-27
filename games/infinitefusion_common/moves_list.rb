# The move tutor's board (pbShowRareTutorFullList): the relearner opened with no Pokemon, a list to browse under the
# title "Moves list", which leads the first move read.
PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::MoveList", :title) do |_mod, original, args|
    PokeAccess.ivar(args[0], :@pokemon) ? original.call : PokeAccess.clean((_INTL("Moves list") rescue "").to_s)
  end
end
