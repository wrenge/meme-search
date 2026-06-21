class ChangeEmbeddingDimensions < ActiveRecord::Migration[7.2]
  def up
    dimensions = ENV.fetch("EMBEDDING_DIMENSIONS", 384).to_i
    execute("DELETE FROM image_embeddings")
    execute("ALTER TABLE image_embeddings DROP COLUMN embedding")
    execute("ALTER TABLE image_embeddings ADD COLUMN embedding vector(#{dimensions})")
  end

  def down
    execute("DELETE FROM image_embeddings")
    execute("ALTER TABLE image_embeddings DROP COLUMN embedding")
    execute("ALTER TABLE image_embeddings ADD COLUMN embedding vector(384)")
  end
end
