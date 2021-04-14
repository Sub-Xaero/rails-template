Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      "https://localhost:3000",
    )
    resource "/packs/*", headers: :any, methods: [:get, :options, :head]
  end
end