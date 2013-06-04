Server Implementation
---------------------

This directory contains the Javascript code which implements the
server side of the PIR algorithm.

The server side can be run locally as a Node.JS module, or on a
Google Spreadsheet.

### Using Node.js

To run the server implementation using Node.js, several packages
are required.

```
npm install optimist wordwrap bigint-node
```

### Via Google Spreadsheets

Files in the *googlified* directory have been converted to run
properly on Google Spreadsheets. For the most part, this
conversion is automatic using the shell script `do_googlify.sh`.

The *interface.js* script goes in the interface script library.
All others belong in the database script library.

### Tidbits

*mkdb.coffee* can be used to generate encrypted elements.

