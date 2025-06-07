# Importance

Importance allows users to select which columns of an Excel or CSV file should be
imported and which ones should be ignored. This makes it possible to upload
files with arbitrary headers, as long as all necessary data is contained.

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

Each importer can define callbacks that control what is done before the import, during the import,
after the import and if any errors occurred.

| Callback | Usage |
|---|---|
| `setup` | Code to be run once before the import. Initialization of an error array, loading of required parent records |
| `perform` | The actual import logic. This block receives a collection of `records` for which you write the logic to import. It may be called multiple times if the dataset is large. |
| `teardown` | Code to be run one after the import. Cleanup, flushing data to a log. |
| `error` | Callback if any unhandled exception occurred. Recives the exception as a parameter. |

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
      
      # Display errors to the user if any occurred
      if @errors.any?
        # Store errors in database to avoid session size limits (4KB)
        import_log = ImportLog.create!(
          user: current_user,
          total_records: @total_count,
          error_count: @errors.size,
          errors_data: @errors.to_json
        )
        
        flash[:alert] = "Import completed with #{@errors.size} errors. Please review the details below."
        redirect_to rails_routes.import_log_path(import_log)
      else
        redirect_to rails_routes.students_path, notice: "Successfully imported #{@total_count} students."
      end
    end

    # Controller code to run after the import
    importer.error do |exception|
      redirect_to rails_routes.root_path, alert: "Import failed: #{exception.message}"
    end
  end
end
```

Add a file upload form to your application. You can use libraries like
Dropzone.js to create drag and drop interfaces, and you can style them just
as you wish. Make sure the path stays, and it is a multipart form.

The gem supports Excel files (.xlsx, .xls) and CSV files (.csv). For CSV files,
the first row is automatically treated as the header row.

```erb
<%= form_with url: importance.submit_path(importer: :students), multipart: true do |form| %>
  <%= form.file_field :file, accept: ".xlsx,.xls,.csv" %>
  <%= form.submit "Submit" %>
<% end %>
```

### Displaying Import Errors

If you collect errors in the `@errors` variable during import (as shown in the example above), you can display them to users in your views. Since sessions have a 4KB limit, errors are stored in the database:

First, create an ImportLog model to store the errors:

```ruby
# app/models/import_log.rb
class ImportLog < ApplicationRecord
  belongs_to :user
  
  def errors_array
    JSON.parse(errors_data || '[]')
  end
end
```

```ruby
# Migration
class CreateImportLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :import_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :total_records
      t.integer :error_count
      t.text :errors_data
      t.timestamps
    end
  end
end
```

Then display the errors in your view:

```erb
<!-- In your import_logs/show.html.erb view -->
<div class="alert alert-warning">
  <h4>Import Errors</h4>
  <p>The following <%= @import_log.error_count %> records could not be imported:</p>
  
  <% errors = @import_log.errors_array %>
  <% if errors.size > 50 %>
    <p><em>Showing first 50 errors (total: <%= errors.size %>)</em></p>
    <% errors = errors.first(50) %>
  <% end %>
  
  <ul>
    <% errors.each do |error| %>
      <li>
        <strong>Row data:</strong> <%= error["record"].inspect %><br>
        <strong>Error:</strong> <%= error["message"] %>
      </li>
    <% end %>
  </ul>
</div>
```

## Customization

The following translations can be overriden by the application

```yml
en:
  importance:
    use_column_as: Use column as
    ignore: Ignore
    import: Import
```

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
