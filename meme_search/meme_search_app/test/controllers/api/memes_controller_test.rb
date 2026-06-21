require "test_helper"

module Api
  class MemesControllerTest < ActionDispatch::IntegrationTest
    TOKEN = "test-api-token".freeze

    def setup
      @previous_token = ENV["MEME_SEARCH_API_TOKEN"]
      ENV["MEME_SEARCH_API_TOKEN"] = TOKEN

      @upload_dir = Rails.root.join("public", "memes", "direct-uploads")
      FileUtils.mkdir_p(@upload_dir)
      @existing_upload_files = Dir.glob(File.join(@upload_dir, "*")).select { |f| File.file?(f) }
    end

    def teardown
      ENV["MEME_SEARCH_API_TOKEN"] = @previous_token
      Dir.glob(File.join(@upload_dir, "*")).each do |file|
        File.delete(file) if File.file?(file) && !@existing_upload_files.include?(file)
      end
    end

    def create_test_image(filename: "bot_upload.jpg")
      # Minimal valid 1x1 JPEG
      content = Base64.decode64("/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA//2Q==")
      Rack::Test::UploadedFile.new(StringIO.new(content), "image/jpeg", original_filename: filename)
    end

    test "rejects request without token" do
      post api_memes_url, params: { file: create_test_image }
      assert_response :unauthorized
    end

    test "rejects request with wrong token" do
      post api_memes_url,
        params: { file: create_test_image },
        headers: { "Authorization" => "Bearer wrong-token" }
      assert_response :unauthorized
    end

    test "rejects non-image upload" do
      bogus = Rack::Test::UploadedFile.new(StringIO.new("not an image"), "text/plain", original_filename: "note.txt")
      post api_memes_url, params: { file: bogus }, headers: { "Authorization" => "Bearer #{TOKEN}" }
      assert_response :unprocessable_entity
    end

    test "saves image, creates record, and enqueues description generation" do
      provider = Object.new
      provider.define_singleton_method(:name) { "openai" }
      provider.define_singleton_method(:queued_provider?) { false }
      provider.define_singleton_method(:generate) { |_ic| flunk "openai should be enqueued, not generated inline" }

      ImageDescriptionProviders::Factory.stub(:build, provider) do
        assert_difference("ImageCore.count", 1) do
          assert_enqueued_jobs 1, only: GenerateImageDescriptionJob do
            post api_memes_url,
              params: { file: create_test_image(filename: "queued_meme.jpg") },
              headers: { "Authorization" => "Bearer #{TOKEN}" }
          end
        end
      end

      assert_response :created
      body = JSON.parse(response.body)
      assert_equal "queued", body["status"]
      assert body["id"].present?

      image_core = ImageCore.find(body["id"])
      assert_equal "in_queue", image_core.status
      assert File.exist?(File.join(@upload_dir, body["filename"]))
    end
  end
end
