namespace :cleanup do
  desc "Cleans up orphaned ActiveStorage::Blob objects"
  task active_storage_orphans: :environment do
    ActiveStorage::Blob.unattached.where("active_storage_blobs.created_at < ?", 1.day.ago).find_each(&:purge_later)
  end
end