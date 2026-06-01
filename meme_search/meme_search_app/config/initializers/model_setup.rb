require "informers"

embedding_model_name = ENV.fetch("EMBEDDING_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
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
