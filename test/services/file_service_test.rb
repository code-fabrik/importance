require_relative "../test_helper"
require 'ostruct'

class Importance::FileServiceTest < Minitest::Test
  def setup 
    @tempfile = Tempfile.new(['test_upload', '.txt'])
    @tempfile.write("Test content")
    @tempfile.rewind
    @original_tempfile_path = @tempfile.path

    @mock_upload = OpenStruct.new(
      tempfile: @tempfile,
      original_filename: 'my_document.txt'
    )

    @persisted_files = []
  end

  def teardown
    @tempfile.close!

    @persisted_files.each do |path|
      FileUtils.rm_f(path)
    end
  end

  def test_store_saves_file_to_tmp_dir_with_uuid_and_returns_path
    @service = Importance::FileService.new(:students, @mock_upload)
    persisted_path = @service.store
    @persisted_files << persisted_path

    assert_instance_of String, persisted_path
    assert File.exist?(persisted_path), "Persisted file should exist at #{persisted_path}"

    assert_match(/^#{Regexp.escape(Dir.tmpdir)}/, persisted_path, "Path should be within system temp directory")

    assert_equal '.txt', File.extname(persisted_path)

    filename = File.basename(persisted_path, '.txt')
    assert_match(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/, filename, "Filename should be a UUID")

    refute File.exist?(@original_tempfile_path), "Original tempfile should have been moved"

    assert_equal "Test content", File.read(persisted_path)
  end

  def test_store_handles_different_extensions
    tempfile_png = Tempfile.new(['image_upload', '.png'])
    tempfile_png.write("PNG data")
    tempfile_png.rewind
    original_png_path = tempfile_png.path

    mock_upload_png = OpenStruct.new(
      tempfile: tempfile_png,
      original_filename: 'logo.png'
    )

    @service = Importance::FileService.new(:students, mock_upload_png)
    persisted_path = @service.store
    @persisted_files << persisted_path

    assert File.exist?(persisted_path)
    assert_equal '.png', File.extname(persisted_path)
    assert_equal "PNG data", File.read(persisted_path)
    refute File.exist?(original_png_path)

    tempfile_png.close!
  end

  def test_store_raises_error_when_upload_is_nil
    assert_raises(ArgumentError) do
      @service = Importance::FileService.new(:students, nil)
      @service.store
    end
  end

   def test_store_raises_error_if_tempfile_path_doesnt_exist
    non_existent_path = "/tmp/non_existent_tempfile_#{SecureRandom.hex}.tmp"
    refute File.exist?(non_existent_path)

    disappeared_upload = OpenStruct.new(
      tempfile: OpenStruct.new(path: non_existent_path),
      original_filename: 'ghost.txt'
    )

    assert_raises(ArgumentError) do
      @service = Importance::FileService.new(:students, disappeared_upload)
      @service.store
    end
   end
end
