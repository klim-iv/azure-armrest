module Azure
  module Armrest
    # Class for managing storage accounts.
    class StorageAccountService < ArmrestService

      # Valid account types for the create or update method.
      VALID_ACCOUNT_TYPES = %w[
        Standard_LRS
        Standard_ZRS
        Standard_GRS
        Standard_RAGRS
      ]

      # Creates and returns a new StorageAccountService (SAS) instance.
      #
      def initialize(_armrest_configuration, options = {})
        super
        @provider = options[:provider] || 'Microsoft.Storage'
        #set_service_api_version(options, 'storageAccounts')
        @api_version = '2015-05-01-preview' # Must hard code for now
      end

      # Return information for the given storage account name for the
      # provided +group+. If no group is specified, it will use the
      # group set in the constructor.
      #
      # If the +include_keys+ option is set to true, then the keys for that
      # storage account will be included in the output as well.
      #
      # Example:
      #
      #   sas.get('portalvhds1234', 'Default-Storage-CentralUS')
      #
      def get(account_name, group = armrest_configuration.resource_group, include_keys = false)
        raise ArgumentError, "must specify resource group" unless group

        url = build_url(group, account_name)
        results = JSON.parse(rest_get(url))
        results['properties'].merge!(list_account_keys(account_name, group)) if include_keys

        results
      end

      # Returns a list of available storage accounts for the given subscription
      # for the provided +group+, or all resource groups if none is provided.
      #
      def list(group = nil)
        if group
          url = build_url(group)
          JSON.parse(rest_get(url))['value']
        else
          array = []
          threads = []
          mutex = Mutex.new

          resource_groups.each do |rg|
            threads << Thread.new(rg['name']) do |group|
              url = build_url(group)
              response = rest_get(url)
              results = JSON.parse(response)['value']
              if results && !results.empty?
                mutex.synchronize{
                  results.each{ |hash| hash['resourceGroup'] = group }
                  array << results
                }
              end
            end
          end

          threads.each(&:join)

          array.flatten
        end
      end

      # List all storage accounts for the current subscription. This does not
      # include storage account key information.
      #
      def list_all_for_subscription
        sub_id = armrest_configuration.subscription_id
        url = File.join(Azure::Armrest::COMMON_URI, sub_id, 'providers', @provider, 'storageAccounts')
        url << "?api-version=#{@api_version}"
        JSON.parse(rest_get(url))
      end

      alias list_all list_all_for_subscription

      # Creates a new storage account, or updates an existing account with the
      # specified parameters. The possible parameters are:
      #
      # - :name
      #   Required. The name of the storage account within the specified
      #   resource stack. Must be 3-24 alphanumeric lowercase characters.
      #
      # - :validating
      #   Optional. Set to 'nameAvailability' to indicate that the account
      #   name must be checked for global availability.
      #
      # - :type
      #   The type of storage account. The default is "Standard_GRS".
      #
      # - :location
      #   Required: One of the Azure geo regions, e.g. 'West US'.
      #
      # - :tags
      #   A hash of tags to describe the resource. You may have a maximum of
      #   10 tags, and each key has a max size of 128 characters, and each
      #   value has a max size of 256 characters. These are optional.
      #
      # Example:
      #
      #   sas = Azure::Armrest::StorageAccountService(config)
      #
      #   sas.create(
      #     :name     => "yourstorageaccount1",
      #     :location => "West US",
      #     :type     => "Standard_ZRS",
      #     :tags     => {:YourCompany => true}
      #   )
      #
      # For convenience you may also specify the :resource_group as an option.
      #
      def create(options = {}, rgroup = armrest_configuration.resource_group)
        rgroup ||= options[:resource_group]
        raise ArgumentError, "No resource group specified" if rgroup.nil?

        # Mandatory options
        name = options.fetch(:name)
        location = options.fetch(:location)

        # Optional
        tags = options[:tags]
        type = options[:type] || "Standard_GRS"

        properties = {:accountType => type}

        validate_account_type(type)
        validate_account_name(name)

        url = build_url(rgroup, name)
        url << "&validating=" << options[:validating] if options[:validating]

        body = {
          :name       => name,
          :location   => location,
          :tags       => tags,
          :properties => properties
        }.to_json

        response = rest_put(url, body)
        response.return!
      end

      alias update create

      # Delete the given storage account name.
      #
      def delete(account_name, group = armrest_configuration.resource_group)
        raise ArgumentError, "must specify resource group" unless group

        url = build_url(group, account_name)
        response = rest_delete(url)
        response.return!
      end

      # Returns the primary and secondary access keys for the given
      # storage account.
      #
      def list_account_keys(account_name, group = armrest_configuration.resource_group)
        raise ArgumentError, "must specify resource group" unless group

        url = build_url(group, account_name, 'listKeys')
        response = rest_post(url)
        JSON.parse(response)
      end

      # Regenerates the primary and secondary access keys for the given
      # storage account.
      #
      def regenerate_storage_account_keys(account_name)
        raise ArgumentError, "must specify resource group" unless group

        url = build_url(group, account_name, 'regenerateKey')
        response = rest_post(url)
        response.return!
      end

      private

      def validate_account_type(account_type)
        unless VALID_ACCOUNT_TYPES.include?(account_type)
          raise ArgumentError, "invalid account type '#{account_type}'"
        end
      end

      def validate_account_name(name)
        if name.size < 3 || name.size > 24 || name[/\W+/]
          raise ArgumentError, "name must be 3-24 alpha-numeric characters only"
        end
      end

      # Builds a URL based on subscription_id an resource_group and any other
      # arguments provided, and appends it with the api-version.
      def build_url(resource_group, *args)
        url = File.join(
          Azure::Armrest::COMMON_URI,
          armrest_configuration.subscription_id,
          'resourceGroups',
          resource_group,
          'providers',
          @provider,
          'storageAccounts',
        )

        url = File.join(url, *args) unless args.empty?
        url << "?api-version=#{@api_version}"
      end
    end
  end
end
