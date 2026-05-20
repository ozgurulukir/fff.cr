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
    def self.content_search(query : String, dir : String) : Array(String)
      return [] of String if query.size < 2

      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run(
        "rg",
        ["-l", "--max-count", "1", query, dir],
        output: output,
        error: error
      )

      return [] of String unless status.success?

      output.to_s.strip.split("\n").reject(&.empty?)
    rescue
      [] of String
    end
  end
end
