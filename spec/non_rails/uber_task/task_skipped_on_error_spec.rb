describe UberTask::SkipTask do
  it 'Skips the task on a error' do
    task_skipped_after_exception = false
  
    UberTask.run do
      UberTask.on_subtask_error do |_task, _event, err|
        if err.message == 'Some error'
          task_skipped_after_exception = true
          UberTask.skip(reason: err)
        end
      end

      UberTask.run do 
        raise 'Some error' if task_skipped_after_exception == false
      end
    end
  
    expect(task_skipped_after_exception).to be(true)
  end
end