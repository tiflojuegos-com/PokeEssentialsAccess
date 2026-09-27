# The summary header's icons, said on the first page in the header's order: the ball, one status slot (fainted, then
# a status, then catching pokerus), the cured-pokerus mark and the shiny star.
Suite.define("summary: the header's icons are said on the first page, the status slot by its priority") do
  s = PokeAccess::Summary
  mon = Struct.new(:hp, :status, :pokerusStage, :ballused, :shiny)
  def_ball = lambda { |pk| s.ball_name(pk) }
  Object.send(:define_method, :pbBallTypeToBall) { |n| n == 1 ? PBItems::POTION : nil }
  begin
    pk = mon.new(20, 0, 2, 1, true)
    def pk.isShiny?; shiny; end
    eq "the ball, the cured mark and the star", s.header_icons(pk),
       [PokeAccess::I18n.t(:sum_ball, :b => PBItems.getName(PBItems::POTION)), PokeAccess::I18n.t(:pk_pokerus_cured),
        PokeAccess::I18n.t(:pk_shiny)].join(", ")
    ko = mon.new(0, 1, 1, nil, false)
    def ko.isShiny?; false; end
    eq "fainted takes the status slot before a status", s.header_icons(ko), PokeAccess::I18n.t(:pk_fainted)
    sick = mon.new(5, 1, 1, nil, false)
    def sick.isShiny?; false; end
    eq "a status before pokerus", s.header_icons(sick), PokeAccess::I18n.t(PokeAccess::Data.status_name(1))
    ill = mon.new(5, 0, 1, nil, false)
    def ill.isShiny?; false; end
    eq "and pokerus that is catching when the slot is free", s.header_icons(ill), PokeAccess::I18n.t(:pk_pokerus)
    falsy "a ball number with no item is no ball", def_ball.call(mon.new(5, 0, 0, 7, false))
  ensure
    Object.send(:remove_method, :pbBallTypeToBall)
  end
end
