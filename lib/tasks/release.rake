namespace :release do
  task all: [
    "db:migrate",
  ]
end