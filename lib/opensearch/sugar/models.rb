module OpenSearch::Sugar
  # Manages ML models deployed via the
  # {https://opensearch.org/docs/latest/ml-commons-plugin/index/ OpenSearch ML Commons plugin}.
  #
  # Provides methods to register, deploy, list, and delete models, as well as to build
  # text-embedding ingest pipelines that use a deployed model.
  #
  # Access an instance via {OpenSearch::Sugar::Client#models}:
  #
  # @example
  #   models = client.models
  #   model  = models.register(name: "all-MiniLM-L6-v2", version: "1.0.0")
  #   puts model.id
  class Models
    # Struct representing a deployed ML model with +:name+, +:version+, and +:id+ members.
    #
    # @!attribute [r] name
    #   @return [String] The model name
    # @!attribute [r] version
    #   @return [String] The model version string
    # @!attribute [r] id
    #   @return [String] The internal OpenSearch model ID (used in API calls)
    ML_INFO = Struct.new(:name, :version, :id)

    # @param os [OpenSearch::Sugar::Client] The client used for ML API calls
    def initialize(os)
      @os = os
    end

    # Registers and deploys an ML model via the ML Commons plugin.
    #
    # Idempotent — if a model matching +name+ is already registered, returns the
    # existing {ML_INFO} without re-registering. Polls the task status every 5 seconds
    # until deployment completes or fails.
    #
    # @param name [String] The model name (e.g. +"all-MiniLM-L6-v2"+)
    # @param version [String] The model version (e.g. +"1.0.0"+)
    # @param format [String] The model format (default: +"TORCH_SCRIPT"+)
    # @return [ML_INFO, nil] The registered model info, or +nil+ if lookup fails after registration
    # @raise [RuntimeError] If the registration task reports a +FAILED+ state
    # @see https://opensearch.org/docs/latest/ml-commons-plugin/api/model-apis/register-model/ OpenSearch register model API
    # @example
    #   model = client.models.register(name: "all-MiniLM-L6-v2", version: "1.0.0")
    #   puts model.id
    def register(name:, version:, format: "TORCH_SCRIPT")
      config = {
        name: name,
        version: version,
        model_format: format
      }

      current = self[name]
      return current if current

      resp = @os.http.post("/_plugins/_ml/models/_register?deploy=true", body: config)
      taskid = resp["task_id"]
      loop do
        model_install_response = @os.http.get("_plugins/_ml/tasks/#{taskid}")
        break if model_install_response["state"] == "COMPLETED"
        raise model_install_response["error"].to_s if model_install_response["state"] == "FAILED"
        sleep(5)
      end
      self[name]
    end

    # Alias for {#register}.
    # @see #register
    alias_method :deploy, :register

    # Get info about the latest version of a model by name, id, or partial name
    # @todo make sure models are unique by nickname if nickname is found
    # @param id_or_fullname_or_nickname [String] Exact model name, exact model ID, or
    #   a case-insensitive partial name. When multiple partial matches exist, returns the
    #   one with the highest version.
    # @return [ML_INFO, nil] Matching model info, or +nil+ if not found
    # @example Look up by exact name
    #   model = client.models["all-MiniLM-L6-v2"]
    # @example Look up by partial name
    #   model = client.models["MiniLM"]
    def [](id_or_fullname_or_nickname)
      mlm = list
      name = mlm.find { |x| x.name == id_or_fullname_or_nickname }
      return name if name

      id = mlm.find { |m| m.id == id_or_fullname_or_nickname }
      return id if id

      nickname_pattern = Regexp.new(id_or_fullname_or_nickname, "i")
      nicks = mlm.find_all { |m| nickname_pattern.match(m.name) }.sort { |a, b| b.version <=> a.version }
      nicks.first # could be nil
    end

    # Returns all deployed ML models in the cluster.
    #
    # @return [Array<ML_INFO>] Unique name/version/id triples for all deployed models
    # @example
    #   client.models.list.each { |m| puts "#{m.name} #{m.version} (#{m.id})" }
    def list
      lst = raw_list.dig("hits", "hits").map { |x| x["_source"] }.each_with_object([]) do |ml, a|
        model = ML_INFO.new(ml["name"], ml["model_version"], ml["model_id"])
        a << model
      end
      lst.uniq
    end

    # Returns the raw OpenSearch response from the ML models search endpoint.
    #
    # This is the unprocessed response from +/_plugins/_ml/models/_search+, filtered
    # to chunk 0 to avoid returning embedding chunks. Prefer {#list} or {#[]} for
    # normal usage.
    #
    # @return [Hash] Raw OpenSearch search response
    def raw_list
      @os.http.get("/_plugins/_ml/models/_search",
        body: {"query" => {"term" => {"chunk_number" => 0}}})
    end

    # Undeploys (unloads from memory) a model without deleting its registration.
    #
    # @param name_or_id [String] Model name, ID, or partial name accepted by {#[]}
    # @return [Hash] The OpenSearch undeploy response
    # @raise [NoMethodError] If no model matching +name_or_id+ is found
    # @example
    #   client.models.undeploy!("all-MiniLM-L6-v2")
    def undeploy!(name_or_id)
      m = self[name_or_id]
      @os.http.post("/_plugins/_ml/models/#{m.id}/_undeploy")
    end

    # Undeploys and permanently deletes a model from the cluster.
    #
    # @param name_or_id [String] Model name, ID, or partial name accepted by {#[]}
    # @return [Hash] The OpenSearch delete response
    # @raise [NoMethodError] If no model matching +name_or_id+ is found
    # @example
    #   client.models.delete!("all-MiniLM-L6-v2")
    def delete!(name_or_id)
      m = self[name_or_id]
      undeploy!(m.id)
      @os.http.delete("/_plugins/_ml/models/#{m.id}")
    end

    # Deletes an ingest pipeline by name.
    #
    # @param pipeline_name [String] The name of the pipeline to delete
    # @return [Hash] The OpenSearch acknowledgement response
    # @example
    #   client.models.delete_pipeline!("my-embedding-pipeline")
    def delete_pipeline!(pipeline_name)
      @os.ingest.delete_pipeline(id: pipeline_name)
    end

    # Creates a text-embedding ingest pipeline backed by a deployed ML model.
    #
    # The pipeline uses the ML Commons +text_embedding+ processor to generate embeddings
    # for each field in +field_map+. Because +text_embedding+ writes to a temporary field,
    # the pipeline also inserts +copy+ processors to move the resulting +.knn+ vectors to
    # the intended target fields.
    #
    # @param name [String] The name to give the ingest pipeline
    # @param model [String] Model name, ID, or partial name accepted by {#[]}
    # @param description [String] Human-readable description of the pipeline
    # @param field_map [Hash{String => String}] Mapping of source text fields to target
    #   vector fields (e.g. +{ "title" => "title_embedding" }+)
    # @return [Hash] The OpenSearch response
    # @raise [RuntimeError] If no model matching +model+ is found
    # @see https://opensearch.org/docs/latest/ml-commons-plugin/semantic-search/ OpenSearch semantic search docs
    # @example
    #   client.models.create_pipeline(
    #     name: "product-embeddings",
    #     model: "all-MiniLM-L6-v2",
    #     description: "Generate embeddings for product titles",
    #     field_map: { "title" => "title_knn" }
    #   )
    def create_pipeline(name:, model:, description:, field_map:)
      m = self[model]
      raise "Can't find model #{model}" unless m
      url = "/_ingest/pipeline/#{name.gsub(/\s+/, " ").gsub(/\s+/, "_")}"
      field_map_to_temp = field_map.transform_values { |actual_target| "#{actual_target}_temp" }
      temp_to_field_map = field_map.values.each_with_object({}) do |actual_target, h|
        h["#{actual_target}_temp"] = actual_target
      end

      payload = {
        description: description,
        processors: [
          {
            text_embedding: {
              model_id: m.id,
              field_map: field_map_to_temp
            }
          }
        ]
      }

      temp_to_field_map.each_pair do |tmp, real|
        payload[:processors] << {
          copy: {
            source_field: "#{tmp}.knn",
            target_field: real,
            ignore_missing: true,
            remove_source: true
          }
        }
      end
      @os.http.put(url, body: payload)
    end
  end
end
