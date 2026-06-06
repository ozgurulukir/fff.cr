module FFF
  module ViewHandlers
    def preview_file
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]

      unless File.exists?(path)
        show_error("File not found: #{File.basename(path)}")
        return
      end

      if File.directory?(path)
        builtin_preview(path)
      else
        external_preview(path) || builtin_preview(path)
      end
    end

    def external_preview(path : String) : Bool
      if bat = Process.find_executable("bat")
        with_tui_restored { Process.run(bat, ["--paging=always", path], input: STDIN, output: STDOUT, error: STDERR) }
        true
      elsif less = Process.find_executable("less")
        with_tui_restored { Process.run(less, [path], input: STDIN, output: STDOUT, error: STDERR) }
        true
      else
        false
      end
    end

    def builtin_preview(path : String)
      @term.leave_tui
      if File.directory?(path)
        puts "Directory: #{File.basename(path)}"
        puts "Contents:"
        Dir.entries(path).each { |e| puts "  #{e}" }
      else
        size = FormatUtils.human_size(File.info(path).size) rescue "???"
        puts "File: #{File.basename(path)}"
        puts "Size: #{size}"
        puts "---"
        if text_file?(path)
          line_count = 0
          File.each_line(path) do |line|
            break if line_count >= 50
            puts line
            line_count += 1
          end
        else
          puts "Binary file"
        end
      end
      print "Press any key to continue..."
      STDOUT.flush
      STDIN.raw(&.read_char) if STDIN.tty?
      print "\n"
      STDOUT.flush
      @term.enter_tui
      @force_full_redraw = true
    end

    def show_attributes
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      result = @file_ops.show_attributes(path)

      @term.leave_tui
      puts result
      print "Press any key to continue..."
      STDOUT.flush
      STDIN.raw(&.read_char) if STDIN.tty?
      print "\n"
      STDOUT.flush
      @term.enter_tui
      @force_full_redraw = true
    end

    def spawn_shell
      @fff_level += 1
      ENV["FFF_LEVEL"] = @fff_level.to_s

      with_tui_restored { Process.run(ENV["SHELL"]? || "bash", input: STDIN, output: STDOUT, error: STDERR) }

      @fff_level -= 1
      ENV["FFF_LEVEL"] = @fff_level.to_s
      @dir_manager.read!
    end
  end
end
