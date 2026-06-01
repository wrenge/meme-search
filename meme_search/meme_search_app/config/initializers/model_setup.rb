require "informers"

embedding_model_name = ENV.fetch("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
baked_model_name     = ENV.fetch("BAKED_EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")

# Route HF_HOME so the fallback model uses the baked-in image cache (never
# shadowed by a volume mount) and custom models use the volume-mounted cache
# (downloaded on first run, persisted across restarts).
ENV["HF_HOME"] = embedding_model_name == baked_model_name ? "/rails/models-default" : "/rails/models"

$embedding_model = Informers.pipeline("embedding", embedding_model_name)

test_vector = $embedding_model.call("test")
$embedding_dimensions = test_vector.length

begin
  db_col = ActiveRecord::Base.connection.columns("image_embeddings").find { |c| c.name == "embedding" }
  db_limit = db_col&.limit
  if db_limit && $embedding_dimensions != db_limit
    raise "Embedding model '#{embedding_model_name}' outputs #{$embedding_dimensions} dimensions " \
          "but database column 'image_embeddings.embedding' has limit #{db_limit}. " \
          "Create a migration (change_column :image_embeddings, :embedding, :vector, limit: #{$embedding_dimensions}) " \
          "or choose a model that produces #{db_limit}-dimensional embeddings."
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid,
       ActiveRecord::ConnectionNotEstablished, PG::Error => e
  Rails.logger.warn "Could not validate embedding dimensions against DB: #{e.message}"
end
