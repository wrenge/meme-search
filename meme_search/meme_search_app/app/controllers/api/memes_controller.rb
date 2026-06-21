module Api
  # POST /api/memes
  # Accepts a single image (multipart field `file`, or first of `files`), saves it into the
  # direct-uploads meme directory, creates the ImageCore record, and queues description
  # generation. Authenticated via bearer token (see Api::BaseController).
  class MemesController < BaseController
    def create
      file = params[:file] || Array(params[:files]).first

      result = MemeApiIntake.new(file).call

      if result.success?
        render json: {
          status: "queued",
          id: result.image_core.id,
          filename: result.filename
        }, status: :created
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end
  end
end
