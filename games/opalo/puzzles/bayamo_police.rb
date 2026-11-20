# Opalo's police station of Pueblo Bayamo (map 393): the invisible outlaw (event 12), seen only through the Lens of Truth,
# named as such in the lens category the core lists him in.
PokeAccess::Game.define("opalo") do
  mechanic(:state, 393) do
    auto
    name 12, :op_outlaw, :when => false
  end
end
