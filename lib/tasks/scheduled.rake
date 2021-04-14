namespace :scheduled do
  task hourly: [
  ]

  task daily: [
    "cleanup:active_storage_orphans"
  ]

  task weekly: [
  ]
end