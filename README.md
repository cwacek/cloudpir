CloudPir
========

Private Information Retrieval in a Google Spreadsheet. This was a
project to allow private (low information leakage) queries to a
public database hosted on the cloud. A formal writeup of the
algorithms used and the results can be found in
[evaluation.pdf](evaluation.pdf)

The server implementation is in *server*, with an additional
README inside. The client implementation is in *client*.

Use
----
To run the PIR implementation against a local server:

```
cd client
bundle install
ruby pir.rb -e 2 -p 50-8
```

To run the implementation against Google Docs:

```
cd client
bundle install
ruby pir.rb -e 2 -p 50-8 -g
```

For help try `ruby pir.rb --help`
