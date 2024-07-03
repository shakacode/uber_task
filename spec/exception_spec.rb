describe UberTask do
  it 'Retries the child task after two exceptions' do
    task_retried_after_exception = 0

    UberTask.run do
      UberTask.on_subtask_error do |task, event, err|
        if err.message == 'Some error'
          task_retried_after_exception += 1
          UberTask.retry(reason: err, wait: 1)
        end
      end

      UberTask.run(retry_count: 2, vital: false) do
        if task_retried_after_exception < 2
          raise 'Some error'
        end
      end
    end


    expect(task_retried_after_exception).to be(2)
  end
end
