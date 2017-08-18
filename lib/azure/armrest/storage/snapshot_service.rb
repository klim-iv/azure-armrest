# Azure namespace
module Azure
  # Armrest namespace
  module Armrest
    # Storage namespace
    module Storage
      # Base class for managing snapshots.
      class SnapshotService < ResourceGroupBasedService
        require_relative './raw_blob_helper'
        include Azure::Armrest::Storage::RawBlobHelper

        # Create and return a new SnapshotService instance.
        #
        def initialize(configuration, options = {})
          super(configuration, 'snapshots', 'Microsoft.Compute', options)
        end
      end # SnapshotService
    end # Storage
  end # Armrest
end # Azure
