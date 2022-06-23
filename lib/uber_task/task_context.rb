# frozen_string_literal: true

module UberTask
  class TaskContext
    attr_reader :body,
                :handlers,
                :location,
                :method,
                :name,
                :parent,
                :retry_info,
                :scope,
                :subtasks,
                :vital

    def initialize(
      name:,
      retry_info:,
      vital: true,
      &block
    )
      @body = block
      @handlers = {
        retry: nil,
        report: nil,
        skip: nil,
        subtask_error: nil,
        success: nil,
      }
      @location = Location.new(
        path: block.source_location[0],
        line: block.source_location[1],
      )
      @method = @body.binding.eval('__method__')
      @name = name
      @parent = UberTask.current
      @parent&.add_subtask(self)
      @retry_info = retry_info
      @scope = @body.binding.eval('self')
      @vital = vital
    end

    def add_subtask(context)
      @subtasks ||= []
      @subtasks.push(context)
    end

    def execute
      enter_task
      result = @scope.instance_exec(self) do |context|
        context.body.call(context)
      end
      execute_handler(:success)
      result
    rescue RetryTask => err
      if retry?(err)
        exit_task
        retry
      end
    rescue SkipTask => err
      execute_handler(:skip, err.reason)
    # rubocop:disable Lint/RescueException
    rescue Exception => err
      parent_asked_to_retry = false

      begin
        # We will allow ancestors to check errors from this task because in some
        # situations, like, for example, a connection issue, a parent task may
        # order the child to retry without having to put the error check on each
        # child task.
        @parent&.execute_handler_chain(self, :subtask_error, err)
      rescue RetryTask => err
        if !retry?(err)
          return
        end
        parent_asked_to_retry = true
      rescue SkipTask => err
        execute_handler(:skip, err.reason)
        return
      end

      if parent_asked_to_retry
        exit_task
        retry
      end

      # None of the parents asked to retry or skip the task.
      raise err
    # rubocop:enable Lint/RescueException
    ensure
      exit_task
    end

    def enter_task
      thread = Thread.current
      thread[:__uber_task_stack__] ||= []
      thread[:__uber_task_stack__].push(self)
      Internal.trace { enter_message }
    end

    def exit_task
      thread = Thread.current
      thread[:__uber_task_stack__].pop
      Internal.trace { exit_message }
    end

    def execute_handler(key, *args)
      @scope.instance_exec(self) do |context|
        context.handlers[key]&.call(*args)
      end
    end

    def execute_handler_chain(task, key, *args)
      begin
        @scope.instance_exec(self) do |context|
          event = Event.new(key.to_s)
          context.handlers[key]&.call(task, event, *args)
        end
      rescue EventHandled
        return
      end

      @parent&.execute_handler_chain(task, key, *args)
    end

    def full_location
      "#{@location.path}:" + @location.line.to_s.red
    end

    def full_name
      result = @scope.to_s.purple + ".#{@method}".cyan
      result += " #{@name.to_s.white}" unless @name.nil?
      result
    end

    def level
      @parent.nil? ? 0 : @parent.level + 1
    end

    def report(level = Logger::INFO)
      return if Rails.logger.level > level
      message = yield
      execute_handler_chain(self, :report, message, level)
    end

    private

    def enter_message
      enter_tag = '[Enter]'.yellow
      trace = "#{uber_task_tag} #{enter_tag} #{full_name} #{full_location}"
      indent = '  ' * level
      indent + trace
    end

    def exit_message
      exit_tag = '[Enter]'.red
      trace = "#{uber_task_tag} #{exit_tag} #{full_name} #{full_location}"
      indent = '  ' * level
      indent + trace
    end

    def uber_task_tag
      '[UberTask]'.green
    end

    def retry?(err)
      if @retry_info.retries_remaining.positive?
        @retry_info.retries_remaining -= 1

        if @retry_info.report
          report { @retry_info.message(wait: err.wait) }
        end

        # The RetryTask exception specified the amount of time to wait.
        if err.wait.positive?
          sleep(err.wait)
        # The task itself has the amount of time to wait configured.
        elsif @retry_info.wait.positive?
          sleep(@retry_info.wait)
        # The task inherited the amount of time to wait from the parent task.
        elsif @retry_info.default_retry_wait.positive?
          sleep(@retry_info.default_retry_wait)
        end

        execute_handler(:retry, err.reason)

        Internal.trace { exit_message }
        Internal.trace { enter_message }

        return true
      end

      raise err.reason if @vital

      # We cannot retry anymore and it is not a vital task.
      execute_handler(:skip, err.reason)
      false
    end
  end
end
