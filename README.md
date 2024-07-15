# UberTask

Welcome to UberTask! A gem that will help you execute sequential tasks.
The gem provides the ability to retry a failed task
and reports the progress on the sequential tasks.

## Table of Contents

* [Installation](#installation)
* [Use case](#use-case)
* [Usage](#usage)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'uber_task'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install uber_task
## Usage

Imagine a Rails application similar to Circle CI, where we need to execute
steps in sequence like:

1. Install the Ruby version as specified in the config file
1. Install Node version as specified in the config file
1. Checkout the code from GitHub
1. Install bundler and gems
1. Install node packages
1. Create DB using `rails db:create`
1. ...
1. ...

Most of the steps are dependent on their previous step to execute successfully.
A few steps involve API calls to third-party services which can be a bottleneck
sometimes if their server is down or we have a bad connectivity issue.

### run

`.run` method creates or adds the current task to the tasks list.
This needs to be called inside a function which usually is considered as a
parent function.

```ruby
def create_build_and_test
  UberTask.run(
    'Build and Test',
    default_retry_count: 1,
    default_retry_wait: 5.mins,
    retry_count: 1
  ) do

    install_ruby
    install_node
    checkout_code_from_github
    install_bundler_and_gems
    install_node_packages
    create_db
  end
end
```

`create_build_and_test` can be treated as a parent function that executes the pipeline steps.
On calling the `.run` method of UberTask inside this function, we add this function as the first task in our process.

#### parameters

1. name -
   Default value is nil. Set the value of this parameter which
   signifies what the function does.

1. default_retry_count:
   Default value is nil. The count here signifies how many times the parent function
   (in the above example `create_build_and_test` function) should be retried.
   This is applicable only for the parent task.

1. default_retry_wait:
   Default value is nil. If the parent task fails and we want to retry it after a certain
   timeout, we should set this value.

1. retry_count:
   Default value is 0. The count signifies how many times the subtasks should be retried.
   If this is not set the `default_retry_count` will be assigned to `retry_count`.

1. vital:
   Default value is true. If set to true, the task is considered to be an important task
   and an error will be raised if it fails. The task will be retried based on `retry_count`.
   If the value is false, it won't be retried even if `retry_count` is greater than 0.

1. block:
   Pass a Ruby block that contains the code to be executed.

### on_success

`#on_success` acts as an event handler similar to JavaScript handlers.

We need to call this inside the `UberTask#run` method. This event is triggered when the current task gets executed successfully.

```ruby
def install_ruby
  UberTask.run('Install Ruby', retry_count: 2) do
    UberTask.on_success do
      # code to send a Slack notification
      send_ruby_installed_notification
    end

    process_ruby_version_and_install_ruby
  end
end
```

`install_ruby` is called inside the `create_build_and_test` function.
When we call `.run` again inside the subtask,
the function gets added to the top of the stack.
Our stack will look as below:

```
    install_ruby          <- top
    create_build_and_test
```

When the `install_ruby` function is successful,
the code inside the `on_success` block gets executed.

#### parameters

1. block:
   Pass a Ruby block that contains the code to be executed.

### on_report

This is similar to the `on_success` event.

We need to call this inside the `UberTask#run` method. This event is triggered when the current task reports something.

```ruby
def install_ruby
  UberTask.run('Install Ruby', retry_count: 2) do
    UberTask.on_report do
      puts 'This message appears when task reports something'
    end

    UberTask.report do
      puts 'Starting ruby installation'
    end

    process_ruby_version_and_install_ruby

    UberTask.report do
      puts 'Finished ruby installation'
    end
  end
end
```

#### parameters

1. block:
   Pass a Ruby block that contains the code to be executed.

### on_skip

This is similar to the `on_success` event.

We need to call this inside the `UberTask#run` method. This event is triggered when the current task gets skipped.

```ruby
def install_ruby
  UberTask.run('Install Ruby', retry_count: 2) do
    UberTask.on_skip do
      puts 'Ruby installation was skipped'
    end

    if ruby_already_installed?
      UberTask.skip('Ruby is already installed')
    else
      process_ruby_version_and_install_ruby
    end
  end
end
```

#### parameters

1. block:
   Pass a Ruby block that contains the code to be executed.

### on_subtask_error

This is similar to the `on_success` event.

We need to call this inside the `UberTask#run` method. This event is triggered when the subtask raises an error.

```ruby
def install_ruby_from_source
  UberTask.run('Install Ruby from source', retry_count: 2) do
    UberTask.on_subtask_error do |_task, event, err|
      if network_error?(err)
        puts 'Encountered network error, retrying...'
        UberTask.retry(reason: err, wait: 3)
      else
        puts "Encountered unexpected error - #{err.message}"
        event.handled
      end
    end

    ### Subtask 1 -- network error can occur
    UberTask.run('Download ruby archieve', retry_count: 3) do
      download_ruby_archieve
    end

    ### Subtask 2 -- compilation can fail
    UberTask.run('Compile ruby') do
      compile_ruby
    end
  end
end
```

#### parameters

1. block:
   Pass a Ruby block that contains the code to be executed.

### on_retry

This is similar to the `on_success` event.

We need to call this inside the `UberTask#run` method. This event is triggered when the current task is retried.

```ruby
def install_ruby
  UberTask.run('Install Ruby', retry_count: 2) do
    UberTask.on_retry do
      puts 'Retrying to install ruby...'
    end

    result = process_ruby_version_and_install_ruby
    UberTask.retry(reason: result.message) if result.error?
  end
end
```

#### parameters

1. block:
   Pass a Ruby block that contains the code to be executed.

## Examples

You can find examples of gem usage at `examples/` folder:
```
ruby examples/download_and_move_file.rb
```

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
