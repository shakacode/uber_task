# frozen_string_literal: true

describe UberTask do
  describe '.report' do
    it 'reports from task' do
      reported = false
      on_report_called = false

      UberTask.run do
        UberTask.on_report do
          on_report_called = true
        end

        UberTask.report do
          reported = true
        end
      end

      expect(reported).to be(true)
      expect(on_report_called).to be(true)
    end
  end
end
