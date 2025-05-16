# Importance gem configuration
# Generated on <%= Date.today.strftime("%Y-%m-%d") %>

Importance.configure do |config|
  # Set the layout to be used for the form. Can be :default or :bootstrap
  config.set_layout :bootstrap

  # Example importer configuration:
  config.register_importer :students do |importer|
    # Define required attributes with possible column names
    importer.attribute :first_name, [ "First Name", "FirstName", "fname" ]
    importer.attribute :last_name, [ "Last Name", "LastName", "lname" ]
    importer.attribute :email, [ "Email", "E-Mail", "email", "mail" ]

    # Process records in batches of this size
    importer.batch_size 500

    # Setup runs before the import begins
    importer.setup do
      @total_count = 0
      @errors = []

      # Access controller context and request info
      @current_user_id = current_user.id
      @import_source = request.remote_ip

      # Initialize any resources needed for the import
      @logger = Logger.new(Rails.root.join("log/imports.log"))
      @logger.info("Starting import by #{current_user.email}")
    end

    # Main import logic
    importer.on_complete do |records|
      @total_count += records.size

      records.each do |record|
        begin
          Student.create!(
            first_name: record[:first_name],
            last_name: record[:last_name],
            email: record[:email],
            created_by: @current_user_id
          )
        rescue => e
          @errors << { record: record, message: e.message }
          @logger.error("Error importing #{record}: #{e.message}")
        end
      end
    end

    # Teardown runs after the import finishes
    importer.teardown do
      # Log import results
      @logger.info("Import completed: #{@total_count} records processed with #{@errors.size} errors")

      # Create an audit record
      ImportAudit.create!(
        user_id: @current_user_id,
        records_count: @total_count,
        errors_count: @errors.size,
        source: @import_source
      )

      # Clean up resources
      @logger.close
    end
  end
end
