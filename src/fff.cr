require "term-color"
require "term-screen"
require "term-cursor"
require "file"
require "file_utils"
require "process"

# Fucking Fast File Manager - Crystal Port
# Using crystal-term shards for proper TUI

module FFF
  VERSION = "0.1.0"

  # Simple key reader
  class KeyReader
    def initialize
      @input = STDIN
    end

    def read_keypress : String?
      # Set terminal to raw mode
      system("stty -echo -icanon min 0 time 0 2>/dev/null")

      char = @input.read_char

      # Restore terminal
      system("stty echo icanon 2>/dev/null")

      char.try(&.to_s)
    end

    def read_line(prompt : String = "") : String
      print prompt
      @input.gets.to_s.strip
    end
  end

  # Configuration
  class Config
    getter editor : String = ENV["EDITOR"]? || "vim"
    getter opener : String = ENV["FFF_OPENER"]? || "xdg-open"
    getter trash_dir : String = ENV["FFF_TRASH"]? || File.join(ENV["HOME"], ".local", "share", "fff", "trash")
    getter cd_on_exit : Bool = ENV["FFF_CD_ON_EXIT"]?.try(&.to_i?) != 0
    getter cd_file : String = ENV["FFF_CD_FILE"]? || File.join(ENV["HOME"], ".cache", "fff", ".fff_d")

    # Keybindings
    getter key_up : String = ENV["FFF_KEY_UP"]? || "k"
    getter key_down : String = ENV["FFF_KEY_DOWN"]? || "j"
    getter key_enter : String = ENV["FFF_KEY_ENTER"]? || "l"
    getter key_quit : String = ENV["FFF_KEY_QUIT"]? || "q"
    getter key_search : String = ENV["FFF_KEY_SEARCH"]? || "/"
    getter key_parent : String = ENV["FFF_KEY_PARENT"]? || "h"
    getter key_mark : String = ENV["FFF_KEY_MARK"]? || " "
    getter key_mark_all : String = ENV["FFF_KEY_MARK_ALL"]? || "m"
    getter key_copy : String = ENV["FFF_KEY_COPY"]? || "c"
    getter key_move : String = ENV["FFF_KEY_MOVE"]? || "v"
    getter key_delete : String = ENV["FFF_KEY_DELETE"]? || "d"
    getter key_new_dir : String = ENV["FFF_KEY_NEW_DIR"]? || "n"
    getter key_paste : String = ENV["FFF_KEY_PASTE"]? || "p"
    getter key_preview : String = ENV["FFF_KEY_PREVIEW"]? || "i"
    getter key_page_up : String = ENV["FFF_KEY_PAGE_UP"]? || "K"
    getter key_page_down : String = ENV["FFF_KEY_PAGE_DOWN"]? || "J"
  end

  # Main application
  class Application
    property start_dir : String = "."
    property version : Bool = false
    property help : Bool = false

    def initialize(args : Array(String))
      @help = false

      args.each do |arg|
        case arg
        when "--version"
          @version = true
        when "--help", "-h"
          @help = true
        else
          @start_dir = arg
        end
      end
    end

    def run
      if @version
        puts "fff #{VERSION}"
        exit
      end

      if @help
        print_help
        exit
      end

      config = Config.new
      Dir.cd(@start_dir) unless @start_dir == "."

      file_manager = FileManager.new(config)
      file_manager.run
    end

    def print_help
      puts "Fucking Fast File Manager - Crystal Port"
      puts "Usage: fff [directory]"
      puts ""
      puts "Keybindings:"
      puts "  K      - Move up"
      puts "  J      - Move down"
      puts "  L      - Enter directory/open file"
      puts "  H      - Go to parent directory"
      puts "  /      - Search files"
      puts "  Q      - Quit"
      puts "  SPACE  - Mark file"
      puts "  M      - Mark all files"
      puts "  C      - Copy marked files"
      puts "  V      - Move marked files"
      puts "  P      - Paste files"
      puts "  D      - Delete marked files"
      puts "  N      - Create new directory"
      puts "  I      - Preview file"
      puts "  SHIFT+K - Page up"
      puts "  SHIFT+J - Page down"
      puts ""
      puts "Environment Variables:"
      puts "  FFF_KEY_UP       Up key (default: k)"
      puts "  FFF_KEY_DOWN     Down key (default: j)"
      puts "  FFF_KEY_ENTER    Enter key (default: l)"
      puts "  FFF_KEY_QUIT     Quit key (default: q)"
      puts "  FFF_KEY_SEARCH   Search key (default: /)"
      puts "  FFF_KEY_PARENT   Parent key (default: h)"
      puts "  FFF_KEY_MARK     Mark file (default: space)"
      puts "  FFF_KEY_MARK_ALL Mark all files (default: m)"
      puts "  FFF_KEY_COPY     Copy files (default: c)"
      puts "  FFF_KEY_MOVE     Move files (default: v)"
      puts "  FFF_KEY_PASTE    Paste files (default: p)"
      puts "  FFF_KEY_DELETE   Delete files (default: d)"
      puts "  FFF_KEY_NEW_DIR  Create directory (default: n)"
      puts "  FFF_KEY_PREVIEW  Preview file (default: i)"
      puts "  FFF_KEY_PAGE_UP  Page up (default: K)"
      puts "  FFF_KEY_PAGE_DOWN Page down (default: J)"
      puts "  FFF_OPENER       File opener (default: xdg-open)"
      puts "  FFF_TRASH        Trash directory"
      puts "  FFF_CD_ON_EXIT   Save last directory on exit"
      puts "  FFF_CD_FILE      File to save last directory"
    end
  end

  # Terminal UI using crystal-term shards
  class TerminalUI
    getter screen : Term::Screen.class
    getter cursor : Term::Cursor.class
    getter reader : KeyReader
    getter max_items : Int32
    getter y : Int32 = 0

    def initialize
      @screen = Term::Screen
      @cursor = Term::Cursor
      @reader = KeyReader.new

      height = @screen.height
      @max_items = height - 3
    end

    def setup
      @cursor.hide
      @cursor.clear_screen
    end

    def reset
      @cursor.show
      @cursor.clear_screen
    end

    def clear
      @cursor.clear_screen
    end

    def move_to(x : Int32, y : Int32)
      @cursor.move_to(y, x)
    end

    def read_keypress
      @reader.read_keypress
    end

    def read_line(prompt : String = "")
      @reader.read_line(prompt)
    end

    def get_terminal_size
      {@screen.width, @screen.height}
    end
  end

  # Main File Manager
  class FileManager
    getter config : Config
    getter terminal : TerminalUI
    getter current_dir : String = Dir.current
    getter list : Array(String) = [] of String
    getter marked_files : Hash(String, String) = {} of String => String
    getter scroll : Int32 = 0
    getter list_total : Int32 = 0
    getter all_marked : Bool = false
    getter clipboard_files : Array(String) = [] of String
    getter clipboard_mode : Symbol = :none # :none, :copy, :move
    getter page_offset : Int32 = 0

    def initialize(@config : Config)
      @terminal = TerminalUI.new
    end

    def setup
      FileUtils.mkdir_p(File.join(ENV["HOME"], ".cache", "fff"))
      FileUtils.mkdir_p(@config.trash_dir)

      @terminal.setup
      read_directory
      run_event_loop
    end

    def read_directory
      @current_dir = Dir.current
      dirs = [] of String
      files = [] of String

      Dir.each_child(@current_dir) do |item|
        full_path = File.join(@current_dir, item)
        if File.directory?(full_path)
          dirs << full_path
        else
          files << full_path
        end
      end

      @list = dirs + files
      @list = ["empty"] of String if @list.empty?
      @list_total = @list.size - 1
      @page_offset = 0
    end

    def visible_range
      max_items = @terminal.max_items
      start_idx = @page_offset
      end_idx = Math.min(@page_offset + max_items, @list.size)
      (start_idx...end_idx)
    end

    def draw_directory
      @terminal.clear

      visible_range.each do |i|
        print_line(i - @page_offset, @list[i]?)
      end
    end

    def print_line(display_index : Int32, file_path : String?)
      return unless file_path

      file_name = File.basename(file_path)
      is_marked = @marked_files.has_key?(file_path)
      is_clipboard = @clipboard_files.includes?(file_path)
      actual_index = @page_offset + display_index

      color = if is_clipboard
                Term::Color.color(:magenta)
              elsif is_marked
                Term::Color.color(:yellow)
              elsif File.directory?(file_path)
                Term::Color.color(:blue)
              elsif File.executable?(file_path)
                Term::Color.color(:green)
              else
                Term::Color.color(:white)
              end

      if actual_index == @scroll
        color = Term::Color.color(:red)
      end

      suffix = File.directory?(file_path) ? "/" : ""
      mark = is_marked ? "*" : " "

      @terminal.move_to(0, display_index)
      print "#{mark}#{Term::Color.truecolor_string(file_name + suffix, fore: color)}"
    end

    def status_line
      pwd_escaped = @current_dir.gsub(/[^[:print:]]/, "^[")
      marked_count = @marked_files.size
      all_marked_str = @all_marked ? "ALL" : marked_count.to_s
      clipboard_info = @clipboard_mode == :none ? "" : " [#{@clipboard_mode}: #{@clipboard_files.size}]"
      page_info = @list.size > @terminal.max_items ? " [#{@page_offset + 1}-#{Math.min(@page_offset + @terminal.max_items, @list.size)}/#{@list.size}]" : ""

      @terminal.move_to(0, @terminal.max_items)
      print Term::Color.truecolor_string(" (#{@scroll + 1}/#{@list_total + 1}) #{pwd_escaped} [#{all_marked_str} marked]#{clipboard_info}#{page_info}",
        fore: Term::Color.color(:black),
        back: Term::Color.color(:white))
    end

    def redraw
      @terminal.clear
      draw_directory
      status_line
    end

    def run_event_loop
      loop do
        draw_directory
        status_line

        key = @terminal.read_keypress
        break unless key

        handle_keypress(key)
      end
    end

    def handle_keypress(key : String)
      case key
      when @config.key_quit
        quit
      when @config.key_up
        scroll_up
      when @config.key_down
        scroll_down
      when @config.key_page_up
        page_up
      when @config.key_page_down
        page_down
      when @config.key_enter
        open_item(@list[@scroll]?)
      when @config.key_parent
        go_parent
      when @config.key_search
        search_files
      when @config.key_mark
        toggle_mark
      when @config.key_mark_all
        toggle_mark_all
      when @config.key_copy
        copy_files
      when @config.key_move
        move_files
      when @config.key_paste
        paste_files
      when @config.key_delete
        delete_files
      when @config.key_new_dir
        create_directory
      when @config.key_preview
        preview_file
      end
    end

    def scroll_down
      return if @scroll >= @list_total
      @scroll += 1

      # Auto scroll page if cursor goes below visible area
      if @scroll >= @page_offset + @terminal.max_items
        @page_offset += @terminal.max_items
        @page_offset = Math.min(@page_offset, @list.size - @terminal.max_items)
        @page_offset = Math.max(@page_offset, 0)
      end

      redraw
    end

    def scroll_up
      return if @scroll <= 0
      @scroll -= 1

      # Auto scroll page if cursor goes above visible area
      if @scroll < @page_offset
        @page_offset -= @terminal.max_items
        @page_offset = Math.max(@page_offset, 0)
      end

      redraw
    end

    def page_down
      return if @scroll >= @list_total

      @page_offset += @terminal.max_items
      @page_offset = Math.min(@page_offset, @list.size - @terminal.max_items)
      @page_offset = Math.max(@page_offset, 0)

      @scroll = Math.min(@scroll + @terminal.max_items, @list_total)
      redraw
    end

    def page_up
      return if @scroll <= 0

      @page_offset -= @terminal.max_items
      @page_offset = Math.max(@page_offset, 0)

      @scroll = Math.max(@scroll - @terminal.max_items, 0)
      redraw
    end

    def go_parent
      if @current_dir != "/"
        Dir.cd(File.dirname(@current_dir))
        read_directory
        @scroll = 0
        redraw
      end
    end

    def open_item(path : String?)
      return unless path
      if File.directory?(path)
        Dir.cd(path) do
          read_directory
          @scroll = 0
          redraw
        end
      elsif File.file?(path)
        Process.run(@config.opener, [path], output: Process::Redirect::Close, error: Process::Redirect::Close)
      end
    end

    def toggle_mark
      return if @list.empty?
      file_path = @list[@scroll]?
      return unless file_path

      if @marked_files.has_key?(file_path)
        @marked_files.delete(file_path)
      else
        @marked_files[file_path] = file_path
      end

      redraw
    end

    def toggle_mark_all
      if @all_marked
        @marked_files.clear
        @all_marked = false
      else
        @list.each do |file_path|
          @marked_files[file_path] = file_path
        end
        @all_marked = true
      end

      redraw
    end

    def copy_files
      if @marked_files.empty?
        # Copy current file
        current_file = @list[@scroll]?
        return unless current_file
        @clipboard_files = [current_file]
      else
        @clipboard_files = @marked_files.keys.to_a
        @marked_files.clear
        @all_marked = false
      end

      @clipboard_mode = :copy
      redraw
    end

    def move_files
      if @marked_files.empty?
        # Move current file
        current_file = @list[@scroll]?
        return unless current_file
        @clipboard_files = [current_file]
      else
        @clipboard_files = @marked_files.keys.to_a
        @marked_files.clear
        @all_marked = false
      end

      @clipboard_mode = :move
      redraw
    end

    def paste_files
      return if @clipboard_files.empty?

      @clipboard_files.each do |file_path|
        file_name = File.basename(file_path)
        dest_path = File.join(@current_dir, file_name)

        begin
          case @clipboard_mode
          when :copy
            if File.directory?(file_path)
              FileUtils.cp_r(file_path, dest_path)
            else
              FileUtils.cp(file_path, dest_path)
            end
          when :move
            FileUtils.mv(file_path, dest_path)
          end
        rescue e
          # Handle error
        end
      end

      @clipboard_files.clear
      @clipboard_mode = :none
      read_directory
      redraw
    end

    def delete_files
      files_to_delete = if @marked_files.empty?
                          # Delete current file
                          current_file = @list[@scroll]?
                          return unless current_file
                          [current_file]
                        else
                          @marked_files.keys.to_a
                        end

      files_to_delete.each do |file_path|
        begin
          if File.directory?(file_path)
            FileUtils.rm_rf(file_path)
          else
            FileUtils.rm(file_path)
          end
        rescue e
          # Handle error
        end
      end

      @marked_files.clear
      @all_marked = false
      read_directory
      redraw
    end

    def create_directory
      @terminal.move_to(0, @terminal.max_items)
      print Term::Color.truecolor_string("New directory name: ", fore: Term::Color.color(:white))
      @terminal.cursor.move_to(18, @terminal.max_items)

      dir_name = @terminal.read_line("")
      return if dir_name.empty?

      dir_path = File.join(@current_dir, dir_name)

      begin
        Dir.mkdir(dir_path)
        read_directory
        redraw
      rescue e
        # Handle error
      end
    end

    def preview_file
      file_path = @list[@scroll]?
      return unless file_path
      return unless File.file?(file_path)

      # Show preview in a temporary screen
      @terminal.reset

      begin
        # Try to show file info
        file_size = File.size(file_path)
        file_mtime = File.info(file_path).modification_time

        puts "File: #{File.basename(file_path)}"
        puts "Size: #{file_size} bytes"
        puts "Modified: #{file_mtime}"
        puts ""
        puts "--- Preview (first 20 lines) ---"
        puts ""

        # Show first 20 lines for text files
        if file_size < 1024 * 1024 # Only preview files smaller than 1MB
          File.open(file_path) do |file|
            20.times do
              line = file.gets
              break unless line
              puts line
            end
          end
        else
          puts "File too large to preview"
        end
      rescue e
        puts "Error reading file: #{e.message}"
      end

      puts ""
      puts "Press any key to continue..."

      # Wait for keypress
      STDIN.read_char

      # Restore terminal
      @terminal.setup
      redraw
    end

    def search_files
      @terminal.move_to(0, @terminal.max_items)
      print Term::Color.truecolor_string("/", fore: Term::Color.color(:white))
      @terminal.cursor.move_to(1, @terminal.max_items)

      search_term = @terminal.read_line("")
      search_term = search_term.strip

      if search_term.empty?
        read_directory
      else
        @list = Dir.glob(File.join(@current_dir, "*#{search_term}*"))
        @list_total = @list.size - 1
        @scroll = 0
        @page_offset = 0
      end
      redraw
    end

    def quit
      cd_file = @config.cd_file
      File.delete(cd_file) if File.exists?(cd_file)
      if @config.cd_on_exit
        File.write(cd_file, @current_dir)
      end
      @terminal.reset
      exit
    end

    def run
      setup
    end
  end
end

# Entry point
app = FFF::Application.new(ARGV)
app.run