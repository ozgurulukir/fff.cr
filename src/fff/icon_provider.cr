module FFF
  # IconProvider — Nerd Font file-type icons for TUI display.
  # Enabled via FFF_ICONS=1 env or config.json "icons": true.
  # Falls back to empty strings when disabled (zero-cost).
  module IconProvider
    # Default icons
    DIR_ICON      = "\uF5C1"
    DIR_OPEN_ICON = "\uF5C2"
    FILE_ICON     = "\uF816"
    SYMLINK_ICON  = "\uF481"
    EXEC_ICON     = "\uF116"

    # Extension → Nerd Font icon mapping
    EXTENSION_ICONS = {
      # Crystal / Ruby
      ".cr" => "\uEB75", ".rb" => "\uE791",
      # Python
      ".py" => "\uE73C", ".pyi" => "\uE73C", ".pyc" => "\uE73C",
      # JavaScript / TypeScript
      ".js" => "\uE718", ".mjs" => "\uE718", ".cjs" => "\uE718",
      ".ts" => "\uE628", ".tsx" => "\uE628", ".jsx" => "\uE628",
      # Web
      ".html" => "\uF13B", ".htm" => "\uF13B",
      ".css" => "\uE614", ".scss" => "\uE600", ".sass" => "\uE603", ".less" => "\uE6A6",
      ".vue" => "\uF542", ".svelte" => "\uE68E",
      # Data / Config
      ".json" => "\uE60B", ".yaml" => "\uE6A8", ".yml" => "\uE6A8", ".toml" => "\uE6B2",
      ".xml" => "\uE6A0", ".csv" => "\uE64A",
      # Markdown / Docs
      ".md" => "\uEBB6", ".mdx" => "\uEBB6", ".rst" => "\uEBB6", ".txt" => "\uE612",
      ".pdf" => "\uF1C1", ".doc" => "\uF1C2", ".docx" => "\uF1C2",
      # Shell
      ".sh" => "\uEBD1", ".bash" => "\uEBD1", ".zsh" => "\uEBD1", ".fish" => "\uEBD1",
      ".ps1" => "\uEBD1", ".psm1" => "\uEBD1", ".bat" => "\uE63B", ".cmd" => "\uE63B",
      # C / C++
      ".c" => "\uE608", ".h" => "\uE612",
      ".cpp" => "\uE61D", ".hpp" => "\uE612", ".cc" => "\uE61D", ".hh" => "\uE612",
      # Go
      ".go" => "\uE667",
      # Rust
      ".rs" => "\uE7A8",
      # Java / Kotlin
      ".java" => "\uE7CB", ".kt" => "\uE634", ".kts" => "\uE634",
      ".gradle" => "\uE660",
      # Swift
      ".swift" => "\uE755",
      # PHP
      ".php" => "\uE608",
      # Lua
      ".lua" => "\uE620",
      # Elixir / Erlang
      ".ex" => "\uE6AD", ".exs" => "\uE6AD", ".erl" => "\uE6AD",
      # Haskell
      ".hs" => "\uE65F",
      # Images
      ".png" => "\uE609", ".jpg" => "\uE609", ".jpeg" => "\uE609", ".gif" => "\uE609",
      ".svg" => "\uE609", ".ico" => "\uE609", ".bmp" => "\uE609", ".webp" => "\uE609",
      # Video
      ".mp4" => "\uE9D8", ".mkv" => "\uE9D8", ".avi" => "\uE9D8", ".mov" => "\uE9D8",
      ".webm" => "\uE9D8",
      # Audio
      ".mp3" => "\uE9D8", ".wav" => "\uE9D8", ".flac" => "\uE9D8", ".ogg" => "\uE9D8",
      ".m4a" => "\uE9D8",
      # Archives
      ".zip" => "\uF410", ".tar" => "\uF410", ".gz" => "\uF410", ".bz2" => "\uF410",
      ".xz" => "\uF410", ".7z" => "\uF410", ".rar" => "\uF410", ".zst" => "\uF410",
      # Docker
      ".dockerfile" => "\uF108",
      # Git
      ".gitignore" => "\uE702", ".gitmodules" => "\uE724",
      # Database
      ".sql" => "\uE706", ".db" => "\uE706", ".sqlite" => "\uE706",
      # Binary / Compiled
      ".exe" => "\uE9E4", ".dll" => "\uE9E4", ".so" => "\uE9E4", ".dylib" => "\uE9E4",
      ".o" => "\uE9E4", ".a" => "\uE9E4",
      # Lock files
      ".lock" => "\uE899",
      # Environment
      ".env" => "\uF2DC",
      # Log
      ".log" => "\uE612",
    }

    # Exact filename → icon mapping (overrides extension)
    SPECIAL_NAMES = {
      "Makefile"            => "\uE673",
      "makefile"            => "\uE673",
      "CMakeLists.txt"      => "\uE673",
      "Dockerfile"          => "\uF108",
      "docker-compose.yml"  => "\uF108",
      "docker-compose.yaml" => "\uF108",
      ".gitignore"          => "\uE702",
      ".gitmodules"         => "\uE724",
      ".gitattributes"      => "\uE724",
      "LICENSE"             => "\uF1C1",
      "LICENSE.md"          => "\uF1C1",
      "LICENSE.txt"         => "\uF1C1",
      "README.md"           => "\uEBB6",
      "README"              => "\uEBB6",
      "Gemfile"             => "\uE791",
      "Rakefile"            => "\uE791",
      "Cargo.toml"          => "\uE7A8",
      "Cargo.lock"          => "\uE7A8",
      "go.mod"              => "\uE667",
      "go.sum"              => "\uE667",
      "package.json"        => "\uE718",
      "package-lock.json"   => "\uE718",
      "tsconfig.json"       => "\uE628",
      "webpack.config.js"   => "\uE718",
      "vite.config.ts"      => "\uE628",
      "vite.config.js"      => "\uE718",
      ".eslintrc"           => "\uE60E",
      ".eslintrc.json"      => "\uE60B",
      ".prettierrc"         => "\uE60B",
      "shard.yml"           => "\uEB75",
      "shard.lock"          => "\uEB75",
      ".editorconfig"       => "\uE612",
      ".env"                => "\uF2DC",
      ".env.local"          => "\uF2DC",
      "Procfile"            => "\uE612",
      "Vagrantfile"         => "\uE612",
    }

    # Get the appropriate icon for a file path
    def self.icon_for(path : String, info : File::Info?, linfo : File::Info?) : String
      name = File.basename(path)

      if icon = SPECIAL_NAMES[name]?
        return icon
      end

      if info && info.directory?
        return DIR_ICON
      end

      if linfo && linfo.symlink?
        return SYMLINK_ICON
      end

      # Executable check
      if info && !info.directory?
        {% unless flag?(:windows) %}
          if ::File::Info.executable?(path)
            return EXEC_ICON
          end
        {% end %}
      end

      # Extension-based lookup
      ext = File.extname(name).downcase
      EXTENSION_ICONS[ext]? || FILE_ICON
    end
  end
end
