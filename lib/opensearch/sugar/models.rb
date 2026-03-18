module OpenSearch::Sugar
  class Models
    # Custom exception for model-related errors
    class ModelError < OpenSearch::Sugar::Error; end

    class ModelDeploymentError < ModelError; end

    class ModelNotFoundError < ModelError; end

    class TimeoutError < ModelError; end

    ML_INFO = Struct.new(:name, :version, :id)

    # Default timeout for model deployment operations (in seconds)
    DEFAULT_DEPLOYMENT_TIMEOUT = 300
    # Default polling interval when waiting for deployment (in seconds)
    DEFAULT_POLL_INTERVAL = 5

    def initialize(os)
      @os = os
      @logger = os.logger
    end

    # Registers and deploys a machine learning model
    #
    # @param name [String] The full model name (e.g., 'huggingface/sentence-transformers/all-MiniLM-L12-v2')
    # @param version [String] The model version
    # @param format [String] The model format (default: 'TORCH_SCRIPT')
    # @param timeout [Integer] Maximum time to wait for deployment in seconds (default: 300)
    # @param poll_interval [Integer] Time between polling attempts in seconds (default: 5)
    # @return [ML_INFO] Model information struct
    # @raise [ModelDeploymentError] If deployment fails
    # @raise [TimeoutError] If deployment exceeds timeout
    # @see https://opensearch.org/docs/latest/ml-commons-plugin/api/model-apis/register-model/
    def register(name:, version:, format: "TORCH_SCRIPT", timeout: DEFAULT_DEPLOYMENT_TIMEOUT, poll_interval: DEFAULT_POLL_INTERVAL)
      config = {
        name: name,
        version: version,
        model_format: format
      }

      current = find_by_name(name)
      return current if current

      resp = @os.http.post("/_plugins/_ml/models/_register?deploy=true", body: config)
      taskid = resp["task_id"]

      wait_for_deployment(taskid, timeout: timeout, poll_interval: poll_interval)
      find_by_name(name)
    end

    alias_method :deploy, :register

    # Finds a model by exact name, ID, or partial name match (for backward compatibility)
    #
    # This method tries multiple search strategies in order:
    # 1. Exact name match
    # 2. Exact ID match
    # 3. Case-insensitive partial name match (returns latest version)
    #
    # @param id_or_fullname_or_nickname [String] Model identifier
    # @return [ML_INFO, nil] Model information or nil if not found
    # @note For clearer semantics, use {#find_by_name}, {#find_by_id}, or {#search} instead
    # @deprecated Use explicit search methods for clearer intent
    def [](id_or_fullname_or_nickname)
      find_by_name(id_or_fullname_or_nickname) ||
        find_by_id(id_or_fullname_or_nickname) ||
        search(id_or_fullname_or_nickname).first
    end

    # Finds a model by exact name
    #
    # @param name [String] The exact model name
    # @return [ML_INFO, nil] Model information or nil if not found
    # @example
    #   model = client.models.find_by_name('huggingface/sentence-transformers/all-MiniLM-L12-v2')
    def find_by_name(name)
      list.find { |model| model.name == name }
    end

    # Finds a model by exact ID
    #
    # @param id [String] The model ID
    # @return [ML_INFO, nil] Model information or nil if not found
    # @example
    #   model = client.models.find_by_id('abc123xyz')
    def find_by_id(id)
      list.find { |model| model.id == id }
    end

    # Searches for models matching a pattern (case-insensitive)
    #
    # @param pattern [String] The pattern to match against model names
    # @return [Array<ML_INFO>] Array of matching models sorted by version (newest first)
    # @example
    #   # Find all MiniLM models
    #   models = client.models.search('minilm')
    #   models.each { |m| puts "#{m.name} v#{m.version}" }
    def search(pattern)
      regex = Regexp.new(pattern, Regexp::IGNORECASE)
      list
        .select { |model| regex.match(model.name) }
        .sort_by { |model| [-model.version.to_s.to_i, model.name] }
    end

    # Get a list of ML models and their versions and internal identifiers
    #
    # @return [Array<ML_INFO>] Array of name/version/id triples as ML_INFO structs
    # @example
    #   models = client.models.list
    #   models.each { |m| puts "#{m.name} v#{m.version}" }
    def list
      lst = raw_list.dig("hits", "hits").map { |x| x["_source"] }.each_with_object([]) do |ml, a|
        model = ML_INFO.new(ml["name"], ml["model_version"], ml["model_id"])
        a << model
      end
      lst.uniq
    end

    # Gets the raw list of models from OpenSearch
    #
    # @return [Hash] Raw OpenSearch response
    def raw_list
      @os.http.get("/_plugins/_ml/models/_search",
        body: {"query" => {"term" => {"chunk_number" => 0}}})
    end

    # Undeploys a model by name or ID
    #
    # @param name_or_id [String] The model name or ID
    # @return [Hash] OpenSearch response
    # @raise [ModelNotFoundError] If the model cannot be found
    # @see https://opensearch.org/docs/latest/ml-commons-plugin/api/model-apis/undeploy-model/
    def undeploy!(name_or_id)
      model = find_by_id(name_or_id) || find_by_name(name_or_id)
      raise ModelNotFoundError, "Model '#{name_or_id}' not found" unless model

      @os.http.post("/_plugins/_ml/models/#{model.id}/_undeploy")
    end

    # Deletes a model by name or ID (undeploys first if necessary)
    #
    # @param name_or_id [String] The model name or ID
    # @return [Hash] OpenSearch response
    # @raise [ModelNotFoundError] If the model cannot be found
    # @see https://opensearch.org/docs/latest/ml-commons-plugin/api/model-apis/delete-model/
    def delete!(name_or_id)
      model = find_by_id(name_or_id) || find_by_name(name_or_id)
      raise ModelNotFoundError, "Model '#{name_or_id}' not found" unless model

      undeploy!(model.id)
      @os.http.delete("/_plugins/_ml/models/#{model.id}")
    end

    # Creates an ingest pipeline that uses a model to generate embeddings
    #
    # @param name [String] The pipeline name (spaces will be converted to underscores)
    # @param model [String] The model name or ID
    # @param description [String] A description of what this pipeline does
    # @param field_map [Hash] Map of source field names to target embedding field names
    # @return [Hash] OpenSearch response
    # @raise [ModelNotFoundError] If the specified model cannot be found
    # @see https://opensearch.org/docs/latest/ml-commons-plugin/semantic-search/
    # @example
    #   client.models.create_pipeline(
    #     name: 'text_embedding_pipeline',
    #     model: 'all-MiniLM-L12-v2',
    #     description: 'Generate text embeddings',
    #     field_map: { 'content' => 'content_embedding' }
    #   )
    def create_pipeline(name:, model:, description:, field_map:)
      m = self[model]
      raise ModelNotFoundError, "Can't find model '#{model}'" unless m

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

    private

    # Waits for a model deployment task to complete
    #
    # @param task_id [String] The deployment task ID
    # @param timeout [Integer] Maximum time to wait in seconds
    # @param poll_interval [Integer] Time between polling attempts in seconds
    # @return [void]
    # @raise [ModelDeploymentError] If deployment fails
    # @raise [TimeoutError] If deployment exceeds timeout
    def wait_for_deployment(task_id, timeout:, poll_interval:)
      deadline = Time.now + timeout

      loop do
        raise TimeoutError, "Model deployment timed out after #{timeout} seconds" if Time.now >= deadline

        model_install_response = @os.http.get("_plugins/_ml/tasks/#{task_id}")
        @logger.debug "Model installation status: #{model_install_response}"

        case model_install_response["state"]
        when "COMPLETED"
          @logger.info "Model deployment completed successfully"
          return
        when "FAILED"
          error_message = model_install_response["error"] || "Unknown error"
          raise ModelDeploymentError, "Model deployment failed: #{error_message}"
        end

        sleep(poll_interval)
      end
    end
  end
end
