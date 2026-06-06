require "./theme"

module FFF
  # ProgressBar — Visual progress indicator for file operations.
  # Shows a bar with percentage, file count, and current filename.
  # Drawn on the second-to-last terminal row (same position as messages).
  struct ProgressBar
    getter current : Int32
    getter total : Int32
    getter current_name : String
    getter operation : String

    def initialize(@operation : String = "Processing", @total : Int32 = 0)
      @current = 0
      @current_name = ""
    end

    # Update progress state
    def update(@current : Int32, @current_name : String)
    end

    # Calculate percentage
    def percentage : Int32
      return 0 if @total <= 0
      ((@current * 100) / @total).clamp(0, 100).to_i
    end

    # Draw the progress bar on terminal
    def draw(term_width : Int32, term_height : Int32, theme : Theme)
      row = term_height - 2
      print "\e[#{row + 1};1H\e[K"

      pct = percentage
      bar_max = {term_width / 3, 20}.min.to_i
      filled = ((bar_max * pct) / 100).to_i
      empty = (bar_max - filled).to_i

      bar = String.build do |s|
        s << Theme.set_fg(theme.progress_fill)
        filled.times { s << "█" }
        s << Theme.set_fg(theme.progress_empty)
        empty.times { s << "░" }
        s << Theme.reset
      end

      name = File.basename(@current_name)
      info = "  #{@operation} #{@current}/#{@total} (#{pct}%)  #{name}"
      max_info = term_width - bar_max - 2
      info = info[0...max_info] if info.size > max_info

      line = String.build do |s|
        s << " " << bar << Theme.fg(info, theme.fg)
      end

      print line
      STDOUT.flush
    end
  end
end
