# Relict's in-battle Arcy Plate selector (Battle::Scene#rewriteArcyPlates): a left/right sprite cursor over
# the owned plates, each granting a type damage/catch boost. The plate name and its type are drawn to a
# bitmap, so nothing is spoken. rewriteArcyPlates(plates, index) runs on open and on every move; read the
# focused plate's item name and type (deduped by index). Guarded: a no-op where absent.
PokeAccess::Game.define("relict") do
  # The dedup ivar lives on the battle-long Scene; reset it when the picker (re)opens so reopening on the
  # same plate index still reads.
  before("Battle::Scene", :pbActivateArcyPlates) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :plate_idx)
  end
  after("Battle::Scene", :rewriteArcyPlates) do |scene, _r, args|
    plates = args[0]; index = args[1]
    next unless plates.is_a?(Array) && index && index >= 0 && index < plates.length
    next unless PokeAccess::Cursor.changed?(scene, :plate_idx, index)
    item = plates[index]
    nm = (GameData::Item.get(item).name rescue item.to_s)
    tsym = (::PLATE_TYPES[item] rescue nil)
    tnm = tsym ? (GameData::Type.get(tsym).name rescue nil) : nil
    txt = tnm ? "#{nm}, #{tnm}" : nm.to_s
    PokeAccess.speak_clean(txt, true)
  end
end
