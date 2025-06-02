# Importance

Importance allows users to select which columns of an Excel file should be
imported and which ones should be ignored. This makes it possible to upload
files with arbtirary headers, as long as all necessary data is contained.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "importance"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install importance
```

Generate the initializer:

```bash
rails generate importance:install
```

This will create a configuration file at `config/initializers/importance.rb` and mount
the engine in `config/routes.rb`.

## Usage

Importance allows you to define one or more `importers`, where each allows you
to define a different treatment of the data you uploaded.

Define the uploaders in an initializer, for example `config/initializers/importance.rb`.
You can define as many importers as you want.

```ruby
Importance.configure do |config|
  config.set_layout :bootstrap

  config.register_importer :students do |importer|
    importer.attribute :first_name, [ "Vorname", "vorname", "vname", "fname", "l_vorname" ]
    importer.attribute :last_name, [ "Nachname", "nachname", "nname", "lname", "l_nachname" ]
    importer.attribute :email, [ "E-Mail", "email", "mail", "l_email" ]
    
    importer.batch_size 500
    
    # Setup code runs before import
    importer.setup do
      @total_count = 0
      @errors = []
      @school = School.find(params[:school_id]) # Access to params
      @current_time = Time.current
    end

    # Main import logic has access to instance variables from setup
    importer.perform do |records|
      @total_count += records.size
      
      records.each do |record|
        begin
          Student.create(
            first_name: record[:first_name],
            last_name: record[:last_name],
            email: record[:email],
            created_by: current_user.id,  # Access to current_user
            school_id: @school.id         # Access to instance var from setup
          )
        rescue => e
          @errors << { record: record, message: e.message }
        end
      end
    end
    
    # Teardown code runs after import
    importer.teardown do
      # Can access both controller context and setup variables
      ActivityLog.create(
        user: current_user,
        action: "import",
        details: "Imported #{@total_count} students with #{@errors.size} errors"
      )
    end
  end
end
```

Add a file upload form to your application. You can use libraries like
Dropzone.js to create drag and drop interfaces, and you can style them just
as you wish. Make sure the path stays, and it is a multipart form. 

```erb
<%= form_with url: importance.submit_path(importer: :students), multipart: true do |form| %>
  <%= form.file_field :file %>
  <%= form.submit "Submit" %>
<% end %>
```

## Customization

The following translations can be overriden by the application

```yml
en:
  importance:
    use_column_as: Use column as
    ignore: Ignore
    save: Save
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
