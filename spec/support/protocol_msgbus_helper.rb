shared_examples 'a protocol message bus' do
  describe '__protocol_msgbus__ PubSub' do
    let(:msgbus) { subject.__protocol_msgbus__ }
    let(:message) { double(:message, name: 'name', channel: 'channel', messages: []) }

    specify 'supports valid ProtocolMessage messages' do
      received = 0
      msgbus.subscribe(:message) { received += 1 }
      expect { msgbus.publish(:message, message) }.to change { received }.to(1)
    end

    specify 'fail with unacceptable STATE event names' do
      expect { msgbus.subscribe(:invalid) }.to raise_error KeyError
      expect { msgbus.publish(:invalid) }.to raise_error KeyError
      expect { msgbus.unsubscribe(:invalid) }.to raise_error KeyError
    end
  end
end
