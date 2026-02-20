module OpenSearch::Sugar
  class Models
    ML_INFO = Struct.new(:name, :version, :id)

    def initialize(os)
      @os = os
    end

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
      while true
        model_install_response = @os.http.get("_plugins/_ml/tasks/#{taskid}")
        pp model_install_response
        break if model_install_response["state"] == "COMPLETED"
        raise model_install_response["error"].to_s if model_install_response["state"] == "FAILED"
        sleep(5)
      end
      self[name]
    end

    alias_method :deploy, :register

    # Get info about the latest version of a model by name, id, or partial name
    # @todo make sure models are unique by nickname if nickname is found
    # @param id_or_fullname_or_nickname [String] any of those things
    # @return [ML_INFO] best match as ML_INFO struct
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

    # Get a list of ML models and their versions and internal identifiers
    # @return [Array<ML_INFO>] Array of name/version/id triples as ML_INFO structs
    def list
      resp = raw_list
      lst = resp.dig("hits", "hits").map { |x| x["_source"] }.each_with_object([]) do |ml, a|
        model = ML_INFO.new(ml["name"], ml["model_version"], ml["model_id"])
        a << model
      end
      lst.uniq
    end

    def raw_list
      @os.http.get("/_plugins/_ml/models/_search",
        body: {"query" => {"term" => {"chunk_number" => 0}}})
    end

    def undeploy!(name_or_id)
      m = self[name_or_id]
      @os.http.post("/_plugins/_ml/models/#{m.id}/_undeploy")
    end

    def delete!(name_or_id)
      m = self[name_or_id]
      undeploy!(m.id)
      @os.http.delete("/_plugins/_ml/models/#{m.id}")
    end

    def create_pipeline(name:, model:, description:, field_map:)
      m = self[model]
      raise "Can't find model #{model}" unless m
      url = "/_ingest/pipeline/#{name.gsub(/\s+/, " ").gsub(/\s+/, "_")}"
      field_map_to_temp = field_map.transform_values { |actual_target| "#{actual_target}_temp" }
      temp_to_field_map = field_map.values.each_with_object({}) do |h, actual_target|
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
            source_field: tmp,
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
