require "spec"

# Spec helper for FFF (Fucking Fast File Manager)
module SpecHelper
  extend self

  # Create a temporary directory for testing
  def create_temp_dir(name = "temp_test_dir")
    temp_dir = File.join(Dir.tempdir, name)
    Dir.mkdir_p(temp_dir)
    temp_dir
  end

  # Create a temporary file with content
  def create_temp_file(dir, filename, content = "test content")
    file_path = File.join(dir, filename)
    File.write(file_path, content)
    file_path
  end

  # Create a temporary directory structure
  def create_test_structure(base_dir)
    # Create some files
    create_temp_file(base_dir, "file1.txt", "Content of file 1")
    create_temp_file(base_dir, "file2.txt", "Content of file 2")
    create_temp_file(base_dir, "script.sh", "#!/bin/bash\necho 'hello'")

    # Create subdirectories
    subdir1 = File.join(base_dir, "subdir1")
    subdir2 = File.join(base_dir, "subdir2")
    Dir.mkdir_p(subdir1)
    Dir.mkdir_p(subdir2)

    # Create files in subdirectories
    create_temp_file(subdir1, "nested_file1.txt", "Nested content 1")
    create_temp_file(subdir2, "nested_file2.txt", "Nested content 2")

    # Create a hidden file
    create_temp_file(base_dir, ".hidden_file", "Hidden content")

    # Create a symlink
    symlink_path = File.join(base_dir, "symlink_to_file1")
    File.symlink("file1.txt", symlink_path) if File.exists?(File.join(base_dir, "file1.txt"))

    {base_dir, subdir1, subdir2}
  end

  # Clean up temporary directories
  def cleanup_temp_dir(dir)
    if Dir.exists?(dir)
      # Change out of the directory if it's the current working directory
      curr = Dir.current.downcase
      target = dir.downcase
      if curr == target || curr.starts_with?(target + File::SEPARATOR) || curr.starts_with?(target + "/")
        Dir.cd(Dir.tempdir)
      end
      # Normalize glob pattern for Windows
      glob_pattern = File.join(dir, "**/*").gsub('\\', '/')
      items = Dir.glob(glob_pattern).sort_by { |f| -f.size }
      items.each do |file|
        if File.directory?(file)
          Dir.delete(file) rescue nil
        else
          File.delete(file) rescue nil
        end
      end
      Dir.delete(dir) rescue nil
    end
  end

  # Clean up temporary files
  def cleanup_temp_file(file_path)
    if File.exists?(file_path)
      File.delete(file_path)
    end
  end

  # Mock LS_COLORS for testing
  def mock_ls_colors(colors = nil, &block)
    if colors
      color_string = colors.map do |pattern, color|
        "#{pattern}=#{color}"
      end.join(":")
    else
      color_string = ""
    end

    # If block is given, mock and restore
    if block
      original_ls_colors = ENV["LS_COLORS"]?

      ENV["LS_COLORS"] = color_string
      yield

      # Restore original value
      if original_ls_colors
        ENV["LS_COLORS"] = original_ls_colors
      else
        ENV.delete("LS_COLORS")
      end
    else
      ENV["LS_COLORS"] = color_string
    end

    color_string
  end

  # Mock environment variables for testing
  def mock_env_vars(vars : Hash(String, String), &)
    original_vars = {} of String => String?

    vars.each do |key, value|
      original_vars[key] = ENV[key]?
      ENV[key] = value
    end

    # Yield for the test
    yield

    # Restore original values
    original_vars.each do |key, original_value|
      if original_value
        ENV[key] = original_value
      else
        ENV.delete(key)
      end
    end
  end

  # Create a mock terminal for testing UI components
  def create_mock_terminal(width = 80, height = 24)
    mock_screen = MockTermScreen.new(width, height)
    mock_cursor = MockTermCursor.new
    mock_color = MockTermColor.new

    Term::Screen.new(width, height)
  end

  # Mock terminal classes for testing
  private class MockTermScreen
    property width : Int32
    property height : Int32

    def initialize(@width, @height)
    end

    def width
      @width
    end

    def height
      @height
    end
  end

  private class MockTermCursor
    def hide
      "\e[?25l"
    end

    def show
      "\e[?25h"
    end

    def move_to(row, col)
      "\e[#{row};#{col}H"
    end
  end

  private class MockTermColor
    def color(fore : Symbol, back : Symbol)
      # Return ANSI color codes
      fore_code = case fore
                  when :black   then "30"
                  when :red     then "31"
                  when :green   then "32"
                  when :yellow  then "33"
                  when :blue    then "34"
                  when :magenta then "35"
                  when :cyan    then "36"
                  when :white   then "37"
                  else               "0"
                  end

      back_code = case back
                  when :black   then "40"
                  when :red     then "41"
                  when :green   then "42"
                  when :yellow  then "43"
                  when :blue    then "44"
                  when :magenta then "45"
                  when :cyan    then "46"
                  when :white   then "47"
                  else               "0"
                  end

      "\e[#{fore_code};#{back_code}m"
    end

    def truecolor_string(text, fore : String, back : String)
      # Convert named colors to RGB if needed, for testing just return normal text
      text
    end
  end
end
