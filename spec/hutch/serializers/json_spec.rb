require 'spec_helper'

describe Hutch::Serializers::JSON do
  let(:subject) { Hutch::Serializers.find("application/json") }

  it "encode/decode" do
    payload = { a: 1, b: 2 }
    encoded = subject.encode(payload)
    decoded = subject.decode(encoded)

    expect(encoded).to eq "{\"a\":1,\"b\":2}"
    expect(decoded).to eq("a" => 1, "b" => 2)
    expect(decoded[:a]).to eq 1
    expect(decoded[:b]).to eq 2
  end

end
