class ChangeEmbeddingDimensions < ActiveRecord::Migration[7.2]
  def up
    dimensions = ENV.fetch("EMBEDDING_DIMENSIONS", 384).to_i
    change_column :image_embeddings, :embedding, :vector, limit: dimensions
  end

  def down
    change_column :image_embeddings, :embedding, :vector, limit: 384
  end
end
