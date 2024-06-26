describe UberTask do
  it 'skips the task' do
    task_skipped = true

    UberTask.run do 
      UberTask.skip
      ask_skipped = false
    end

    expect(task_skipped).to be(true)
  end
end


        