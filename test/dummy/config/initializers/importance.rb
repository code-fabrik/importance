if Rails.env.development? && defined?(Zeitwerk::Loader.default_logger)
  # Zeitwerk::Loader.default_logger = Logger.new(STDOUT) # Log to console
  Zeitwerk::Loader.default_logger = Logger.new("log/zeitwerk.log") # Log to file
end

Importance.configure do |config|
  config.set_layout :bootstrap
  config.register_importer :students do |importer|
    importer.attribute :first_name, [ "Vorname", "vorname", "vname", "fname", "l_vorname" ]
    importer.attribute :last_name, [ "Nachname", "nachname", "nname", "lname", "l_nachname" ]
    importer.attribute :email, [ "E-Mail", "email", "mail", "l_email" ]
    importer.batch_size 500
    importer.on_complete do |records|
      records.each do |record|
        puts "Imported student: #{record.inspect}"
      end
    end
  end
end
