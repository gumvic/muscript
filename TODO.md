- generate readable js

- interdependent lets shouldn't be allowed


- multiarity

- zero arity as a special case

- check arity on call?


- AST for module sucks -- module, alias, globals, all that should be renamed


- js module should be able to both declare its name and require modules


- let Point x y -- generates Point (using Object.create(Point.prototype)), isPoint; allow user to redefine those helpers?

- let Point.distance otherPoint = ...


- new name and global search and replace "mu"


- access -- a.b.c

- getter functions like .x, also chained, like .address.city; also, maybe they should use `get`/`getIn` if the data is immutable

- setters like .!x, .!x.!y -- do chained setters make sense?


- template strings

- import (window, $) from .. -- .. means outside world

- operators

- source maps

- CLI interface

- REPL