module FFF
  module NavigationHandlers
    def cursor_up
      return if @dir_manager.list.empty?
      @scroll = {@scroll - 1, 0}.max
      adjust_page_offset
    end

    def cursor_down
      return if @dir_manager.list.empty?
      @scroll = {@scroll + 1, @dir_manager.list.size - 1}.min
      adjust_page_offset
    end

    def page_up
      return if @dir_manager.list.empty?
      @scroll = {@scroll - @term.max_items, 0}.max
      adjust_page_offset
    end

    def page_down
      return if @dir_manager.list.empty?
      @scroll = {@scroll + @term.max_items, @dir_manager.list.size - 1}.min
      adjust_page_offset
    end

    def go_top
      return if @dir_manager.list.empty?
      @scroll = 0
      @page_offset = 0
    end

    def go_bottom
      return if @dir_manager.list.empty?
      @scroll = @dir_manager.list.size - 1
      adjust_page_offset
    end

    def adjust_page_offset
      max = @term.max_items
      if @scroll < @page_offset
        @page_offset = @scroll
      elsif @scroll >= @page_offset + max
        @page_offset = @scroll - max + 1
      end
    end

    def go_parent
      begin
        return unless @dir_manager.go_parent

        if child = @prev_child
          idx = @dir_manager.find_child(child)
          @scroll = idx || 0
        end
        @page_offset = 0
      rescue e : Exception
        show_error(e.message)
      end
    end

    def go_home
      begin
        @dir_manager.go_home
        @scroll = 0
        @page_offset = 0
      rescue e : Exception
        show_error(e.message)
      end
    end

    def go_prev
      begin
        old_prev = @prev_dir
        return unless @dir_manager.go_prev(@prev_dir, @prev_child)

        if prev_child = @prev_child
          found_idx = @dir_manager.find_child(prev_child)
          @scroll = found_idx if found_idx
        end
        @prev_dir = old_prev
        @prev_child = nil
        @page_offset = 0
      rescue e : Exception
        show_error(e.message)
      end
    end

    def go_to_dir
      dest = @term.prompt_inline("Go to directory:")

      return if dest.nil? || dest.empty?

      unless File.exists?(dest) && File.directory?(dest)
        show_error("No such directory: #{dest}")
        return
      end

      begin
        Dir.cd(dest)
        @dir_manager.read!
        @scroll = 0
        @page_offset = 0

        @marked = Set(String).new
        @message_bus.clear
        @force_full_redraw = true
      rescue e : Exception
        Dir.cd(@dir_manager.current_dir) rescue nil
        show_error(e.message)
      end
    end

    def go_to_trash
      begin
        trash_dir = @config.trash_dir
        return unless @dir_manager.go_to_trash(trash_dir)
        @scroll = 0
        @page_offset = 0
      rescue e : Exception
        show_error(e.message)
      end
    end

    def jump_to_bookmark(key : String)
      path = @config.favorites[key]?
      return if path.nil?

      return unless File.exists?(path) && File.directory?(path)

      begin
        Dir.cd(path)
        @dir_manager.read!
        @scroll = 0
        @page_offset = 0
      rescue e : Exception
        Dir.cd(@dir_manager.current_dir) rescue nil
        show_error(e.message)
      end
    end
  end
end
