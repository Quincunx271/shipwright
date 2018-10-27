# Shipwright

## Experimental

Shipwright is a CMake parsing library.

TODO:
A thought on design:
It seems like a beautiful idea for a lexer to be an iterator/range over the underlying data range.
However, how would I indicate a lexer error? If lexer errors aren't a thing, I'm good. Otherwise, an
idea is to have a lexer object that has a nicer way to indicate errors, and a throwing iterator
interface around that. Another idea is to have an error token which is simply passed into the
outgoing token stream.
