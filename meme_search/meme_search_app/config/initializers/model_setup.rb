require "informers"

embedding_model_name = ENV.fetch("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
baked_model_name     = ENV.fetch("BAKED_EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")

# Route cache dir: fallback model uses the baked-in image path (never shadowed
# by the volume mount); custom models use the volume-mounted path so downloads
# persist across restarts. informers uses Informers.cache_dir (backed by XDG_CACHE_HOME).
Informers.cache_dir = embedding_model_name == baked_model_name \
  ? "/rails/models-default/informers" \
  : "/rails/models/informers"

$embedding_model = Informers.pipeline("embedding", embedding_model_name)

test_vector = $embedding_model.call("test")
$embedding_dimensions = test_vector.length

begin
  db_col = ActiveRecord::Base.connection.columns("image_embeddings").find { |c| c.name == "embedding" }
  db_limit = db_col&.limit
  if db_limit && $embedding_dimensions != db_limit
    Rails.logger.info "[EmbeddingSync] Column dimension changed: #{db_limit} → #{$embedding_dimensions}. Migrating..."
    ActiveRecord::Base.connection.execute("DELETE FROM image_embeddings")
    ActiveRecord::Base.connection.change_column(:image_embeddings, :embedding, :vector, limit: $embedding_dimensions)
    Rails.logger.info "[EmbeddingSync] Done. Existing embeddings cleared — regenerate from the UI."
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid,
       ActiveRecord::ConnectionNotEstablished, PG::Error => e
  Rails.logger.warn "Could not validate embedding dimensions against DB: #{e.message}"
end
