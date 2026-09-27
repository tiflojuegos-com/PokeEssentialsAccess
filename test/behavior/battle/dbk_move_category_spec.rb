# The Enhanced Battle UI's move panel works out four moves' category while drawing: Tera Blast and Tera Starstorm by
# the higher attacking stat once terastallized, Shell Side Arm and Photon Geyser by their use-time step on a copy.

DBKCatMove = Struct.new(:name, :function_code, :category, :calcCategory)

# A battler with the two answers the panel asks: whether it is terastallized, and its attacking stats.
class DBKCatBattler
  def initialize(tera, atk, spatk); @tera = tera; @atk = atk; @spatk = spatk; end
  def tera?; @tera; end
  def getOffensiveStats; [@atk, @spatk]; end
  def pbDirectOpposing; :foe; end
end

# Photon Geyser: special until pbOnStartUse compares the user's attacking stats and stores calcCategory.
class DBKTargetCatMove
  attr_reader :name, :function_code, :category, :calcCategory
  def initialize(code); @name = "Fotogeiser"; @function_code = code; @category = 1; @calcCategory = 1; end
  def pbOnStartUse(user, targets)
    atk, spatk = user.getOffensiveStats
    @calcCategory = (targets == [:foe] && atk > spatk) ? 0 : 1
  end
end

Suite.define("dbk move panel: the category is the one the panel draws") do
  m = PokeAccess::DBKMoveInfo
  plain = DBKCatMove.new("Rayo", "ParalyzeTarget", 1, nil)
  eq "an ordinary move draws its own category", m.shown_category(plain, DBKCatBattler.new(false, 10, 5), false), 1

  blast = DBKCatMove.new("Teraexplosion", "CategoryDependsOnHigherDamageTera", 1, 0)
  eq "Tera Blast, terastallized, takes the higher attacking stat",
     m.shown_category(blast, DBKCatBattler.new(true, 90, 140), true), 1
  eq "whichever it is", m.shown_category(blast, DBKCatBattler.new(true, 140, 90), true), 0
  eq "and without the tera keeps what the move calculated, not its stored category",
     m.shown_category(blast, DBKCatBattler.new(false, 140, 90), false), 0

  geyser = DBKTargetCatMove.new("CategoryDependsOnHigherDamageIgnoreTargetAbility")
  eq "Photon Geyser before its first use: worked out against the foe, as the panel draws it",
     m.shown_category(geyser, DBKCatBattler.new(false, 150, 100), false), 0
  eq "on a copy, the move itself left as it was", geyser.calcCategory, 1
  arm = DBKTargetCatMove.new("CategoryDependsOnHigherDamagePoisonTarget")
  eq "Shell Side Arm the same way, the fight menu's line included",
     PokeAccess::MoveInfo.target_category(arm, DBKCatBattler.new(false, 150, 100)), 0
  eq "and any other move has no such category", PokeAccess::MoveInfo.target_category(plain, DBKCatBattler.new(false, 1, 2)), nil
end

# Terapagos in its Stellar Form, as Anil's and Royal's panels see it: terastallized whatever tera? says.
class DBKStellarBattler < DBKCatBattler
  def initialize(form, atk, spatk); super(false, atk, spatk); @form = form; end
  def isSpecies?(sp); sp == :TERAPAGOS; end
  def form; @form; end
  def tera_type; :STELLAR; end
end

# Tera Starstorm, whose calculated type is its stored one until the panel settles it.
class DBKStarstorm < DBKCatMove
  def type; :NORMAL; end
  def pbCalcType(_b); :NORMAL; end
end

Suite.define("dbk move panel: Terapagos in its Stellar Form draws Tera Starstorm as the panel does") do
  m = PokeAccess::DBKMoveInfo
  storm = DBKStarstorm.new("Teraclusion", "TerapagosCategoryDependsOnHigherDamage", 1, 1)
  stellar = DBKStellarBattler.new(2, 150, 100)
  truthy "the Stellar Form counts as terastallized", m.terastal?(stellar, nil, nil)
  falsy "its other forms do not", m.terastal?(DBKStellarBattler.new(1, 150, 100), nil, nil)
  eq "so the panel's category is the higher attacking stat", m.shown_category(storm, stellar, true), 0
  eq "and its type Stellar", m.shown_type(storm, stellar, true), :STELLAR
  eq "before it, the stored type", m.shown_type(storm, DBKStellarBattler.new(1, 150, 100), false), :NORMAL
end
