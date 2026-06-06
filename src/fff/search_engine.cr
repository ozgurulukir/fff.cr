module FFF
  # SearchEngine - Logic for fuzzy matching and external search tools (ripgrep)
  class SearchEngine
    # Performs fuzzy matching on a list of paths based on filename
    def self.fuzzy_match(list : Array(String), query : String) : Array(String)
      return list if query.empty?

      matches = [] of {String, Int32}
      list.each do |path|
        name = File.basename(path).downcase
        score = fuzzy_score(name, query.downcase)
        matches << {path, score} if score > 0
      end

      matches.sort_by { |m| {-m[1], m[0]} }.map { |m| m[0] }
    end

    # Puanlama mantığı
    def self.fuzzy_score(text : String, query : String) : Int32
      return 100 if query.empty?
      return 0 if query.size > text.size

      # Kesin eşleşme
      return 1000 if text == query
      # Başlangıç eşleşmesi
      return 500 if text.starts_with?(query)

      # Bulanık (fuzzy) eşleşme skorlama
      text_idx = 0
      query_idx = 0
      score = 100
      consecutive = 0

      while text_idx < text.size && query_idx < query.size
        if text[text_idx] == query[query_idx]
          score += 10
          score += consecutive * 5
          consecutive += 1
          query_idx += 1
        else
          score -= 1
          consecutive = 0
        end
        text_idx += 1
      end

      score += 50 if text.includes?(query)

      query_idx == query.size ? Math.max(score, 1) : 0
    end

    # Recursive path search — scans directory tree with fuzzy matching
    # Triggered by `>` prefix in search mode
    def self.recursive_search(query : String, dir : String, max_results : Int32 = 200) : Array(String)
      return [] of String if query.size < 1

      matches = [] of {String, Int32}
      query_lower = query.downcase

      scan_recursive(dir, query_lower, matches, max_results, 0, 5)

      matches.sort_by { |m| {-m[1], m[0]} }.map { |m| m[0] }.first(max_results)
    rescue
      [] of String
    end

    private def self.scan_recursive(dir : String, query : String, matches : Array({String, Int32}),
                                     max_results : Int32, depth : Int32, max_depth : Int32)
      return if depth > max_depth
      return if matches.size >= max_results

      begin
        Dir.entries(dir).each do |entry|
          next if entry == "." || entry == ".."
          next if entry.starts_with?('.')

          path = File.join(dir, entry)
          name = entry.downcase
          score = fuzzy_score(name, query)
          matches << {path, score} if score > 0

          if File.directory?(path) && matches.size < max_results
            scan_recursive(path, query, matches, max_results, depth + 1, max_depth)
          end
        end
      rescue
        # Permission denied or other I/O error — skip this directory
      end
    end

    # Ripgrep entegrasyonu - Dosya içeriğinde arama yapar
    # Runs rg in a fiber with a 2-second timeout so the TUI never freezes.
    def self.content_search(query : String, dir : String) : Array(String)
      return [] of String if query.size < 2

      proc_chan = Channel(Process?).new(1)
      result_chan = Channel(IO::Memory).new(1)
      timeout_chan = Channel(Nil).new(1)

      pipe_rd, pipe_wr = IO.pipe
      pipe_err_rd, pipe_err_wr = IO.pipe

      spawn_ripgrep(query, dir, proc_chan, result_chan, pipe_rd, pipe_wr, pipe_err_rd, pipe_err_wr)
      spawn_timeout(proc_chan, timeout_chan, pipe_rd, pipe_err_rd)

      parse_rg_output(result_chan, timeout_chan, dir)
    rescue
      [] of String
    end

    private def self.spawn_ripgrep(query, dir, proc_chan, result_chan, pipe_rd, pipe_wr, pipe_err_rd, pipe_err_wr)
      output_io = IO::Memory.new
      error_io = IO::Memory.new

      spawn do
        _the_proc = begin
          p = Process.new(
            "rg", ["-l", "--max-count", "1", query, dir],
            output: pipe_wr, error: pipe_err_wr
          )
          pipe_wr.close
          pipe_err_wr.close
          proc_chan.send(p)
          p
        rescue
          nil
        end

        output_io << pipe_rd.gets_to_end
        error_io << pipe_err_rd.gets_to_end

        result_chan.send(output_io)
      rescue
        result_chan.send(output_io)
      end
    end

    private def self.spawn_timeout(proc_chan, timeout_chan, pipe_rd, pipe_err_rd)
      spawn do
        sleep 2.seconds
        the_proc = proc_chan.receive
        if the_proc
          {% if flag?(:windows) %}
            the_proc.terminate rescue nil
          {% else %}
            Process.signal(Signal::TERM, the_proc.pid) rescue nil
          {% end %}
          pipe_rd.close rescue nil
          pipe_err_rd.close rescue nil
          the_proc.wait rescue nil
        end
        timeout_chan.send(nil)
      end
    end

    private def self.parse_rg_output(result_chan, timeout_chan, dir) : Array(String)
      select
      when output = result_chan.receive
        rg_text = output.to_s
        rg_results = rg_text.strip.split("\n").reject(&.empty?)
        return [] of String if rg_results.empty?
        rg_results.map { |path| Path.new(path).absolute? ? path : ::File.join(dir, path) }
      when _ignored = timeout_chan.receive
        [] of String
      end
    end
  end
end
