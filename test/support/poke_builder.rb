# A Pokemon stand-in with every field the readers touch; each spec overrides only what it cares about.
class TestPoke
  attr_accessor :name, :level, :species, :hp, :totalhp, :attack, :defense, :spatk, :spdef, :speed,
                :nature, :ability, :item, :moves, :iv, :ev, :status, :gender, :ribbons, :happiness,
                :personalID, :form, :shiny

  # Builds a Pokemon stub from an options hash; unspecified fields take a playable default.
  def self.build(opts = {})
    p = new
    p.name = opts.fetch(:name, "Tester")
    p.level = opts.fetch(:level, 25)
    p.species = opts.fetch(:species, 1)
    p.hp = opts.fetch(:hp, 40)
    p.totalhp = opts.fetch(:totalhp, 40)
    p.attack = opts.fetch(:attack, 30)
    p.defense = opts.fetch(:defense, 28)
    p.spatk = opts.fetch(:spatk, 32)
    p.spdef = opts.fetch(:spdef, 26)
    p.speed = opts.fetch(:speed, 35)
    p.nature = opts.fetch(:nature, 0)
    p.ability = opts.fetch(:ability, 1)
    p.item = opts.fetch(:item, 0)
    p.moves = opts.fetch(:moves, [1, 2, 3, 4])
    p.iv = opts.fetch(:iv, [31, 31, 31, 31, 31, 31])
    p.ev = opts.fetch(:ev, [0, 0, 0, 0, 0, 0])
    p.status = opts.fetch(:status, 0)
    p.gender = opts.fetch(:gender, 0)
    p.ribbons = opts.fetch(:ribbons, [])
    p.happiness = opts.fetch(:happiness, 70)
    p.personalID = opts.fetch(:personalID, 123456)
    p.form = opts.fetch(:form, 0)
    p.shiny = opts.fetch(:shiny, false)
    p
  end

  # Shiny only when the spec asks for it (:shiny => true).
  def shiny?; @shiny ? true : false; end
end

# Short alias for specs.
Poke = TestPoke
