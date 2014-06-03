require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'rflow-components-file'))

require 'logger'

RFlow.logger = Logger.new STDOUT
RFlow.logger.level = 5

def decode_avro(schema_string, serialized_object)
  schema = Avro::Schema.parse(schema_string)
  sio = StringIO.new(serialized_object)
  Avro::IO::DatumReader.new(schema, schema).read Avro::IO::BinaryDecoder.new(sio)
end

def encode_avro(schema_string, object)
  schema = Avro::Schema.parse(schema_string)
  sio = StringIO.new
  Avro::IO::DatumWriter.new(schema).write object, Avro::IO::BinaryEncoder.new(sio)
  sio.string
end
