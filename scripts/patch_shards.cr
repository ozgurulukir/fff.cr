PATCHES = {
  {
    shard:    "term-reader",
    path:     "lib/term-reader/src/term-reader.cr",
    search:   "@output.as(IO::FileDescriptor).sync = buffering",
    replace:  "@output.as(IO::FileDescriptor).sync = buffering || false",
  },
  {
    shard:    "term-prompt",
    path:     "lib/term-prompt/src/prompt/confirm_question.cr",
    search:   "Regex.escape(positive.to_s[0])",
    replace:  "Regex.escape(positive.to_s[0].to_s)",
  },
  {
    shard:    "term-color",
    path:     "lib/term-color/src/color/color.cr",
    search:   "Cor.truecolor_string",
    replace:  "Color.truecolor_string",
  },
}

applied = 0
skipped = 0

PATCHES.each do |patch|
  path = patch[:path]
  unless File.exists?(path)
    STDERR.puts "  SKIP #{patch[:shard]}: #{path} not found"
    skipped += 1
    next
  end

  content = File.read(path)

  if content.includes?(patch[:replace])
    puts "  OK   #{patch[:shard]}: already patched"
    skipped += 1
    next
  end

  unless content.includes?(patch[:search])
    STDERR.puts "  WARN #{patch[:shard]}: search string not found (upstream may have fixed this)"
    skipped += 1
    next
  end

  content = content.gsub(patch[:search], patch[:replace])
  File.write(path, content)
  puts "  FIX  #{patch[:shard]}: patched successfully"
  applied += 1
end

puts "\n  #{applied} patched, #{skipped} skipped"
exit(applied > 0 || skipped == PATCHES.size ? 0 : 1)
