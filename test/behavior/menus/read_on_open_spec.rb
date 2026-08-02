# read_on_open: the opening-summary primitive. Its one hard rule is QUEUED speech (interrupt false,
# always) -- an opening read must never cut the transition or a line already playing; only navigation
# readers interrupt. Default timing is after the opener; :timing => :before speaks before the original
# runs (openers that block in their own loop, like OpaloCard's pages). Nil/empty text stays silent.
Suite.define("hooks: read_on_open speaks queued, before or after the opener") do
  order = []
  klass = Class.new do
    define_method(:pbStartScene) { order << :orig_start; :started }
    define_method(:blocking_page) { order << :orig_page; :page }
  end
  Object.const_set(:RooTarget, klass) unless Object.const_defined?(:RooTarget)

  PokeAccess::Hooks.read_on_open("RooTarget") { |_s| order << :read_after; "opening summary" }
  PokeAccess::Hooks.read_on_open("RooTarget", :blocking_page, :timing => :before) do |_s|
    order << :read_before
    "page summary"
  end
  PokeAccess::Hooks.read_on_open("RooTarget", :pbStartScene) { |_s| nil }

  t = RooTarget.new
  eq "the opener's return value is preserved", t.pbStartScene, :started
  spoke "the opening summary is spoken", /opening summary/
  eq "the after-read runs after the original", order.index(:orig_start) < order.index(:read_after), true
  truthy "the opening read is QUEUED (interrupt false)",
         SpeakCapture.log.any? { |line, int| line =~ /opening summary/ && int == false }
  falsy "no opening read ever interrupts",
        SpeakCapture.log.any? { |_line, int| int == true }

  SpeakCapture.clear
  order.clear
  t.blocking_page
  spoke "the before-read speaks the page summary", /page summary/
  eq "the before-read runs before the blocking original", order, [:read_before, :orig_page]
  truthy "the before-read is queued too",
         SpeakCapture.log.any? { |line, int| line =~ /page summary/ && int == false }
end
