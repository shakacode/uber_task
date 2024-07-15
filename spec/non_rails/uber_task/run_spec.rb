# frozen_string_literal: true

describe UberTask do
  describe '.run' do
    context 'when task succeeds' do
      it 'it triggers .on_success hook' do
        on_success_called = false

        UberTask.run do
          UberTask.on_success do
            on_success_called = true
          end
        end

        expect(on_success_called).to be(true)
      end
    end

    context 'when task fails' do
      it 'does not trigger .on_success hook' do
        on_success_called = false

        UberTask.run do
          UberTask.on_success do
            on_success_called = true
          end

          raise 'error'
        end
      rescue StandardError
        expect(on_success_called).to be(false)
      end
    end
  end
end
