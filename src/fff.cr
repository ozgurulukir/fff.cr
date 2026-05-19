require "term-color"
require "term-screen"
require "term-cursor"
require "file"
require "file_utils"
require "process"
require "io"

# Fucking Fast File Manager - Crystal Port
# Using crystal-term shards: term-color, term-screen, term-cursor

module FFF
  VERSION = "0.1.0"

  # Raw terminal I/O using IO#raw
  class Terminal
    getter width : Int32
    getter height : Int32

    @original_tty : Bool

    def initialize
      @original_tty = STDIN.tty?
      @width = Term::Screen.width
      @height = Term::Screen.height
    end

    def max_items
      @height - 3
    end

    def enter_raw_mode
      @width = Term::Screen.width
      @height = Term::Screen.height
      print Term::Cursor.hide
      print "\e[?1049h"  # alternate screen buffer
      print Term::Cursor.clear_screen
      print Term::Cursor.move_to(0, 0)
      STDOUT.flush
    end

    def leave_raw_mode
      print Term::Cursor.clear_screen
      print Term::Cursor.move_to(0, 0)
      print Term::Cursor.show
      print "\e[?1049l"  # restore main screen
      STDOUT.flush
    end

    def clear_screen
      print Term::Cursor.clear_screen
      print Term::Cursor.move_to(0, 0)
      STDOUT.flush
    end

    def move_to(row : Int32, col : Int32)
      print Term::Cursor.move_to(row, col)
      STDOUT.flush
    end

    def clear_line(row : Int32)
      print Term::Cursor.move_to(row, 0)
      print Term::Cursor.clear_line
      STDOUT.flush
    end

    # Read a single keypress using IO#raw (Crystal built-in)
    def read_keypress : String?
      return nil unless @original_tty

      char = STDIN.raw do |io|
        io.read_char
      end
      char.try(&.to_s)
    end

    # Read a line with echo (for search, new dir, etc.)
    def read_line(prompt : String = "") : String
      print prompt
      STDOUT.flush
      STDIN.gets.to_s.strip
    end

    def refresh_size
      @width = Term::Screen.width
      @height = Term::Screen.height
    end
  end

  # Configuration from environment
  class Config
    getter editor : String
    getter opener : String
    getter trash_dir : String
    getter cd_on_exit : Bool
    getter cd_file : String
    getter key_up : String
    getter key_down : String
    getter key_enter : String
    getter key_quit : String
    getter key_search : String
    getter key_parent : String
    getter key_mark : String
    getter key_mark_all : String
    getter key_copy : String
    getter key_move : String
    getter key_delete : String
    getter key_new_dir : String
    getter key_paste : String
    getter key_preview : String
    getter key_page_up : String
    getter key_page_down : String
    getter key_top : String
    getter key_bottom : String
    getter key_rename : String
    getter key_shell : String

    def initialize
      @editor = ENV["EDITOR"]? || "vi"
      @opener = ENV["FFF_OPENER"]? || "xdg-open"
      @trash_dir = ENV["FFF_TRASH"]? || File.join(ENV["HOME"], ".local", "share", "fff", "trash")
      @cd_on_exit = (ENV["FFF_CD_ON_EXIT"]? == "1")
      @cd_file = ENV["FFF_CD_FILE"]? || File.join(ENV["HOME"], ".cache", "fff", ".fff_d")
      @key_up = ENV["FFF_KEY_UP"]? || "k"
      @key_down = ENV["FFF_KEY_DOWN"]? || "j"
      @key_enter = ENV["FFF_KEY_ENTER"]? || "l"
      @key_quit = ENV["FFF_KEY_QUIT"]? || "q"
      @key_search = ENV["FFF_KEY_SEARCH"]? || "/"
      @key_parent = ENV["FFF_KEY_PARENT"]? || "h"
      @key_mark = ENV["FFF_KEY_MARK"]? || " "
      @key_mark_all = ENV["FFF_KEY_MARK_ALL"]? || "m"
      @key_copy = ENV["FFF_KEY_COPY"]? || "y"
      @key_move = ENV["FFF_KEY_MOVE"]? || "v"
      @key_delete = ENV["FFF_KEY_DELETE"]? || "d"
      @key_new_dir = ENV["FFF_KEY_NEW_DIR"]? || "n"
      @key_paste = ENV["FFF_KEY_PASTE"]? || "p"
      @key_preview = ENV["FFF_KEY_PREVIEW"]? || "i"
      @key_page_up = ENV["FFF_KEY_PAGE_UP"]? || "\e[A"   # arrow up
      @key_page_down = ENV["FFF_KEY_PAGE_DOWN"]? || "\e[B" # arrow down
      @key_top = ENV["FFF_KEY_TOP"]? || "g"
      @key_bottom = ENV["FFF_KEY_BOTTOM"]? || "G"
      @key_rename = ENV["FFF_KEY_RENAME"]? || "r"
      @key_shell = ENV["FFF_KEY_SHELL"]? || "s"
    end
  end

  # Main application
  class Application
    def initialize(@args : Array(String))
    end

    def run
      if @args.includes?("--version")
        puts "fff #{VERSION}"
        return
      end

      if @args.includes?("--help") || @args.includes?("-h")
        print_help
        return
      end

      start_dir = @args.find { |a| !a.starts_with?('-') } || "."
      config = Config.new

      fm = FileManager.new(config, start_dir)
      fm.run
    end

    private def print_help
      puts "fff - Fucking Fast File Manager (Crystal)"
      puts ""
      puts "Usage: fff [options] [directory]"
      puts ""
      puts "Options:"
      puts "  -h, --help     Show this help"
      puts "  --version      Show version"
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
      puts ""
      puts "All keys configurable via FFF_KEY_* env vars."
    end
  end

  # The file manager
  class FileManager
    @term : Terminal
    @config : Config
    @list : Array(String)
    @scroll : Int32
    @page_offset : Int32
    @marked : Set(String)
    @clipboard : Array(String)
    @clipboard_mode : Symbol
    @running : Bool

    def initialize(@config : Config, start_dir : String)
      @term = Terminal.new
      Dir.cd(start_dir)
      @list = [] of String
      @scroll = 0
      @page_offset = 0
      @marked = Set(String).new
      @clipboard = [] of String
      @clipboard_mode = :none
      @running = true
    end

    def run
      ensure_dirs
      @term.enter_raw_mode
      read_directory
      event_loop
    rescue e : Exception
      @term.leave_raw_mode
      STDERR.puts "fff error: #{e.message}"
      STDERR.puts e.backtrace.join('\n') if ENV["FFF_DEBUG"]? == "1"
    end

    private def ensure_dirs
      FileUtils.mkdir_p(File.join(ENV["HOME"], ".cache", "fff"))
      FileUtils.mkdir_p(@config.trash_dir)
    end

    # ── Directory reading ──────────────────────────────────────

    private def read_directory
      cwd = Dir.current
      dirs = [] of String
      files = [] of String

      Dir.each_child(cwd) do |name|
        path = File.join(cwd, name)
        if File.directory?(path)
          dirs << path
        else
          files << path
        end
      rescue File::NotFoundError
        next
      end

      @list = dirs.sort + files.sort
      @scroll = 0
      @page_offset = 0
    end

    private def list_total
      @list.size
    end

    # ── Drawing ────────────────────────────────────────────────

    private def redraw
      @term.refresh_size
      @term.clear_screen
      draw_list
      draw_status
      STDOUT.flush
    end

    private def draw_list
      max = @term.max_items
      offset = @page_offset

      max.times do |i|
        idx = offset + i
        break if idx >= @list.size

        path = @list[idx]
        name = File.basename(path)
        selected = (idx == @scroll)
        is_marked = @marked.includes?(path)
        in_clip = @clipboard.includes?(path)

        color = if selected
                  :red
                elsif is_marked
                  :yellow
                elsif in_clip
                  :magenta
                elsif File.directory?(path)
                  :blue
                elsif File.info?(path).try(&.permissions.includes?(::File::Permissions::OtherExecute))
                  :green
                else
                  :white
                end

        prefix = is_marked ? "*" : " "
        suffix = File.directory?(path) ? "/" : ""
        label = "#{prefix} #{name}#{suffix}"

        # Truncate to terminal width
        label = label[0...(@term.width - 1)] if label.size > @term.width

        @term.move_to(i, 0)
        print Term::Color.truecolor_string(label, fore: Term::Color.color(color))
      end
    end

    private def draw_status
      row = @term.max_items
      cwd = Dir.current
      total = list_total
      cur = total > 0 ? @scroll + 1 : 0
      marked_n = @marked.size
      clip_str = case @clipboard_mode
                 when :copy then " [yank:#{@clipboard.size}]"
                 when :move then " [cut:#{@clipboard.size}]"
                 else ""
                 end

      status = " #{cur}/#{total} #{cwd} [#{marked_n} marked]#{clip_str}"

      @term.move_to(row, 0)
      print Term::Color.truecolor_string(status,
        fore: Term::Color.color(:black),
        back: Term::Color.color(:white))
    end

    # ── Event loop ─────────────────────────────────────────────

    private def event_loop
      redraw

      while @running
        key = @term.read_keypress

        unless key
          sleep 10.milliseconds
          next
        end

        handle_key(key)
        redraw if @running
      end

      @term.leave_raw_mode
      save_cd_on_exit
    end

    private def handle_key(key : String)
      case key
      when @config.key_quit     then quit
      when @config.key_up       then cursor_up
      when @config.key_down     then cursor_down
      when @config.key_enter    then enter_item
      when @config.key_parent   then go_parent
      when @config.key_search   then search
      when @config.key_mark     then toggle_mark
      when @config.key_mark_all then toggle_mark_all
      when @config.key_copy     then yank_files
      when @config.key_move     then cut_files
      when @config.key_paste    then paste_files
      when @config.key_delete   then delete_files
      when @config.key_new_dir  then new_directory
      when @config.key_preview  then preview_file
      when @config.key_page_up  then page_up
      when @config.key_page_down then page_down
      when @config.key_top      then go_top
      when @config.key_bottom   then go_bottom
      when @config.key_rename   then rename_item
      when @config.key_shell    then spawn_shell
      end
    end

    # ── Navigation ─────────────────────────────────────────────

    private def cursor_up
      return if @scroll <= 0
      @scroll -= 1
      adjust_page_offset
    end

    private def cursor_down
      return if @scroll >= list_total - 1
      @scroll += 1
      adjust_page_offset
    end

    private def page_up
      max = @term.max_items
      @scroll = {@scroll - max, 0}.max
      adjust_page_offset
    end

    private def page_down
      max = @term.max_items
      @scroll = {@scroll + max, list_total - 1}.min
      adjust_page_offset
    end

    private def go_top
      @scroll = 0
      @page_offset = 0
    end

    private def go_bottom
      @scroll = {list_total - 1, 0}.max
      adjust_page_offset
    end

    private def adjust_page_offset
      max = @term.max_items
      if @scroll < @page_offset
        @page_offset = @scroll
      elsif @scroll >= @page_offset + max
        @page_offset = @scroll - max + 1
      end
      @page_offset = {@page_offset, 0}.max
    end

    private def enter_item
      path = @list[@scroll]?
      return unless path

      if File.directory?(path)
        Dir.cd(path)
        read_directory
      else
        # Open file with opener, restore terminal temporarily
        @term.leave_raw_mode
        Process.run(@config.opener, [path],
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)
        @term.enter_raw_mode
      end
    end

    private def go_parent
      cwd = Dir.current
      return if cwd == "/"
      Dir.cd(File.dirname(cwd))
      read_directory
    end

    # ── Marking ────────────────────────────────────────────────

    private def toggle_mark
      path = @list[@scroll]?
      return unless path
      @marked.includes?(path) ? @marked.delete(path) : @marked.add(path)
    end

    private def toggle_mark_all
      if @marked.size == @list.size
        @marked.clear
      else
        @list.each { |p| @marked.add(p) }
      end
    end

    # ── Clipboard ──────────────────────────────────────────────

    private def yank_files
      paths = marked_or_current
      return if paths.empty?
      @clipboard = paths
      @clipboard_mode = :copy
      @marked.clear
    end

    private def cut_files
      paths = marked_or_current
      return if paths.empty?
      @clipboard = paths
      @clipboard_mode = :move
      @marked.clear
    end

    private def paste_files
      return if @clipboard.empty?
      dest_dir = Dir.current

      @clipboard.each do |src|
        name = File.basename(src)
        dest = File.join(dest_dir, name)
        begin
          case @clipboard_mode
          when :copy
            File.directory?(src) ? FileUtils.cp_r(src, dest) : FileUtils.cp(src, dest)
          when :move
            FileUtils.mv(src, dest)
          end
        rescue e
          show_error("paste: #{e.message}")
        end
      end

      @clipboard.clear
      @clipboard_mode = :none
      read_directory
    end

    # ── Delete ─────────────────────────────────────────────────

    private def delete_files
      paths = marked_or_current
      return if paths.empty?

      return unless confirm?("Delete #{paths.size} item(s)?")

      paths.each do |path|
        begin
          File.directory?(path) ? FileUtils.rm_rf(path) : FileUtils.rm(path)
        rescue e
          show_error("delete: #{e.message}")
        end
      end

      @marked.clear
      read_directory
    end

    # ── New directory ──────────────────────────────────────────

    private def new_directory
      name = prompt_input("New dir: ")
      return if name.empty?
      begin
        Dir.mkdir(File.join(Dir.current, name))
        read_directory
      rescue e
        show_error("mkdir: #{e.message}")
      end
    end

    # ── Rename ─────────────────────────────────────────────────

    private def rename_item
      old_path = @list[@scroll]?
      return unless old_path

      old_name = File.basename(old_path)
      new_name = prompt_input("Rename: #{old_name} -> ")
      return if new_name.empty? || new_name == old_name

      new_path = File.join(Dir.current, new_name)
      begin
        File.rename(old_path, new_path)
        read_directory
      rescue e
        show_error("rename: #{e.message}")
      end
    end

    # ── Search ─────────────────────────────────────────────────

    private def search
      term = prompt_input("/")
      if term.empty?
        read_directory
      else
        cwd = Dir.current
        results = @list.select { |p| File.basename(p).downcase.includes?(term.downcase) }
        if results.empty?
          show_error("No matches for '#{term}'")
        else
          @list = results
          @scroll = 0
          @page_offset = 0
        end
      end
    end

    # ── Preview ────────────────────────────────────────────────

    private def preview_file
      path = @list[@scroll]?
      return unless path && File.file?(path)

      @term.leave_raw_mode

      size = File.size(path)
      mtime = File.info(path).modification_time

      puts "\e[1m#{File.basename(path)}\e[0m  #{human_size(size)}  #{mtime}"
      puts "-" * 60

      if size < 2 * 1024 * 1024
        File.open(path) do |f|
          30.times do
            line = f.gets
            break unless line
            puts line
          end
        end
      else
        puts "(file too large)"
      end

      puts "\nPress Enter to return..."
      STDIN.gets

      @term.enter_raw_mode
    end

    # ── Shell ──────────────────────────────────────────────────

    private def spawn_shell
      @term.leave_raw_mode

      shell = ENV["SHELL"]? || "/bin/sh"
      puts "(fff) spawning shell, type 'exit' to return"
      Process.run(shell, input: Process::Redirect::Inherit,
                        output: Process::Redirect::Inherit,
                        error: Process::Redirect::Inherit)

      @term.enter_raw_mode
      read_directory  # refresh in case files changed
    end

    # ── Quit ───────────────────────────────────────────────────

    private def quit
      @running = false
    end

    private def save_cd_on_exit
      return unless @config.cd_on_exit
      File.write(@config.cd_file, Dir.current)
    end

    # ── Helpers ────────────────────────────────────────────────

    private def marked_or_current : Array(String)
      if @marked.empty?
        path = @list[@scroll]?
        path ? [path] : [] of String
      else
        @marked.to_a
      end
    end

    private def prompt_input(prompt : String) : String
      @term.leave_raw_mode
      result = @term.read_line(prompt)
      @term.enter_raw_mode
      result
    end

    private def confirm?(message : String) : Bool
      @term.leave_raw_mode
      print "#{message} [y/N] "
      STDOUT.flush
      answer = STDIN.gets.to_s.strip.downcase
      @term.enter_raw_mode
      answer == "y"
    end

    private def show_error(message : String)
      row = @term.max_items + 1
      @term.move_to(row, 0)
      print Term::Color.truecolor_string(" ERROR: #{message} ", fore: Term::Color.color(:white), back: Term::Color.color(:red))
      STDOUT.flush
      sleep 2.seconds
    end

    private def human_size(bytes : Int) : String
      case bytes
      when .<(1024)           then "#{bytes}B"
      when .<(1024 * 1024)    then "#{bytes / 1024}K"
      when .<(1024 * 1024 * 1024) then "#{bytes / (1024 * 1024)}M"
      else "#{bytes / (1024 * 1024 * 1024)}G"
      end
    end
  end
end

app = FFF::Application.new(ARGV)
app.run
