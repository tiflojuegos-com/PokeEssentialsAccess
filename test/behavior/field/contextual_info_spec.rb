# The info key's builders. summary_text reads a Pokemon's name, level, species line and stats.
Suite.define("info: summary_text keeps stats even on a bare Pokemon") do
  pk = Poke.build(:name => "Bulba", :species => 1, :level => 12,
                  :hp => 30, :totalhp => 44, :attack => 20, :defense => 18,
                  :spatk => 22, :spdef => 16, :speed => 25)
  text = PokeAccess::Info.summary_text(pk)
  truthy "summary is not silenced", text && !text.to_s.empty?
  match "reads the Pokemon name and level", text, /Bulba/
  match "includes the species line", text, /Especie1/
  match "includes the HP stat", text, /30/
  match "includes the Speed stat", text, /25/
end

# pokemon_info, the at-a-glance line: name, level and HP; item 0 and status 0 add nothing.
Suite.define("info: pokemon_info reads name, level and HP at a glance") do
  pk = Poke.build(:name => "Char", :level => 30, :hp => 50, :totalhp => 70,
                  :item => 0, :status => 0, :gender => nil)
  glance = PokeAccess::Info.pokemon_info(pk)
  eq "matches the pk_glance template",
     glance, PokeAccess::I18n.t(:pk_glance, :name => "Char", :level => 30, :hp => 50, :tot => 70)
  truthy "nil Pokemon is nil", PokeAccess::Info.pokemon_info(nil).nil?
end

# The glance says the Exp. Share mark the member's panel draws.
Suite.define("info: the glance says the Exp. Share icon the panel draws") do
  pk = Poke.build(:name => "Pika", :level => 12)
  pk.define_singleton_method(:expshare) { true }
  truthy "the member holding the flag says it", PokeAccess::Info.pokemon_info(pk).include?(PokeAccess::I18n.t(:pty_expshare))
end

# move_info of an id-only move takes its name and power from the data provider (the gen-6 stub's power is 40 + id).
Suite.define("info: move_info fills fields from the data provider") do
  move = Object.new
  def move.id; 7; end
  text = PokeAccess::Info.move_info(move)
  truthy "move_info is not silenced", text && !text.to_s.empty?
  match "reads the move name", text, /Mov7/
  match "includes the power phrase", text, /#{PokeAccess::I18n.t(:mv_power, :p => 47)}/
  truthy "nil move is nil", PokeAccess::Info.move_info(nil).nil?
end
