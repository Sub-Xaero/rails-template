Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      "https://localhost:3000",
      # TODO: Set up permitted domains for CORS
    )
    resource "/packs/*", headers: :any, methods: [:get, :options, :head]
  end
end