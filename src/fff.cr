require "term-color"
require "term-screen"
require "term-cursor"
require "term-reader"
require "term-prompt"
require "file"
require "file_utils"
require "process"
require "signal"

# Fucking Fast File Manager - Crystal Port
# Using crystal-term shards: term-color, term-screen, term-cursor, term-reader, term-prompt

require "./fff/format_utils"
require "./fff/draw_state"
require "./fff/terminal"
require "./fff/config"
require "./fff/directory_manager"
require "./fff/ui_renderer"
require "./fff/input_mode"
require "./fff/file_operations"
require "./fff/search_engine"
require "./fff/navigation_handlers"
require "./fff/file_op_handlers"
require "./fff/view_handlers"
require "./fff/file_manager"

module FFF
  VERSION = "0.2.1"

  # Main application
  class Application
    def initialize(@args : Array(String))
    end

    def run
      if @args.includes?("--version")
        puts "fff-cr #{VERSION}"
        return
      end

      if @args.includes?("--help") || @args.includes?("-h")
        print_help
        return
      end

      picker_mode = @args.includes?("-p")
      start_dir = @args.find { |a| !a.starts_with?('-') } || "."
      config = Config.new

      fm = FileManager.new(config, start_dir, picker_mode: picker_mode)
      fm.run
    end

    private def print_help
      puts "fff-cr - Fucking Fast File Manager (Crystal)"
      puts ""
      puts "Usage: fff-cr [options] [directory]"
      puts ""
      puts "Options:"
      puts "  -h, --help     Show this help"
      puts "  --version      Show version"
      puts "  -p             Picker mode (write selection to file)"
      puts ""
      puts "Keys:"
      puts "  j/k       Down/Up        l/h    Enter/Parent"
      puts "  q         Quit           /      Search"
      puts "  space     Mark           m      Mark all"
      puts "  y         Yank (copy)    v      Move (cut)"
      puts "  p         Paste          d      Delete"
      puts "  n         New dir        r      Rename"
      puts "  i         Preview        s      Shell"
      puts "  g/G       Top/Bottom     arrows Page up/down"
      puts "  .         Toggle hidden  ~      Home dir"
      puts "  -         Prev dir       e      Refresh"
      puts "  f         New file       x      Attributes"
      puts "  X         Toggle exec    :      Go to dir"
      puts "  t         Go to trash"
      puts "  S         Create symlink"
      puts "  =/+       Cycle sort mode/reverse"
      puts ""
      puts "All keys configurable via FFF_KEY_* env vars."
    end
  end
end

app = FFF::Application.new(ARGV)
app.run
