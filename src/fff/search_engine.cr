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
      # İçerik eşleşmesi
      return 200 if text.includes?(query)

      # Bulanık (fuzzy) eşleşme skorlama
      text_idx = 0
      query_idx = 0
      score = 100

      while text_idx < text.size && query_idx < query.size
        if text[text_idx] == query[query_idx]
          score += 10
          query_idx += 1
        else
          score -= 1
        end
        text_idx += 1
      end

      query_idx == query.size ? Math.max(score, 1) : 0
    end

    # Ripgrep entegrasyonu - Dosya içeriğinde arama yapar
    # Runs rg in a fiber with a 2-second timeout so the TUI never freezes.
    def self.content_search(query : String, dir : String) : Array(String)
      return [] of String if query.size < 2

      proc_chan = Channel(Process).new(1)
      result_chan = Channel(IO::Memory).new(1)
      timeout_chan = Channel(Nil).new(1)
      output_io = IO::Memory.new
      error_io = IO::Memory.new
      pipe_rd, pipe_wr = IO.pipe
      pipe_err_rd, pipe_err_wr = IO.pipe

      spawn do
        the_proc = Process.new(
          "rg", ["-l", "--max-count", "1", query, dir],
          output: pipe_wr, error: pipe_err_wr
        )
        pipe_wr.close
        pipe_err_wr.close
        proc_chan.send(the_proc)

        output_io << pipe_rd.gets_to_end
        error_io << pipe_err_rd.gets_to_end

        result_chan.send(output_io)
      rescue
        result_chan.send(output_io)
      end

      spawn do
        sleep 2.seconds
        the_proc = proc_chan.receive
        Process.signal(Signal::TERM, the_proc.pid) rescue nil
        pipe_rd.close rescue nil
        pipe_err_rd.close rescue nil
        the_proc.wait rescue nil
        timeout_chan.send(nil)
      end

      select
      when output = result_chan.receive
        timeout_chan.receive rescue nil
        rg_text = output.to_s
        rg_results = rg_text.strip.split("\n").reject(&.empty?)
        return [] of String if rg_results.empty?
        rg_results.map { |path| Path.new(path).absolute? ? path : ::File.join(dir, path) }
      when ignored = timeout_chan.receive
        [] of String
      end
    rescue
      [] of String
    end
  end
end
