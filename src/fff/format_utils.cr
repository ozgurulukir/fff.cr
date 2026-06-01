require "random/secure"

module FFF
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
  end
end
