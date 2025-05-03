# Importance

Importance allows users to select which columns of an Excel file should be
imported and which ones should be ignored. This makes it possible to upload
files with arbtirary headers, as long as all necessary data is contained.

## Usage

Importance allows you to define one or more `importers`, where each allows you
to define a different treatment of the data you uploaded.

Define the uploaders in an initializer, for example `config/initializers/importance.rb`.
You can define as many importers as you want.

```ruby
Importance.configure do |config|

  # Define an importer for students
  config.register_importer :students do |importer|

    # They each must contain first name, last name and email. Allow different spellings.
    importer.attribute :first_name, [ "Vorname", "vorname", "vname", "fname", "l_vorname" ]
    importer.attribute :last_name, [ "Nachname", "nachname", "nname", "lname", "l_nachname" ]
    importer.attribute :email, [ "E-Mail", "email", "mail", "l_email" ]

    # When the mapping has run, process them in slices of 500.
    importer.batch_size 500

    # For each entry of the file, create a new student record
    importer.on_complete do |records|
      records.each do |record|
        Student.create(first_name: record[:first_name], last_name: record[:last_name], email: record[:email])
      end
    end
  end

  #...
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

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
