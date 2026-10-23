# Regenerates every committed census in test/static from the decompiled dumps (outside the repo, absent on CI):
# arity, era, fangame classes and plugins, field moves, and the reader censuses with the test-file one; then the
# reference census from the plugin copies in _refmods, which takes no dumps path. Each builder still runs alone. Run
# after adding or refreshing a dump, a reference copy or a test file:
#   ruby test/static/build_census.rb ["path\to\decompiled Scripts"]
BUILDERS = %w[build_arity_census build_era_census build_fangame_census build_field_move_census build_reader_census].freeze

failed = BUILDERS.reject do |b|
  puts "== #{b}"
  system("ruby", File.join(File.dirname(__FILE__), "#{b}.rb"), *ARGV)
end
puts "== build_reference_census"
failed.push("build_reference_census") unless system("ruby", File.join(File.dirname(__FILE__), "build_reference_census.rb"))
puts(failed.empty? ? "every census regenerated" : "failed: #{failed.join(', ')}")
exit(failed.empty? ? 0 : 1)
