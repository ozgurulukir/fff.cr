require "term-color"
require "./config"

module FFF
  # UIRenderer - Handles all TUI rendering and drawing logic
  class UIRenderer
    @term : Terminal
    @config : Config
    @color_cache : Hash(Tuple(String, Symbol, Int32), Symbol)

    def initialize(@term : Terminal, @config : Config)
      @color_cache = Hash(Tuple(String, Symbol, Int32), Symbol).new
    end

    def redraw(full : Bool, 
               scroll : Int32, 
               page_offset : Int32, 
               list : Array(String),
               marked : Set(String),
               search_mode : Bool,
               search_term : String,
               rename_mode : Bool,
               rename_new_name : String,
               prev_scroll : Int32,
               prev_page_offset : Int32,
               current_dir : String,
               clipboard_mode : Symbol,
               clipboard_size : Int32,
               error_msg : String?,
               loading : Bool)
      @term.refresh_size
      
      if full
        @term.move_to(0, 0)
        print "\e[2J"
        draw_header(search_term, @term.width) if search_mode
        draw_all_lines(list, scroll, page_offset, marked, search_mode, search_term, loading)
      else
        if prev_scroll != scroll || prev_page_offset != page_offset
          old_row = prev_scroll - prev_page_offset
          if old_row >= 0 && old_row < @term.max_items
            @term.move_to(old_row + (search_mode ? 1 : 0), 0)
            draw_line(old_row, prev_scroll, list, marked, scroll, search_mode, search_term) if prev_scroll < list.size
          end
          new_row = scroll - page_offset
          if new_row >= 0 && new_row < @term.max_items && scroll < list.size
            draw_line(new_row, scroll, list, marked, scroll, search_mode, search_term)
          end
        end
      end

      draw_status(scroll, list, current_dir, clipboard_mode, clipboard_size, marked.size, @term.width)
      draw_error(error_msg, @term.width)
      draw_header(search_term, @term.width) if search_mode
      draw_rename_prompt(rename_new_name, @term.width) if rename_mode
      
      if search_mode
        prompt_size = 13 + search_term.size
        @term.move_to(0, prompt_size)
      end
      
      STDOUT.flush
    end

    private def draw_line(row : Int32, idx : Int32, list : Array(String), marked : Set(String), scroll : Int32, search_mode : Bool, search_term : String)
      header_offset = search_mode ? 1 : 0
      actual_row = row + header_offset
      path = list[idx]
      name = File.basename(path)
      selected = (idx == scroll)
      is_marked = marked.includes?(path)
      color = get_file_color(path)
      prefix = is_marked ? " ● " : "   "
      
      @term.move_to(actual_row, 0)
      if selected
        line_text = "#{prefix}#{name}".ljust(@term.width)
        print Term::Color.truecolor_string(line_text, fore: Term::Color.color(:white), back: Term::Color.color(:blue))
      else
        print Term::Color.truecolor_string(prefix, fore: Term::Color.color(is_marked ? :yellow : :white))
        if search_mode && !search_term.empty? && !search_term.starts_with?('!')
          draw_fuzzy_name(name, search_term.downcase, color)
        else
          print Term::Color.truecolor_string(name, fore: Term::Color.color(color))
        end
        print "\e[K"
      end
    end

    private def draw_all_lines(list : Array(String), scroll : Int32, page_offset : Int32, marked : Set(String), search_mode : Bool, search_term : String, loading : Bool)
      if loading
        row = (@term.height / 2).to_i
        @term.move_to(row, (@term.width / 2).to_i - 5)
        print Term::Color.truecolor_string("Loading...", fore: Term::Color.color(:yellow))
        return
      end

      max = @term.max_items
      start_idx = page_offset
      end_idx = {page_offset + max, list.size}.min

      (start_idx...end_idx).each do |i|
        draw_line(i - page_offset, i, list, marked, scroll, search_mode, search_term)
      end

      # Clear remaining lines
      if end_idx - start_idx < max
        ((end_idx - start_idx)...max).each do |i|
          @term.move_to(i + (search_mode ? 1 : 0), 0)
          print "\e[K"
        end
      end
    end

    private def draw_status(scroll : Int32, list : Array(String), current_dir : String, clipboard_mode : Symbol, clipboard_size : Int32, marked_size : Int32, width : Int32)
      @term.move_to(@term.height - 1, 0)
      
      # Current item info
      current = if list.size > 0 && scroll < list.size
        path = list[scroll]
        name = File.basename(path)
        if File.directory?(path)
          "#{name}/"
        elsif File.symlink?(path)
          "#{name}@"
        else
          name
        end
      else
        ""
      end

      # Clipboard status
      clipboard_str = case clipboard_mode
      when :copy then " 📋#{clipboard_size}"
      when :cut  then " ✂️#{clipboard_size}"
      else            ""
      end

      # Marked status
      marked_str = marked_size > 0 ? " ●#{marked_size}" : ""

      # Build status line
      status = "#{current_dir} | #{scroll + 1}/#{list.size} #{current}#{clipboard_str}#{marked_str}"
      status = status.ljust(width)[0...width]
      
      print Term::Color.truecolor_string(status, fore: Term::Color.color(:white), back: Term::Color.color(:blue))
    end

    private def draw_header(search_term : String, width : Int32)
      @term.move_to(0, 0)
      print "\e[K"
      prompt = "Search: #{search_term}_"
      prompt = prompt.ljust(width)[0...width]
      print Term::Color.truecolor_string(prompt, fore: Term::Color.color(:yellow), back: Term::Color.color(:blue))
    end

    private def draw_error(error_msg : String?, width : Int32)
      return if error_msg.nil?
      @term.move_to(@term.height - 2, 0)
      msg = error_msg.to_s.ljust(width)[0...width]
      print Term::Color.truecolor_string(msg, fore: Term::Color.color(:red), back: Term::Color.color(:blue))
    end

    private def draw_fuzzy_name(name : String, query : String, base_color : Symbol)
      query_idx = 0
      name.each_char do |char|
        if query_idx < query.size && char.downcase == query[query_idx]
          print Term::Color.truecolor_string(char.to_s, fore: Term::Color.color(:yellow), back: Term::Color.color(:black))
          query_idx += 1
        else
          print Term::Color.truecolor_string(char.to_s, fore: Term::Color.color(base_color))
        end
      end
    end

    private def draw_rename_prompt(new_name : String, width : Int32)
      @term.move_to(@term.height - 2, 0)
      prompt = "Rename to: #{new_name}_"
      prompt = prompt.ljust(width)[0...width]
      print Term::Color.truecolor_string(prompt, fore: Term::Color.color(:yellow), back: Term::Color.color(:blue))
    end

    private def get_file_color(path : String) : Symbol
      cache_key = {path, :color, @term.width}
      
      if @color_cache.has_key?(cache_key)
        cached = @color_cache[cache_key]
        return cached.is_a?(Symbol) ? cached : :white
      end

      color = if File.directory?(path)
        :blue
      elsif File.info?(path).try(&.permissions.includes?(::File::Permissions::OtherExecute))
        :green
      else
        ext = File.extname(path).downcase
        @config.ls_colors[ext]? || :white
      end

      # Ensure we always return a Symbol
      color = color.is_a?(Symbol) ? color : :white
      @color_cache[cache_key] = color
      color
    rescue
      :white
    end

    def human_size(bytes : Int) : String
      case bytes
      when .<(1024)                then "#{bytes}B"
      when .<(1024 * 1024)         then "#{(bytes / 1024.0).round(1).to_s.rstrip('0').rstrip('.')}K"
      when .<(1024 * 1024 * 1024)  then "#{(bytes / (1024.0 * 1024.0)).round(1).to_s.rstrip('0').rstrip('.')}M"
      else "#{(bytes / (1024.0 * 1024.0 * 1024.0)).round(1).to_s.rstrip('0').rstrip('.')}G"
      end
    end

    def clear_cache
      @color_cache.clear
    end
  end
end
