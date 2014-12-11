### Reshard Kinesis streams in response to cloud watch metrics

This CLI client provides support for observing the cloud watch metrics on a
Kinesis stream and resharding accordingly.

#### Usage

A library which implements the basic machinery is provided, as well as an
executable target, `kinesis-reshard`.

~~~~sh
kinesis-reshard \
  --access-key AK \
  --secret-access-key SK \
  --region "us-west-2" \
  --stream-name "my-stream"
~~~~
