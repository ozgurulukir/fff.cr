require "time"

module FFF
  # FormatUtils — Shared formatting helpers used across modules
  HOME = ENV["HOME"]? || begin
    Path.home.to_s
  rescue
    File.join(Dir.tempdir, "fff-#{Random::Secure.hex(16)}")
  end

  module FormatUtils
    def self.human_size(bytes : Int) : String
      human_size_i64(bytes.to_i64)
    end

    def self.human_size(bytes : Int64) : String
      human_size_i64(bytes)
    end

    private def self.human_size_i64(bytes : Int64) : String
      case bytes
      when .<(1024_i64)
        "#{bytes}B"
      when .<(1024_i64 * 1024_i64)
        "#{(bytes / 1024.0).round(1).to_s.rstrip('0').rstrip('.')}K"
      when .<(1024_i64 * 1024_i64 * 1024_i64)
        "#{(bytes / (1024.0 * 1024.0)).round(1).to_s.rstrip('0').rstrip('.')}M"
      else
        "#{(bytes / (1024.0 * 1024.0 * 1024.0)).round(1).to_s.rstrip('0').rstrip('.')}G"
      end
    end

    # Format modification time for column display
    def self.format_time(time : Time) : String
      now = Time.local
      local_time = time.to_local
      if local_time.year == now.year
        local_time.to_s("%b %d")
      else
        local_time.to_s("%b %y")
      end
    rescue
      "      "
    end

    # Format modification time with hours for detailed view
    def self.format_time_detailed(time : Time) : String
      time.to_local.to_s("%b %d %H:%M")
    rescue
      ""
    end
  end
end
