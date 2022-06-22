# frozen_string_literal: true

require 'uber_task/error'
require 'uber_task/event'
require 'uber_task/event_handled'
require 'uber_task/location'
require 'uber_task/retry_info'
require 'uber_task/retry_task'
require 'uber_task/skip_task'
require 'uber_task/task_context'
require 'uber_task/version'

module UberTask
  def self.current
    Thread.current[:__uber_task_stack__] ||= []
    Thread.current[:__uber_task_stack__].last
  end

  def self.on_report(&block)
    UberTask.current.handlers[:report] = block
  end

  def self.on_retry(
    report: true,
    wait: 0,
    &block
  )
    context = UberTask.current
    context.handlers[:retry] = block
    context.retry_info.report = report
    context.retry_info.wait = wait
  end

  def self.on_skip(&block)
    UberTask.current.handlers[:skip] = block
  end

  def self.on_subtask_error(&block)
    UberTask.current.handlers[:subtask_error] = block
  end

  def self.on_success(&block)
    UberTask.current.handlers[:success] = block
  end

  def self.report(
    level = Logger::INFO,
    &block
  )
    UberTask.current.report(level, &block)
  end

  def self.retry(reason: nil, wait: 0)
    if block_given?
      reason ||= yield
    end
    raise RetryTask.new(
      reason: reason,
      wait: wait,
    )
  end

  def self.run(
    name = nil,
    default_retry_count: nil,
    default_retry_wait: nil,
    retry_count: 0,
    vital: true,
    &block
  )
    parent = UberTask.current

    if parent
      if default_retry_count.nil?
        default_retry_count = parent.retry_info.default_retries
      end

      if default_retry_wait.nil?
        default_retry_wait = parent.retry_info.default_retry_wait
      end

      if retry_count < 1
        retry_count = default_retry_count || 0
      end
    end

    retry_info = RetryInfo.new(
      default_retries: default_retry_count,
      default_retry_wait: default_retry_wait,
      retries: retry_count,
    )

    context = TaskContext.new(
      name: name,
      retry_info: retry_info,
      vital: vital,
      &block
    )

    context.execute
  end

  def self.skip(reason = nil)
    if block_given?
      reason ||= yield
    end
    raise SkipTask.new(reason: reason)
  end
end
