# Native RMXP loader (for games without mkxp-z), injected into Scripts.rxdata before "Main": evals our own
# accessibility/boot.rb. Needs a Ruby 1.8.7 interpreter (min_by/max_by), not RMXP's stock 1.8.1.
begin
  path = "accessibility/boot.rb"
  if File.exist?(path)
    eval(File.read(path), TOPLEVEL_BINDING, path)
  end
rescue Exception => e
  raise if e.is_a?(SystemExit)
  begin
    File.open("accessibility/data/loader_error.txt", "w") do |f|
      f.write("#{e.class}: #{e.message}\n")
      f.write((e.backtrace || []).join("\n"))
    end
  rescue StandardError
  end
end
