require "file"
require "file_utils"
require "process"
require "signal"
require "./terminal"
require "./config"
require "./directory_manager"
require "./ui_renderer"
require "./input_mode"
require "./file_operations"
require "./search_engine"

module FFF
  # FileManager - Core TUI file manager coordinator
  class FileManager
    @term : Terminal
    @config : Config
    @dir_manager : DirectoryManager
    @renderer : UIRenderer
    @input_mode : InputMode
    @file_ops : FileOperations
    
    @scroll : Int32
    @page_offset : Int32
    @marked : Set(String)
    @clipboard : Array(String)
    @clipboard_mode : Symbol
    @running : Bool
    @prev_dir : String?
    @prev_child : String?
    @error_msg : String?
    @error_expires : Time?
    @prev_scroll : Int32
    @prev_page_offset : Int32
    @fff_level : Int32
    @picker_mode : Bool
    @loading : Bool

    def initialize(@config : Config, start_dir : String, @picker_mode = false)
      @term = Terminal.new
      @dir_manager = DirectoryManager.new(start_dir)
      @renderer = UIRenderer.new(@term, @config)
      @input_mode = InputMode.new(@term)
      @file_ops = FileOperations.new(@config, @term)
      
      @scroll = 0
      @page_offset = 0
      @marked = Set(String).new
      @clipboard = [] of String
      @clipboard_mode = :none
      @running = true
      @prev_dir = nil
      @prev_child = nil
      @error_msg = nil
      @error_expires = nil
      @prev_scroll = -1
      @prev_page_offset = -1
      @fff_level = (ENV["FFF_LEVEL"]?.try(&.to_i) || 0)
      @loading = false
    end

    def run
      Signal::INT.trap { quit }
      Signal::TERM.trap { quit }
      Signal::QUIT.trap { quit }
      Signal::WINCH.trap { handle_resize }

      at_exit { @term.leave_tui if @running }
      ENV["FFF_LEVEL"] = @fff_level.to_s

      ensure_dirs
      @term.enter_tui
      @dir_manager.read!
      event_loop
    rescue e : Exception
      @term.leave_tui
      STDERR.puts "fff error: #{e.message}"
      if ENV["FFF_DEBUG"]? == "1"
        STDERR.puts e.backtrace.join("\n")
      end
    end

    private def ensure_dirs
      FileUtils.mkdir_p(File.join(ENV["HOME"], ".cache", "fff")) if @config.cd_on_exit
    end

    private def handle_resize
      @term.refresh_size
      max = @term.max_items
      @scroll = {@scroll, @dir_manager.list.size - 1}.min if @dir_manager.list.size > 0
      @page_offset = {@page_offset, {@scroll - max + 1, 0}.max}.min if @scroll >= @page_offset + max
      redraw(true)
    end

    private def redraw(full = false)
      check_error_expiry
      
      @renderer.redraw(
        full,
        @scroll,
        @page_offset,
        @dir_manager.list,
        @marked,
        @input_mode.active,
        @input_mode.text,
        @input_mode.mode == :rename,
        @input_mode.text,
        @prev_scroll,
        @prev_page_offset,
        @dir_manager.current_dir,
        @clipboard_mode,
        @clipboard.size,
        @error_msg,
        @loading
      )

      @prev_scroll = @scroll
      @prev_page_offset = @page_offset
    end

    private def check_error_expiry
      if expires = @error_expires
        if Time.utc > expires
          @error_msg = nil
          @error_expires = nil
        end
      end
    end

    private def event_loop
      while @running
        redraw
        
        key = @term.read_keypress
        break if key.nil?

        if @input_mode.active
          handle_input_mode(key)
        else
          handle_key(key)
        end
      end

      @term.leave_tui
      save_cd_on_exit if @config.cd_on_exit && !@picker_mode
      write_picker_file if @picker_mode
    end

    private def handle_input_mode(key : String)
      complete = @input_mode.handle_key(key)

      if complete
        if @input_mode.mode == :search
          if key == "\e"  # ESC - restore original
            @dir_manager.list = @input_mode.original_list.dup
            @input_mode.end(true)
          else  # Enter - keep filtered
            @dir_manager.list = @input_mode.apply_search(@dir_manager.list)
            @input_mode.end(false)
          end
        elsif @input_mode.mode == :rename
          if @scroll < @dir_manager.list.size
            old_path = @dir_manager.list[@scroll]
            error = @input_mode.apply_rename(old_path)
            show_error(error) if error
            @dir_manager.read!
          end
          @input_mode.end
        end
      else
        # Live search update
        if @input_mode.mode == :search
          @dir_manager.list = @input_mode.apply_search(@input_mode.original_list)
        end
      end
    end

    private def handle_key(key : String)
      key = @config.key_bindings[key] || key

      case key
      when "j", "\e[B"     then cursor_down
      when "k", "\e[A"     then cursor_up
      when "h", "\e[D"     then go_parent
      when "l", "\e[C"     then enter_item
      when "G"             then go_bottom
      when "g"             then go_top
      when " "             then toggle_mark
      when "m"             then toggle_mark_all
      when "y"             then yank_files
      when "v"             then cut_files
      when "p"             then paste_files
      when "d"             then delete_files
      when "n"             then new_directory
      when "f"             then new_file
      when "r"             then start_rename
      when "b"             then bulk_rename
      when "i"             then preview_file
      when "s"             then spawn_shell
      when "/"             then start_search
      when "."             then @dir_manager.toggle_hidden
      when "t"             then go_to_trash
      when "x"             then show_attributes
      when "X"             then toggle_executable
      when ":"             then go_to_dir
      when "~"             then @dir_manager.go_home
      when "-"             then go_prev
      when "e"             then @dir_manager.refresh!
      when "S"             then create_symlink
      when "="             then @dir_manager.cycle_sort_mode
      when "+"             then @dir_manager.toggle_sort_reverse
      when "q"             then quit
      when "1", "2", "3", "4", "5", "6", "7", "8", "9"
        jump_to_bookmark(key)
      end
    end

    private def start_search
      @input_mode.start_search(@dir_manager.list)
    end

    private def start_rename
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size
      
      old_path = @dir_manager.list[@scroll]
      old_name = File.basename(old_path)
      @input_mode.start_rename(old_name)
    end

    private def cursor_up
      return if @dir_manager.list.empty?
      @scroll = {@scroll - 1, 0}.max
      adjust_page_offset
    end

    private def cursor_down
      return if @dir_manager.list.empty?
      @scroll = {@scroll + 1, @dir_manager.list.size - 1}.min
      adjust_page_offset
    end

    private def go_top
      return if @dir_manager.list.empty?
      @scroll = 0
      @page_offset = 0
    end

    private def go_bottom
      return if @dir_manager.list.empty?
      @scroll = @dir_manager.list.size - 1
      adjust_page_offset
    end

    private def adjust_page_offset
      max = @term.max_items
      if @scroll < @page_offset
        @page_offset = @scroll
      elsif @scroll >= @page_offset + max
        @page_offset = @scroll - max + 1
      end
    end

    private def enter_item
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      
      if File.directory?(path)
        @prev_dir = @dir_manager.current_dir
        @prev_child = File.basename(path)
        Dir.cd(path)
        @dir_manager.read!
        @scroll = 0
        @page_offset = 0
      elsif text_file?(path)
        open_in_editor(path)
      else
        show_error("Not a text file: #{File.basename(path)}")
      end
    end

    private def text_file?(path : String) : Bool
      return false if File.directory?(path) || File.symlink?(path)
      
      ext = File.extname(path).downcase
      text_exts = [".txt", ".cr", ".sh", ".py", ".js", ".ts", ".json", ".yaml", ".yml", 
                   ".md", ".html", ".css", ".xml", ".rb", ".go", ".rs", ".c", ".h", 
                   ".cpp", ".hpp", ".java", ".php", ".swift", ".kt"]
      
      text_exts.includes?(ext) || `file --mime-type "#{path}" 2>/dev/null`.includes?("text/")
    end

    private def open_in_editor(path : String)
      @term.leave_tui
      system("#{@config.editor} \"#{path}\"")
      @term.enter_tui
    end

    private def go_parent
      return unless @dir_manager.go_parent
      
      # Try to restore previous position
      if @prev_child
        idx = @prev_child ? @dir_manager.find_child(@prev_child.not_nil!) : nil
        @scroll = idx || 0
        @page_offset = 0
      end
    end

    private def go_home
      @dir_manager.go_home
      @scroll = 0
      @page_offset = 0
    end

    private def go_prev
      return unless @dir_manager.go_prev(@prev_dir, @prev_child)
      
      if @prev_child
        found_idx = @dir_manager.find_child(@prev_child.not_nil!)
        @scroll = found_idx if found_idx
      end
      @page_offset = 0
    end

    private def go_to_dir
      @term.leave_tui
      dest = @term.ask("Go to directory: ")
      @term.enter_tui
      
      return if dest.nil? || dest.empty?
      
      unless File.exists?(dest) && File.directory?(dest)
        show_error("No such directory: #{dest}")
        return
      end
      
      Dir.cd(dest)
      @dir_manager.read!
      @scroll = 0
      @page_offset = 0
    end

    private def go_to_trash
      trash_dir = File.join(ENV["HOME"], ".local", "share", "fff", "trash")
      return unless @dir_manager.go_to_trash(trash_dir)
      @scroll = 0
      @page_offset = 0
    end

    private def new_file
      @term.leave_tui
      name = @term.ask("New file name: ")
      @term.enter_tui
      
      return if name.nil? || name.empty?
      
      error = @file_ops.new_file(@dir_manager.current_dir, name)
      show_error(error) if error
      @dir_manager.read!
    end

    private def new_directory
      @term.leave_tui
      name = @term.ask("New directory name: ")
      @term.enter_tui
      
      return if name.nil? || name.empty?
      
      error = @file_ops.new_directory(@dir_manager.current_dir, name)
      show_error(error) if error
      @dir_manager.read!
    end

    private def rename_item
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size
      
      old_path = @dir_manager.list[@scroll]
      old_name = File.basename(old_path)
      @term.leave_tui
      new_name = @term.ask("Rename to: ", old_name)
      @term.enter_tui
      
      return if new_name.nil? || new_name == old_name
      
      dir = File.dirname(old_path)
      new_path = File.join(dir, new_name)
      
      if File.exists?(new_path)
        show_error("Target exists: #{new_name}")
        return
      end
      
      begin
        FileUtils.mv(old_path, new_path)
        @dir_manager.read!
      rescue e : Exception
        show_error(e.message)
      end
    end

    private def bulk_rename
      sources = marked_or_current
      @term.leave_tui
      error = @file_ops.bulk_rename(sources, @config.editor)
      @term.enter_tui
      
      show_error(error) if error
      @marked.clear
      @dir_manager.read!
    end

    private def create_symlink
      sources = marked_or_current
      error = @file_ops.create_symlink(sources, @dir_manager.current_dir)
      
      show_error(error) if error
      @marked.clear
      @dir_manager.read!
    end

    private def toggle_mark
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      if @marked.includes?(path)
        @marked.delete(path)
      else
        @marked.add(path)
      end
    end

    private def toggle_mark_all
      if @marked.size == @dir_manager.list.size
        @marked.clear
      else
        @dir_manager.list.each { |path| @marked.add(path) }
      end
    end

    private def marked_or_current : Array(String)
      return @marked.to_a if @marked.size > 0
      return [] of String if @dir_manager.list.empty?
      return [] of String if @scroll >= @dir_manager.list.size
      [@dir_manager.list[@scroll]]
    end

    private def yank_files
      @clipboard = marked_or_current
      @clipboard_mode = :copy if @clipboard.size > 0
    end

    private def cut_files
      @clipboard = marked_or_current
      @clipboard_mode = :cut if @clipboard.size > 0
    end

    private def paste_files
      return if @clipboard.empty?
      
      error = @file_ops.paste_files(@clipboard, @dir_manager.current_dir, @clipboard_mode)
      show_error(error) if error
      
      @marked.clear
      @dir_manager.read!
    end

    private def delete_files
      sources = marked_or_current
      return if sources.empty?
      
      trash_dir = File.join(ENV["HOME"], ".local", "share", "fff", "trash")
      
      @term.leave_tui
      confirm = @term.confirm?("Delete #{sources.size} item(s)? ")
      @term.enter_tui
      
      return unless confirm
      
      error = @file_ops.delete_files(sources, trash_dir)
      show_error(error) if error
      
      @marked.clear
      @dir_manager.read!
    end

    private def show_attributes
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      result = @file_ops.show_attributes(path)
      
      @term.leave_tui
      puts result
      @term.keypress("Press any key to continue...")
      @term.enter_tui
    end

    private def toggle_executable
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      error = @file_ops.toggle_executable(path)
      show_error(error) if error
    end

    private def jump_to_bookmark(key : String)
      idx = key.to_i - 1
      path = @config.bookmarks[idx]?
      return if path.nil?
      
      return unless File.exists?(path) && File.directory?(path)
      
      Dir.cd(path)
      @dir_manager.read!
      @scroll = 0
      @page_offset = 0
    end

    private def preview_file
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      
      unless File.exists?(path)
        show_error("File not found: #{File.basename(path)}")
        return
      end
      
      @term.leave_tui
      if File.directory?(path)
        puts "Directory: #{File.basename(path)}"
        puts "Contents:"
        Dir.entries(path).each { |e| puts "  #{e}" }
      else
        size = @renderer.human_size(File.info(path).size) rescue "???"
        puts "File: #{File.basename(path)}"
        puts "Size: #{size}"
        puts "---"
        if text_file?(path)
      line_number = 0
      File.each_line(path) do |line|
        break if line_number >= 50
        puts line
        line_number += 1
      end
      line_number = 0
        else
          puts "Binary file"
        end
      end
      @term.keypress("Press any key to continue...")
      @term.enter_tui
    end

    private def spawn_shell
      @fff_level += 1
      ENV["FFF_LEVEL"] = @fff_level.to_s
      
      @term.leave_tui
      system(ENV["SHELL"] || "bash")
      @term.enter_tui
      
      @fff_level -= 1
      ENV["FFF_LEVEL"] = @fff_level.to_s
      @dir_manager.read!
    end

    private def quit
      @running = false
    end

    private def save_cd_on_exit
      last_file = File.join(ENV["HOME"], ".cache", "fff", "opened_file")
      File.write(last_file, @dir_manager.current_dir)
    end

    private def write_picker_file
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      last_file = File.join(ENV["HOME"], ".cache", "fff", "opened_file")
      File.write(last_file, @dir_manager.list[@scroll])
    end

    private def show_error(message : String?)
      return if message.nil? || message.empty?
      
      @error_msg = message
      @error_expires = Time.utc + 2.seconds
    end
  end
end
