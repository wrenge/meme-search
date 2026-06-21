# Handles a single image submitted over the token-authenticated API (POST /api/memes).
# Saves the file into the "direct-uploads" meme directory, scans to create the ImageCore
# record, and queues description generation using the currently configured provider —
# mirroring the manual upload + generate_description flow used by the web UI.
class MemeApiIntake
  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze

  Result = Struct.new(:success, :image_core, :filename, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(file)
    @file = file
  end

  def call
    return failure("No file provided") if @file.blank?
    return failure("File size exceeds maximum allowed (10MB)") if @file.size > MAX_FILE_SIZE

    extension = File.extname(@file.original_filename.to_s).downcase
    unless ALLOWED_EXTENSIONS.include?(extension)
      return failure("Invalid file type. Allowed: #{ALLOWED_EXTENSIONS.join(", ")}")
    end

    mime_type = Marcel::MimeType.for(@file.tempfile)
    return failure("File content is not a recognized image") unless mime_type&.start_with?("image/")

    image_path = ImagePath.ensure_direct_uploads_path!
    filename = save_file!
    image_path.scan_and_update!

    image_core = ImageCore.find_by(image_path: image_path, name: filename)
    return failure("Upload saved but no image record was created") if image_core.nil?

    queue_description_generation!(image_core)
    Result.new(success: true, image_core: image_core, filename: filename)
  rescue StandardError => e
    Rails.logger.error "MemeApiIntake failed: #{e.class}: #{e.message}"
    failure(e.message)
  end

  private

  def failure(message)
    Result.new(success: false, error: message)
  end

  def upload_dir
    @upload_dir ||= File.join(Rails.root, "public", "memes", "direct-uploads")
  end

  def save_file!
    filename = generate_unique_filename(sanitize_filename(@file.original_filename.to_s))
    File.open(File.join(upload_dir, filename), "wb") { |f| f.write(@file.read) }
    filename
  end

  def sanitize_filename(filename)
    basename = File.basename(filename)
    sanitized = basename.tr("/", "_").tr("\0", "").gsub(/[\x00-\x1f\x7f]/, "")
    sanitized = sanitized.gsub(/\s+/, " ").strip
    sanitized.presence || "meme.jpg"
  end

  def generate_unique_filename(filename)
    return filename unless File.exist?(File.join(upload_dir, filename))

    extension = File.extname(filename)
    basename = File.basename(filename, extension)
    "#{basename}_#{Time.now.to_i}#{extension}"
  end

  # Mirrors ImageCoresController#generate_description: queued providers enqueue internally,
  # non-queued providers (e.g. openai) create an attempt and enqueue the Solid Queue job.
  def queue_description_generation!(image_core)
    configuration = ImageDescriptionProviders::Configuration.current
    provider = ImageDescriptionProviders::Factory.build(configuration)

    if provider.queued_provider?
      provider.generate(image_core)
    else
      provider_name = provider.respond_to?(:name) ? provider.name : configuration.provider
      attempt = image_core.start_description_generation_attempt!(
        provider: provider_name,
        provider_settings: configuration.job_options
      )
      image_core.update!(status: :in_queue)
      GenerateImageDescriptionJob.perform_later(image_core.id, configuration.job_options, attempt.id)
    end
  end
end
