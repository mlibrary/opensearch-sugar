# frozen_string_literal: true

module OpenSearch::Sugar
  # Base error class for ML model operations
  class ModelError < Error; end

  # Raised when a model cannot be found
  class ModelNotFoundError < ModelError; end

  # Raised when model registration fails
  class ModelRegistrationError < ModelError; end

  # Raised when model registration exceeds timeout
  class ModelRegistrationTimeoutError < ModelRegistrationError; end

  # Manages OpenSearch ML (Machine Learning) models
  #
  # This class provides methods to register, deploy, list, and manage
  # machine learning models in OpenSearch using the ML Commons plugin.
  #
  # @see https://docs.opensearch.org/latest/ml-commons-plugin/index/
  class Models
    # Default polling interval in seconds when waiting for model registration
    DEFAULT_POLL_INTERVAL = 5

    # Default timeout in seconds for model registration
    DEFAULT_POLL_TIMEOUT = 300

    # Data class representing ML model information
    #
    # @!attribute name
    #   @return [String] The model name
    # @!attribute version
    #   @return [String] The model version
    # @!attribute id
    #   @return [String] The internal OpenSearch model ID
    MLInfo = Data.define(:name, :version, :id) do
      # @deprecated Use MLInfo instead
      def self.new(...)
        super
      end
    end

    # @deprecated Use MLInfo instead
    ML_INFO = MLInfo

    # Initializes a new Models manager
    #
    # @param os [OpenSearch::Sugar::Client] The OpenSearch client instance
    def initialize(os) = @os = os

    # Registers and deploys a machine learning model
    #
    # This method registers a new ML model and automatically deploys it.
    # If the model already exists, it returns the existing model information.
    # The method polls the task status until registration completes.
    #
    # @param name [String] The name of the model to register
    # @param version [String] The version of the model
    # @param format [String] The model format (default: "TORCH_SCRIPT")
    # @param poll_interval [Integer] Seconds to wait between polling attempts (default: 5)
    # @param timeout [Integer] Maximum seconds to wait for registration (default: 300)
    # @return [MLInfo, nil] The model information struct, or nil if not found
    # @raise [ModelRegistrationError] If model registration fails
    # @raise [ModelRegistrationTimeoutError] If registration exceeds timeout
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/model-apis/register-model/
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/model-apis/deploy-model/
    # @example Register a TorchScript model
    #   model = client.models.register(name: "my-model", version: "1.0.0")
    # @example Register with custom polling
    #   model = client.models.register(name: "my-model", version: "1.0.0", poll_interval: 10, timeout: 600)
    def register(name:, version:, format: "TORCH_SCRIPT",
      poll_interval: DEFAULT_POLL_INTERVAL,
      timeout: DEFAULT_POLL_TIMEOUT)
      # Return existing model if already registered
      existing_model = self[name]
      return existing_model if existing_model

      config = {
        name:,
        version:,
        model_format: format
      }

      resp = http.post("/_plugins/_ml/models/_register?deploy=true", body: config)
      task_id = resp["task_id"]

      wait_for_task_completion(task_id, interval: poll_interval, timeout: timeout)
      self[name]
    end

    alias_method :deploy, :register

    # Checks if a model is currently deployed
    #
    # @param name_or_id [String] The model name, ID, or nickname pattern
    # @return [Boolean] True if the model is deployed, false otherwise
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/model-apis/model-stats/
    # @example Check if a model is deployed
    #   if client.models.deployed?("my-model")
    #     puts "Model is ready for inference"
    #   end
    def deployed?(name_or_id)
      model = self[name_or_id]
      return false unless model

      stats = http.get("/_plugins/_ml/models/#{model.id}/_stats")
      stats.dig("model_stats", "state") == "DEPLOYED"
    rescue => e
      logger.warn { "Error checking deployment status for '#{name_or_id}': #{e.message}" }
      false
    end

    # Ensures a model is deployed, deploying it if necessary
    #
    # @param name_or_id [String] The model name, ID, or nickname pattern
    # @param poll_interval [Integer] Seconds to wait between polling attempts (default: 5)
    # @param timeout [Integer] Maximum seconds to wait for deployment (default: 300)
    # @return [MLInfo] The model information
    # @raise [ModelNotFoundError] If the model cannot be found
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/model-apis/deploy-model/
    # @example Ensure a model is deployed before use
    #   model = client.models.ensure_deployed!("my-model")
    def ensure_deployed!(name_or_id, poll_interval: DEFAULT_POLL_INTERVAL, timeout: DEFAULT_POLL_TIMEOUT)
      return self[name_or_id] if deployed?(name_or_id)

      model = find_model!(name_or_id)
      resp = http.post("/_plugins/_ml/models/#{model.id}/_deploy")
      task_id = resp["task_id"]

      wait_for_task_completion(task_id, interval: poll_interval, timeout: timeout)
      self[name_or_id]
    end

    private

    # Waits for a model registration task to complete
    #
    # @param task_id [String] The task ID to monitor
    # @param interval [Integer] Seconds to wait between polling attempts
    # @param timeout [Integer] Maximum seconds to wait before timing out
    # @raise [ModelRegistrationError] If the task fails
    # @raise [ModelRegistrationTimeoutError] If the task exceeds timeout
    # @api private
    def wait_for_task_completion(task_id, interval:, timeout:)
      start_time = Time.now

      loop do
        response = http.get("_plugins/_ml/tasks/#{task_id}")
        logger.debug { "Task #{task_id} state: #{response["state"]}" }

        case response["state"]
        when "COMPLETED"
          logger.info { "Task #{task_id} completed successfully" }
          break
        when "FAILED"
          error_msg = "Model registration failed: #{response["error"]}"
          logger.error { "Task #{task_id} failed: #{response["error"]}" }
          raise ModelRegistrationError, error_msg
        else
          # Task is still running (e.g., "RUNNING", "CREATED" states)
          elapsed = Time.now - start_time
          logger.debug { "Task #{task_id} still running (#{elapsed.round(2)}s elapsed)" }

          if elapsed > timeout
            raise ModelRegistrationTimeoutError, "Model registration timeout after #{elapsed.round(2)}s"
          end
        end

        sleep(interval)
      end
    end

    # HTTP client accessor for making requests
    #
    # @return [Object] The HTTP client from the OpenSearch client
    # @api private
    def http = os.http

    # Logger instance for this class
    #
    # @return [Logger] Logger instance
    # @api private
    def logger
      require "logger" unless defined?(Logger)
      @logger ||= os.respond_to?(:logger) ? os.logger : Logger.new($stdout)
    end

    attr_reader :os

    # Fetches models from OpenSearch and transforms them into MLInfo structs
    #
    # @return [Array<MLInfo>] Array of model information structs
    # @api private
    def fetch_models
      raw_list
        .dig("hits", "hits")
        &.map { _1["_source"] }
        &.filter_map do |ml|
          MLInfo.new(
            name: ml["name"],
            version: ml["model_version"],
            id: ml["model_id"]
          )
        end
        &.uniq || []
    end

    # Finds a model by partial name match (case-insensitive)
    #
    # @param models [Array<MLInfo>] List of models to search
    # @param pattern_string [String] Pattern to match against model names
    # @return [MLInfo, nil] Latest version of matching model, or nil
    # @api private
    def find_by_partial_name(models, pattern_string)
      pattern = Regexp.new(pattern_string, Regexp::IGNORECASE)
      models
        .filter { pattern.match?(_1.name) }
        .max_by(&:version)
    end

    # Finds a model or raises an error if not found
    #
    # @param model_identifier [String] Model name, ID, or nickname pattern
    # @return [MLInfo] The found model
    # @raise [ModelNotFoundError] If the model cannot be found
    # @api private
    def find_model!(model_identifier)
      self[model_identifier] || raise(ModelNotFoundError, "Model '#{model_identifier}' not found")
    end

    # Sanitizes a pipeline name by replacing whitespace with underscores
    #
    # @param name [String] The pipeline name to sanitize
    # @return [String] Sanitized pipeline name
    # @api private
    def sanitize_pipeline_name(name) = name.gsub(/\s+/, "_")

    public

    # Get info about the latest version of a model by name, id, or partial name
    #
    # Searches for a model by exact name match, then ID match, then partial name match.
    # For partial matches, returns the latest version.
    #
    # @param id_or_fullname_or_nickname [String] Model identifier (name, ID, or nickname pattern)
    # @return [MLInfo, nil] Best match as MLInfo struct, or nil if not found
    # @todo Ensure models are unique by nickname if nickname is found
    def [](id_or_fullname_or_nickname)
      models = list

      # Try exact name match first, then exact ID match, then partial name match
      models.find { _1.name == id_or_fullname_or_nickname } ||
        models.find { _1.id == id_or_fullname_or_nickname } ||
        find_by_partial_name(models, id_or_fullname_or_nickname)
    end

    # Get a list of ML models and their versions and internal identifiers
    #
    # Results are cached by default to reduce HTTP requests. Use refresh: true to invalidate cache.
    #
    # @param refresh [Boolean] If true, invalidates the cache and fetches fresh data
    # @return [Array<MLInfo>] Array of name/version/id triples as MLInfo structs
    def list(refresh: false)
      @models = nil if refresh
      @models ||= fetch_models
    end

    # Retrieves the raw list of ML models from OpenSearch
    #
    # This method queries the ML models index for all registered models,
    # filtering by chunk_number 0 to get base model information.
    #
    # @return [Hash] The raw search response from OpenSearch
    # @api private
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/model-apis/search-model/
    def raw_list
      http.get("/_plugins/_ml/models/_search",
        body: {query: {term: {chunk_number: 0}}})
    end

    # Undeploys a machine learning model
    #
    # This method undeploys a deployed ML model, freeing up cluster resources.
    # The model remains registered but is no longer available for inference.
    #
    # @param name_or_id [String] The model name, ID, or nickname pattern
    # @return [Hash] The response from OpenSearch
    # @raise [ModelNotFoundError] If the model cannot be found
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/model-apis/undeploy-model/
    # @example Undeploy a model by name
    #   client.models.undeploy!("my-model")
    def undeploy!(name_or_id)
      model = find_model!(name_or_id)
      http.post("/_plugins/_ml/models/#{model.id}/_undeploy")
    end

    # Deletes a machine learning model
    #
    # This method first undeploys the model if it's deployed, then permanently
    # removes it from OpenSearch.
    #
    # WARNING: This operation is destructive and cannot be undone.
    #
    # @param name_or_id [String] The model name, ID, or nickname pattern
    # @return [Hash] The response from OpenSearch
    # @raise [ModelNotFoundError] If the model cannot be found
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/model-apis/delete-model/
    # @example Delete a model
    #   client.models.delete!("my-model")
    def delete!(name_or_id)
      model = find_model!(name_or_id)
      undeploy!(model.id)
      http.delete("/_plugins/_ml/models/#{model.id}")
    end

    # Creates an ingest pipeline for text embedding using an ML model
    #
    # This method creates an ingest pipeline that uses a text embedding model
    # to automatically generate embeddings for specified fields during document ingestion.
    # The pipeline includes a text_embedding processor and copy processors to move
    # the embeddings to their final destination fields.
    #
    # @param name [String] The name for the pipeline (spaces will be converted to underscores)
    # @param model [String] The model name, ID, or nickname to use for embeddings
    # @param description [String] A description of the pipeline's purpose
    # @param field_map [Hash{String => String}] A hash mapping source fields to target embedding fields
    # @return [Hash] The response from OpenSearch
    # @raise [ModelNotFoundError] If the specified model cannot be found
    # @see https://docs.opensearch.org/latest/ingest-pipelines/
    # @see https://docs.opensearch.org/latest/ml-commons-plugin/api/ingest-pipelines/index/
    # @example Create a text embedding pipeline
    #   client.models.create_pipeline(
    #     name: "my-embedding-pipeline",
    #     model: "sentence-transformers",
    #     description: "Embed product descriptions",
    #     field_map: { "description" => "description_embedding" }
    #   )
    def create_pipeline(name:, model:, description:, field_map:)
      model_info = find_model!(model)
      pipeline_name = sanitize_pipeline_name(name)

      payload = PipelineBuilder.new(model_info, description, field_map).build
      http.put("/_ingest/pipeline/#{pipeline_name}", body: payload)
    end

    # Inner class for building ingest pipeline payloads
    #
    # This class encapsulates the logic for creating text embedding pipeline
    # configurations with proper field mapping and copy processors.
    #
    # @api private
    class PipelineBuilder
      # @param model_info [MLInfo] The model information
      # @param description [String] Pipeline description
      # @param field_map [Hash{String => String}] Field mapping configuration
      def initialize(model_info, description, field_map)
        @model_info = model_info
        @description = description
        @field_map = field_map
      end

      # Builds the pipeline payload
      #
      # @return [Hash] The complete pipeline configuration
      def build
        {
          description: @description,
          processors: [text_embedding_processor, *copy_processors]
        }
      end

      private

      # Creates the text embedding processor configuration
      #
      # @return [Hash] Text embedding processor config
      def text_embedding_processor
        {
          text_embedding: {
            model_id: @model_info.id,
            field_map: temp_field_map
          }
        }
      end

      # Creates copy processors for each field mapping
      #
      # @return [Array<Hash>] Array of copy processor configs
      def copy_processors
        @field_map.each_value.map { |target_field| copy_processor(target_field) }
      end

      # Creates a single copy processor configuration
      #
      # @param target_field [String] The target field name
      # @return [Hash] Copy processor config
      def copy_processor(target_field)
        {
          copy: {
            source_field: "#{target_field}_temp.knn",
            target_field: target_field,
            ignore_missing: true,
            remove_source: true
          }
        }
      end

      # Transforms field map to use temporary field names
      #
      # @return [Hash] Field map with temp field values
      def temp_field_map
        @field_map.transform_values { "#{_1}_temp" }
      end
    end
  end
end
